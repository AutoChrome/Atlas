class ChartsController < ApplicationController
  allow_unauthenticated_access only: %i[show elsewhere]

  before_action :set_area
  before_action :set_chart, only: %i[show edit update destroy preview_import apply_import elsewhere]

  def show
    authorize @chart
    # The nested to/from_chart_column: :chart_table preloads are for each
    # column's own "referenced by / references" panel; outgoing/incoming
    # on their own would be enough for the table-level list below.
    @chart_tables = @chart.chart_tables.includes(
      chart_columns: [
        { outgoing_relationships: { to_chart_column: :chart_table } },
        { incoming_relationships: { from_chart_column: :chart_table } }
      ],
      chart_indices: []
    )
    # Loaded once here rather than separately by the toolbox's global list
    # and (per table) the "what does this connect to" panel — both views
    # filter/iterate this same preloaded set, no extra queries.
    @relationships = @chart.chart_relationships.includes(from_chart_column: :chart_table, to_chart_column: :chart_table)
  end

  def new
    @chart = @area.charts.new
    authorize @chart
  end

  def create
    @chart = @area.charts.new(chart_params)
    authorize @chart

    if @chart.save
      redirect_to [ @area, @chart ], notice: "Chart created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @chart
  end

  def update
    authorize @chart

    if @chart.update(chart_params)
      redirect_to [ @area, @chart ], notice: "Chart updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @chart
    @chart.destroy
    redirect_to @area, notice: "Chart deleted.", status: :see_other
  end

  def new_import
    @chart = @area.charts.new
    authorize @chart, :create?
  end

  def import
    @chart = @area.charts.new
    authorize @chart, :create?

    file = params[:sql_file]
    if !file.respond_to?(:read)
      @chart.errors.add(:base, "Choose a .sql file or a Rails db/schema.rb file to import.")
      return render :new_import, status: :unprocessable_entity
    end

    title = params[:title].presence || File.basename(file.original_filename, ".*")
    parsed = parse_uploaded(file.read)
    result = ChartImportBuilder.build(area: @area, title: title, **parsed)

    if result.chart
      redirect_to [ @area, result.chart ], notice: import_notice(result)
    else
      @chart.errors.add(:base, result.warnings.first || "Could not parse that file.")
      render :new_import, status: :unprocessable_entity
    end
  end

  # Uploads a file against an EXISTING chart and shows what it would
  # change — nothing is written yet. Matching is case-insensitive by name
  # (see ChartImportSync); a genuinely different name always reads as new.
  def preview_import
    authorize @chart, :update?

    file = params[:sql_file]
    if !file.respond_to?(:read)
      return redirect_to [ @area, @chart ], alert: "Choose a .sql file or a Rails db/schema.rb file to import."
    end

    parsed = parse_uploaded(file.read)
    @diff = ChartImportSync.diff(chart: @chart, tables: parsed[:tables], table_order: parsed[:table_order], pending_fks: parsed[:pending_fks])
    @parse_warnings = parsed[:warnings]
    @import_payload = parsed.slice(:tables, :table_order, :pending_fks).to_json
  end

  # Commits the changes a `preview_import` page showed. Re-resolves
  # everything against the chart's current state (see ChartImportSync)
  # rather than trusting stale references from the preview request.
  def apply_import
    authorize @chart, :update?

    parsed = rehydrate_import_payload(params[:import_payload])
    ChartImportSync.apply!(chart: @chart, **parsed)
    redirect_to [ @area, @chart ], notice: "Chart updated from file."
  rescue JSON::ParserError, ActiveRecord::RecordInvalid => e
    redirect_to [ @area, @chart ], alert: "Couldn't apply those changes: #{e.message}"
  end

  # Backs the chart page's own table search: alongside filtering this
  # chart's tables client-side, it asks whether the same name shows up in
  # a *different* chart too — useful because a foreign key can point at a
  # table someone put in another chart, and ChartRelationship deliberately
  # can't model that (a relationship is scoped to one chart; letting it
  # reference another chart's column would need its own visibility check,
  # not something to bolt on here). This is read-only and non-authoritative
  # by design — a name match, not a real relationship — so it reuses the
  # same Chart search index the sitewide search already relies on rather
  # than adding new data to maintain.
  def elsewhere
    authorize @chart, :show?
    query = params[:q].to_s.strip
    return render json: { results: [] } if query.blank?

    visibility_filter = current_user ? {} : { public: true }
    other_charts = Chart.search(
      query,
      fields: [ "table_names", "column_names" ],
      match: :word_start,
      where: visibility_filter.merge(id: { not: @chart.id }),
      limit: 8,
      includes: [ :area ]
    )

    results = other_charts.filter_map { |c| elsewhere_result(c, query) }
    render json: { results: results }
  rescue Searchkick::Error, Faraday::ConnectionFailed => e
    Rails.logger.error("Chart elsewhere-search unavailable: #{e.message}")
    render json: { results: [] }
  end

  private
    # Searchkick tells us the chart matched, not which of its (possibly
    # hundreds or thousands of) tables did — filtered at the database
    # level, not by loading the whole chart into memory and scanning it in
    # Ruby, specifically so a match in a *huge* other chart doesn't drag
    # its entire table/column set into this request just to find a few rows.
    # Capped at 25 candidates (rather than unbounded) for the same reason —
    # generous enough to find a real match in practice, but not "load every
    # table a common column name touches."
    def elsewhere_result(chart, query)
      like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      matched_tables = chart.chart_tables
        .left_joins(:chart_columns)
        .where("chart_tables.name ILIKE :q OR chart_columns.name ILIKE :q", q: like_query)
        .distinct
        .includes(chart_columns: :outgoing_relationships)
        .limit(25)
        .to_a

      return nil if matched_tables.empty?

      # Handed back as structured data (name + whether it's a primary key
      # here) so the searching chart can annotate its OWN matching columns
      # directly (see chart_search_controller.js's applyElsewhereColumnHints)
      # rather than only rendering this table's HTML into a side panel.
      #
      # Deliberately NOT restricted to primary-key matches only: the point
      # is to surface the relationship from EITHER side. Standing on the
      # foreign-key-shaped side (a plain column here, a PK over there) needs
      # this, but so does standing on the primary-key side itself (a PK
      # here, a plain same-named column over there) — otherwise the PK
      # owner never learns anything points at it just because the pointer
      # happens to live in a different chart. The client does the actual
      # "does this look like a real FK/PK pair" filtering, by comparing
      # primary_key here against its own column's primary_key state — two
      # same-named PKs (e.g. every table's own "id") or two same-named
      # plain columns is far more likely coincidence than a relationship.
      downcased_query = query.downcase
      matched_columns = matched_tables.flat_map { |table|
        table.chart_columns.select { |c| c.name.downcase.include?(downcased_query) }
      }

      # Tables with an actual column match (not just a table-name match)
      # get first billing in the capped preview.
      tables_with_column_match, other_tables = matched_tables.partition { |table|
        table.chart_columns.any? { |c| c.name.downcase.include?(downcased_query) }
      }
      preview_tables = (tables_with_column_match + other_tables).first(3)

      {
        chart_title: chart.title,
        area_name: chart.area.name,
        # Carries the search term along so following this link lands on the
        # other chart with the same query already active (see
        # chart_search_controller.js's connect) — without it, arriving there
        # shows a blank search box and none of this chart's own hints back,
        # which is what made the relationship look one-directional even
        # though ChartsController#elsewhere is symmetric either way.
        url: area_chart_path(chart.area, chart, q: query),
        matched_columns: matched_columns.map { |c| { name: c.name, primary_key: c.primary_key? } }.uniq,
        tables_html: preview_tables.map { |table|
          render_to_string(partial: "chart_tables/preview", formats: [ :html ], locals: { table: table, area: chart.area, chart: chart, query: query })
        }.join
      }
    end

    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_chart
      @chart = @area.charts.friendly.find(params[:slug])
    end

    def chart_params
      params.require(:chart).permit(:title, :description, :public, :icon)
    end

    def import_notice(result)
      count = "#{result.tables_count} table#{"s" unless result.tables_count == 1}"
      base = "Imported #{count}."
      result.warnings.any? ? "#{base} #{result.warnings.size} warning(s) below." : base
    end

    # Content-sniffed, not filename-based — a renamed or extensionless
    # upload still gets parsed correctly. Never evaluates the file; only
    # decides which text-pattern parser (SchemaRbParser vs SqlSchemaParser)
    # to hand it to.
    def schema_rb?(content)
      content.match?(/ActiveRecord::Schema/) || content.match?(/^\s*create_table\s+"[^"]+".*do\s*\|/)
    end

    def parse_uploaded(content)
      schema_rb?(content) ? SchemaRbParser.parse(ruby: content) : SqlSchemaParser.parse(sql: content)
    end

    # Reverses the `.to_json` in `preview_import` — table names stay as
    # plain string hash keys (round-tripping them through JSON's
    # symbolize_names would turn "users" into :users, breaking every
    # `tables[name]` lookup downstream), while each column/index/fk hash
    # gets its expected symbol keys back.
    def rehydrate_import_payload(json)
      raw = JSON.parse(json)
      tables = raw["tables"].transform_values do |table|
        {
          columns: table["columns"].map { |c| c.transform_keys(&:to_sym) },
          indexes: table["indexes"].map { |i| i.transform_keys(&:to_sym) },
          notes: table["notes"]
        }
      end

      {
        tables: tables,
        table_order: raw["table_order"],
        pending_fks: raw["pending_fks"].map { |fk| fk.transform_keys(&:to_sym) }
      }
    end
end
