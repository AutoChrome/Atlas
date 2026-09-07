class SearchController < ApplicationController
  allow_unauthenticated_access only: %i[index]

  def index
    query = params[:q].to_s.strip
    return render json: { results: [] } if query.blank?

    # Anyone signed in sees everything (matches AreaPolicy::Scope /
    # PagePolicy::Scope); anonymous visitors only see what's publicly
    # visible — `public` in the index is Area/Page#publicly_visible?, which
    # already accounts for a public parent area, not just the record's own
    # flag.
    visibility_filter = current_user ? {} : { public: true }

    results =
      search_type(Area, query, visibility_filter, fields: [ "name^3", "description" ], limit: 5) { |a|
        { type: "Area", title: a.name, url: area_path(a) }
      } +
      search_type(Page, query, visibility_filter, fields: [ "title^3", "content" ], limit: 8, includes: [ :area ]) { |p|
        { type: "Page", title: p.title, meta: p.area.name, url: area_page_path(p.area, p) }
      } +
      search_type(Chart, query, visibility_filter, fields: [ "title^3", "description", "table_names", "column_names" ], limit: 5, includes: [ :area ]) { |c|
        { type: "Chart", title: c.title, meta: c.area.name, url: area_chart_path(c.area, c) }
      } +
      search_type(Tutorial, query, visibility_filter, fields: [ "title^3", "description", "steps_content" ], limit: 5, includes: [ :area ]) { |t|
        { type: "Tutorial", title: t.title, meta: t.area.name, url: area_tutorial_path(t.area, t) }
      }

    render json: { results: results }
  end

  private
    # Each content type is searched independently so a problem with one
    # index (a bad mapping, a timeout) degrades to "this type contributes
    # no results" rather than taking the other three down with it — that
    # exact failure mode is what made Chart's word_start mismatch look like
    # "search is down" sitewide instead of "chart search is down".
    def search_type(model, query, visibility_filter, fields:, limit:, includes: nil)
      options = { fields: fields, match: :word_start, where: visibility_filter, limit: limit }
      options[:includes] = includes if includes

      model.search(query, **options).map { |record| yield record }
    rescue Searchkick::Error, Faraday::ConnectionFailed => e
      Rails.logger.error("#{model.name} search unavailable: #{e.message}")
      []
    end
end
