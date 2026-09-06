json.webhooks @webhooks do |webhook|
  json.partial! "webhook", webhook: webhook
end

json.pagination do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
