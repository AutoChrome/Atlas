# Builds a native Bruno collection (https://www.usebruno.com) from
# ApiSpec::RESOURCES — one folder per resource, one .bru request file per
# operation, plus a bruno.json manifest and a "Local" environment carrying
# base_url/api_token as variables. Returns { relative_path => file_content },
# which Api::V1::DocsController zips up for download.
class BrunoCollectionBuilder
  COLLECTION_NAME = "Atlas API".freeze

  def self.build(base_url:)
    new(base_url).files
  end

  def initialize(base_url)
    @base_url = base_url
  end

  def files
    { "#{root}/bruno.json" => bruno_json, "#{root}/environments/Local.bru" => environment_bru }
      .merge(request_files)
  end

  private
    attr_reader :base_url

    def root
      COLLECTION_NAME
    end

    def bruno_json
      JSON.pretty_generate(
        "version" => "1",
        "name" => COLLECTION_NAME,
        "type" => "collection",
        "ignore" => ["node_modules", ".git"],
      )
    end

    def environment_bru
      "vars {\n  base_url: #{base_url}\n  api_token: YOUR_API_TOKEN\n}\n"
    end

    def request_files
      files = {}

      ApiSpec::RESOURCES.each do |resource|
        resource[:operations].each_with_index do |op, index|
          filename = sanitize_filename(op[:summary])
          files["#{root}/#{resource[:name]}/#{filename}.bru"] = request_bru(op, seq: index + 1)
        end
      end

      files
    end

    def sanitize_filename(name)
      name.gsub(%r{[/\\:*?"<>|]}, "-")
    end

    # Every top-level .bru block, one per array entry, blank-line separated —
    # blocks that don't apply to this operation (no path params, GET has no
    # body, etc.) just return nil and are dropped.
    def request_bru(op, seq:)
      blocks = [
        meta_block(op, seq),
        method_block(op),
        path_params_block(op),
        query_params_block(op),
        auth_block,
        body_block(op),
      ].compact

      "#{blocks.join("\n\n")}\n"
    end

    def meta_block(op, seq)
      "meta {\n  name: #{op[:summary]}\n  type: http\n  seq: #{seq}\n}"
    end

    def method_block(op)
      "#{op[:method]} {\n  url: #{bruno_url(op)}\n  body: #{body_type_value(op)}\n  auth: bearer\n}"
    end

    # {slug} (OpenAPI-style, from ApiSpec) -> :slug (Bruno's URL syntax).
    def bruno_url(op)
      path = op[:path].gsub(/\{(\w+)\}/) { ":#{$1}" }
      query_string = example_pairs(op[:query_params]).map { |name, value| "#{name}=#{value}" }.join("&")
      url = "{{base_url}}#{path}"
      query_string.present? ? "#{url}?#{query_string}" : url
    end

    def body_type_value(op)
      case op[:body_type]
      when :multipart then "multipart-form"
      when :form then "form-urlencoded"
      else "none"
      end
    end

    def path_params_block(op)
      pairs = example_pairs(op[:path_params])
      return nil if pairs.empty?

      "params:path {\n#{format_pairs(pairs)}\n}"
    end

    def query_params_block(op)
      pairs = example_pairs(op[:query_params])
      return nil if pairs.empty?

      "params:query {\n#{format_pairs(pairs)}\n}"
    end

    def auth_block
      "auth:bearer {\n  token: {{api_token}}\n}"
    end

    def body_block(op)
      return nil if op[:body_params].blank?

      case op[:body_type]
      when :multipart
        pairs = Array(op[:body_params]).map { |p| [p[:name], "@file(#{p[:example]})"] }
        "body:multipart-form {\n#{format_pairs(pairs)}\n}"
      else
        "body:form-urlencoded {\n#{format_pairs(example_pairs(op[:body_params]))}\n}"
      end
    end

    # name/example pairs for params that actually have an example to show —
    # a nil example (e.g. optional parent_id, "top-level if omitted") is
    # left out of the request entirely rather than rendered as a blank value.
    def example_pairs(params)
      Array(params).filter_map { |p| [p[:name], p[:example]] unless p[:example].nil? }
    end

    def format_pairs(pairs)
      pairs.map { |name, value| "  #{name}: #{value}" }.join("\n")
    end
end
