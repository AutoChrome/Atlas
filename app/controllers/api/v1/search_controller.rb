module Api
  module V1
    # Same underlying Searchkick indexes and matching as the in-app
    # navigation search (see SearchController) — this just exposes it over
    # the API, scoped to whatever areas the token has access to.
    class SearchController < Api::BaseController
      def index
        if query.blank? || (!search_areas? && !search_pages?)
          return render json: { results: [] }
        end

        results = []
        results.concat(area_results) if search_areas?
        results.concat(page_results) if search_pages?

        render json: { results: results }
      rescue Searchkick::Error, Faraday::ConnectionFailed => e
        Rails.logger.error("Search unavailable: #{e.message}")
        render json: { results: [], error: "Search is temporarily unavailable." }
      end

      private
        def query
          params[:q].to_s.strip
        end

        def search_areas?
          boolean_param(:areas, default: true)
        end

        def search_pages?
          boolean_param(:pages, default: true)
        end

        def boolean_param(key, default:)
          return default unless params.key?(key)

          ActiveModel::Type::Boolean.new.cast(params[key])
        end

        def area_results
          areas = Area.search(query, fields: ["name^3", "description"], match: :word_start, limit: 5)
          areas.select { |area| current_api_token.authorized_for_area?(area) }.map do |area|
            {
              type: "Area",
              id: area.id,
              slug: area.slug,
              title: area.name,
              public: area.publicly_visible?,
              url: api_v1_area_url(area),
              web_url: area_url(area),
            }
          end
        end

        def page_results
          pages = Page.search(query, fields: ["title^3", "content"], match: :word_start, limit: 8, includes: [:area])
          pages.select { |page| current_api_token.authorized_for_area?(page.area) }.map do |page|
            {
              type: "Page",
              id: page.id,
              title: page.title,
              area: page.area.name,
              public: page.publicly_visible?,
              # id:, not the page itself — see _page.json.jbuilder for why
              # passing the record would generate a 404ing slug-based URL.
              url: api_v1_page_url(id: page.id),
              web_url: area_page_url(page.area, page),
            }
          end
        end
    end
  end
end
