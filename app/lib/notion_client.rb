# Minimal wrapper around the two Notion REST API endpoints NotionSyncJob
# actually needs: a page's own properties (for its title) and its block
# children (its actual content), fetched recursively since Notion only
# returns one level of children per call. Not a general Notion API client —
# extend it if a future feature needs more of the API surface.
#
# API_VERSION is pinned to a long-stable version deliberately, not
# whatever's newest — Notion's 2025-09-03 version restructured databases
# around a new "data source" concept that this integration (pages only,
# no database sync) has no need for.
class NotionClient
  API_BASE = "https://api.notion.com/v1"
  API_VERSION = "2022-06-28"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  MAX_CHILD_DEPTH = 10

  class Error < StandardError; end

  def initialize(integration_token)
    @integration_token = integration_token
  end

  # https://developers.notion.com/reference/retrieve-a-page
  def retrieve_page(page_id)
    get("/pages/#{page_id}")
  end

  # https://developers.notion.com/reference/get-block-children — paginated,
  # and recurses into any block with children (a nested list item, a
  # toggle, a table's rows, ...), embedding the result as block["children"]
  # so NotionBlocksToHtml never has to make API calls of its own. Capped at
  # MAX_CHILD_DEPTH purely as a guard against pathological toggle-in-toggle
  # nesting — silently stops recursing deeper rather than erroring.
  def retrieve_block_children(block_id, depth: 0)
    blocks = fetch_all_children(block_id)
    return blocks if depth >= MAX_CHILD_DEPTH

    blocks.each do |block|
      next unless block["has_children"]

      block["children"] = retrieve_block_children(block["id"], depth: depth + 1)
    end
    blocks
  end

  # The page's own "title" property is one of its `properties`, but its
  # KEY varies by page/database schema (often "title", "Name", or "Page"),
  # not a fixed field — this finds whichever property actually has type
  # "title" rather than assuming a name.
  def self.extract_title(notion_page)
    title_property = notion_page.fetch("properties", {}).values.find { |property| property["type"] == "title" }
    rich_text = title_property&.dig("title") || []
    rich_text.map { |t| t["plain_text"] }.join.presence || "Untitled"
  end

  private
    def fetch_all_children(block_id)
      blocks = []
      cursor = nil

      loop do
        response = get("/blocks/#{block_id}/children", start_cursor: cursor, page_size: 100)
        blocks.concat(response["results"])
        break unless response["has_more"]

        cursor = response["next_cursor"]
      end

      blocks
    end

    def get(path, **query)
      uri = URI.parse("#{API_BASE}#{path}")
      uri.query = URI.encode_www_form(query.compact)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@integration_token}"
      request["Notion-Version"] = API_VERSION

      response = http.request(request)
      raise Error, "Notion API #{response.code}: #{response.body.to_s.first(300)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
end
