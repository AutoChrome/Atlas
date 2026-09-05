json.pages @pages do |page|
  json.partial! "page", page: page
end

json.pagination do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
