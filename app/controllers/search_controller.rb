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

    areas = Area.search(query, fields: [ "name^3", "description" ], match: :word_start, where: visibility_filter, limit: 5)
    pages = Page.search(query, fields: [ "title^3", "content" ], match: :word_start, where: visibility_filter, limit: 8, includes: [ :area ])
    charts = Chart.search(query, fields: [ "title^3", "description", "table_names" ], match: :word_start, where: visibility_filter, limit: 5, includes: [ :area ])
    tutorials = Tutorial.search(query, fields: [ "title^3", "description" ], match: :word_start, where: visibility_filter, limit: 5, includes: [ :area ])

    results = areas.map { |a| { type: "Area", title: a.name, url: area_path(a) } } +
              pages.map { |p| { type: "Page", title: p.title, meta: p.area.name, url: area_page_path(p.area, p) } } +
              charts.map { |c| { type: "Chart", title: c.title, meta: c.area.name, url: area_chart_path(c.area, c) } } +
              tutorials.map { |t| { type: "Tutorial", title: t.title, meta: t.area.name, url: area_tutorial_path(t.area, t) } }

    render json: { results: results }
  rescue Searchkick::Error, Faraday::ConnectionFailed => e
    Rails.logger.error("Search unavailable: #{e.message}")
    render json: { results: [], error: "Search is temporarily unavailable." }
  end
end
