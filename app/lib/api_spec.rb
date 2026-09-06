# The single source of truth for Atlas's public JSON API surface — every
# resource, operation, and parameter listed here drives three things that
# would otherwise drift out of sync with each other and with reality:
# the parameter tables on api_tokens/docs, the generated OpenAPI document
# (OpenapiDocumentBuilder), and the downloadable Bruno collection
# (BrunoCollectionBuilder). Update this when the API changes; the other
# three follow automatically.
#
# Shape of one entry in RESOURCES[n][:operations]:
#   method:       :get / :post / :patch / :delete
#   path:         "/api/v1/areas/{slug}" — {name} marks a path parameter
#   summary:      short description, also used as the Bruno request name
#   description:  longer prose (optional)
#   path_params:  [{ name:, type:, example: }]
#   query_params: [{ name:, type:, required:, default:, example: }]
#   body_type:    :form (url-encoded or JSON) or :multipart — omit for GET/DELETE
#   body_params:  [{ name:, type:, required:, example: }]
module ApiSpec
  RESOURCES = [
    {
      name: "Areas",
      operations: [
        {
          method: :get, path: "/api/v1/areas", summary: "List areas",
          query_params: [ { name: "page", type: :integer, required: false, example: 1 } ]
        },
        {
          method: :get, path: "/api/v1/areas/{slug}", summary: "Fetch a single area",
          path_params: [ { name: "slug", type: :string, example: "getting-started" } ]
        },
        {
          method: :post, path: "/api/v1/areas", summary: "Create an area",
          body_type: :form,
          body_params: [
            { name: "name", type: :string, required: true, example: "Release Notes" },
            { name: "description", type: :string, required: false, example: "What shipped, and when." },
            { name: "icon", type: :string, required: false, example: "rocket" },
            { name: "public", type: :boolean, required: false, example: true },
            { name: "position", type: :integer, required: false, example: 0 },
            { name: "parent_id", type: :integer, required: false, example: nil }
          ]
        },
        {
          method: :patch, path: "/api/v1/areas/{slug}", summary: "Update an area",
          path_params: [ { name: "slug", type: :string, example: "getting-started" } ],
          body_type: :form,
          body_params: [
            { name: "name", type: :string, required: false, example: "Release Notes" },
            { name: "description", type: :string, required: false, example: "Updated description" },
            { name: "icon", type: :string, required: false, example: "rocket" },
            { name: "public", type: :boolean, required: false, example: true },
            { name: "position", type: :integer, required: false, example: 0 },
            { name: "parent_id", type: :integer, required: false, example: nil }
          ]
        },
        {
          method: :delete, path: "/api/v1/areas/{slug}", summary: "Delete an area",
          path_params: [ { name: "slug", type: :string, example: "getting-started" } ]
        }
      ]
    },
    {
      name: "Pages",
      operations: [
        {
          method: :get, path: "/api/v1/pages", summary: "List pages",
          query_params: [
            { name: "area_id", type: :integer, required: false, example: 1 },
            { name: "page", type: :integer, required: false, example: 1 }
          ]
        },
        {
          method: :get, path: "/api/v1/pages/{id}", summary: "Fetch a single page",
          path_params: [ { name: "id", type: :integer, example: 42 } ]
        },
        {
          method: :post, path: "/api/v1/pages", summary: "Create a page",
          body_type: :form,
          body_params: [
            { name: "area_id", type: :integer, required: true, example: 1 },
            { name: "title", type: :string, required: true, example: "Deploying to production" },
            { name: "content", type: :string, required: false, example: "<p>Step one: don't panic.</p>" },
            { name: "icon", type: :string, required: false, example: "rocket" },
            { name: "public", type: :boolean, required: false, example: false },
            { name: "position", type: :integer, required: false, example: 0 }
          ]
        },
        {
          method: :patch, path: "/api/v1/pages/{id}", summary: "Update a page",
          path_params: [ { name: "id", type: :integer, example: 42 } ],
          body_type: :form,
          body_params: [
            { name: "area_id", type: :integer, required: false, example: 1 },
            { name: "title", type: :string, required: false, example: "Deploying to production (updated)" },
            { name: "content", type: :string, required: false, example: "<p>Updated content.</p>" },
            { name: "icon", type: :string, required: false, example: "rocket" },
            { name: "public", type: :boolean, required: false, example: false },
            { name: "position", type: :integer, required: false, example: 0 }
          ]
        },
        {
          method: :delete, path: "/api/v1/pages/{id}", summary: "Delete a page",
          path_params: [ { name: "id", type: :integer, example: 42 } ]
        }
      ]
    },
    {
      name: "Attachments",
      operations: [
        {
          method: :post, path: "/api/v1/attachments", summary: "Upload an inline attachment",
          description: "Not tied to any page yet — registers the file and hands back an `html` snippet ready to embed in a page's `content`.",
          body_type: :multipart,
          body_params: [
            { name: "file", type: :file, required: true, example: "screenshot.png" }
          ]
        }
      ]
    },
    {
      name: "Announcements",
      operations: [
        {
          method: :get, path: "/api/v1/announcements", summary: "List announcements",
          query_params: [ { name: "page", type: :integer, required: false, example: 1 } ]
        },
        {
          method: :get, path: "/api/v1/announcements/{id}", summary: "Fetch a single announcement",
          path_params: [ { name: "id", type: :integer, example: 42 } ]
        },
        {
          method: :post, path: "/api/v1/announcements", summary: "Create an announcement",
          description: "Creates a draft — never publishes or sends anything to a webhook. Publishing stays a deliberate action taken from the Atlas web UI.",
          body_type: :form,
          body_params: [
            { name: "title", type: :string, required: true, example: "Scheduled maintenance this weekend" },
            { name: "content", type: :string, required: false, example: "<p>We'll be taking the app down...</p>" },
            { name: "starts_on", type: :date, required: true, example: "2026-09-06" },
            { name: "ends_on", type: :date, required: true, example: "2026-09-07" }
          ]
        },
        {
          method: :patch, path: "/api/v1/announcements/{id}", summary: "Update an announcement",
          path_params: [ { name: "id", type: :integer, example: 42 } ],
          body_type: :form,
          body_params: [
            { name: "title", type: :string, required: false, example: "Scheduled maintenance this weekend" },
            { name: "content", type: :string, required: false, example: "<p>Updated details.</p>" },
            { name: "starts_on", type: :date, required: false, example: "2026-09-06" },
            { name: "ends_on", type: :date, required: false, example: "2026-09-08" }
          ]
        },
        {
          method: :delete, path: "/api/v1/announcements/{id}", summary: "Delete an announcement",
          path_params: [ { name: "id", type: :integer, example: 42 } ]
        }
      ]
    },
    {
      name: "Webhooks",
      operations: [
        {
          method: :get, path: "/api/v1/webhooks", summary: "List webhooks",
          description: "Admin-only. Never includes the signing secret.",
          query_params: [ { name: "page", type: :integer, required: false, example: 1 } ]
        },
        {
          method: :get, path: "/api/v1/webhooks/{id}", summary: "Fetch a single webhook",
          description: "Admin-only. Never includes the signing secret.",
          path_params: [ { name: "id", type: :integer, example: 1 } ]
        }
      ]
    },
    {
      name: "Search",
      operations: [
        {
          method: :get, path: "/api/v1/search", summary: "Search areas and pages",
          description: "Same index and word-start matching as the in-app search box, scoped to the token's authorized areas.",
          query_params: [
            { name: "q", type: :string, required: true, example: "deploy" },
            { name: "areas", type: :boolean, required: false, default: true, example: true },
            { name: "pages", type: :boolean, required: false, default: true, example: true }
          ]
        }
      ]
    }
  ].freeze
end
