# Builds a real OpenAPI 3.0 document from ApiSpec::RESOURCES — the same data
# that drives the downloadable Bruno collection (BrunoCollectionBuilder) and
# the parameter tables on api_tokens/docs. Consumed by: Bruno's own
# "Import Collection > OpenAPI" flow, and Notion AI's custom-connector setup
# (see the "Connect Notion AI" section on that page for why this exists).
class OpenapiDocumentBuilder
  TYPE_SCHEMAS = {
    string: { "type" => "string" },
    integer: { "type" => "integer" },
    boolean: { "type" => "boolean" },
    date: { "type" => "string", "format" => "date" },
    file: { "type" => "string", "format" => "binary" }
  }.freeze

  def self.build(base_url:)
    new(base_url).document
  end

  def initialize(base_url)
    @base_url = base_url
  end

  def document
    {
      "openapi" => "3.0.3",
      "info" => {
        "title" => "Atlas API",
        "version" => "1",
        "description" => "Self-hosted documentation platform: nested areas, rich WYSIWYG pages, " \
          "public sharing, role-based access, full audit trail, and a scoped JSON API."
      },
      "servers" => [ { "url" => @base_url } ],
      "security" => [ { "bearerAuth" => [] } ],
      "components" => {
        "securitySchemes" => {
          "bearerAuth" => { "type" => "http", "scheme" => "bearer", "bearerFormat" => "API token" }
        },
        "schemas" => component_schemas
      },
      "paths" => paths
    }
  end

  private
    attr_reader :base_url

    def paths
      operations_by_path = ApiSpec::RESOURCES.flat_map { |r| r[:operations] }.group_by { |op| op[:path] }

      operations_by_path.transform_values do |ops|
        ops.each_with_object({}) { |op, methods| methods[op[:method].to_s] = operation_object(op) }
      end
    end

    def operation_object(op)
      obj = { "summary" => op[:summary] }
      obj["description"] = op[:description] if op[:description]

      params = Array(op[:path_params]).map { |p| parameter_object(p, "path") } +
               Array(op[:query_params]).map { |p| parameter_object(p, "query") }
      obj["parameters"] = params if params.any?

      obj["requestBody"] = request_body_object(op) if op[:body_params].present?
      obj["responses"] = responses_object(op)
      obj
    end

    def parameter_object(param, location)
      schema = TYPE_SCHEMAS.fetch(param[:type]).dup
      schema["default"] = param[:default] if param.key?(:default)

      {
        "name" => param[:name],
        "in" => location,
        "required" => location == "path" ? true : !!param[:required],
        "schema" => schema,
        "example" => param[:example]
      }.compact
    end

    def request_body_object(op)
      properties = Array(op[:body_params]).to_h { |p| [ p[:name], TYPE_SCHEMAS.fetch(p[:type]) ] }
      required = Array(op[:body_params]).select { |p| p[:required] }.map { |p| p[:name] }
      example = Array(op[:body_params]).filter_map { |p| [ p[:name], p[:example] ] if p[:example] }.to_h

      schema = { "type" => "object", "properties" => properties }
      schema["required"] = required if required.any?

      content_type = op[:body_type] == :multipart ? "multipart/form-data" : "application/x-www-form-urlencoded"

      {
        "required" => true,
        "content" => {
          content_type => { "schema" => schema, "example" => example }
        }
      }
    end

    def responses_object(op)
      responses = {}

      case op[:method]
      when :get
        responses["200"] = { "description" => "OK" }
      when :post
        responses["201"] = { "description" => "Created" }
        responses["422"] = error_response("Validation failed", schema: "ValidationError")
      when :patch
        responses["200"] = { "description" => "OK" }
        responses["422"] = error_response("Validation failed", schema: "ValidationError")
      when :delete
        responses["204"] = { "description" => "No Content" }
      end

      responses["401"] = error_response("Missing or invalid token")
      responses["403"] = error_response("Not allowed for this token") unless op[:path] == "/api/v1/search"
      responses["404"] = error_response("Not found") if op[:path].include?("{")

      responses
    end

    def error_response(description, schema: "Error")
      { "description" => description, "content" => { "application/json" => { "schema" => { "$ref" => "#/components/schemas/#{schema}" } } } }
    end

    def component_schemas
      {
        "Error" => {
          "type" => "object",
          "properties" => { "error" => { "type" => "string" } }
        },
        "ValidationError" => {
          "type" => "object",
          "properties" => { "errors" => { "type" => "array", "items" => { "type" => "string" } } }
        },
        "Pagination" => {
          "type" => "object",
          "properties" => {
            "page" => { "type" => "integer" },
            "pages" => { "type" => "integer" },
            "count" => { "type" => "integer" }
          }
        }
      }
    end
end
