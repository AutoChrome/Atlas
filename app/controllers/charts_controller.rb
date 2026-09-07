class ChartsController < ApplicationController
  allow_unauthenticated_access only: %i[show]

  before_action :set_area
  before_action :set_chart, only: %i[show edit update destroy preview_import apply_import]

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

  private
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
