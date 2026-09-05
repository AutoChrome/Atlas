json.areas @areas do |area|
  json.partial! "area", area: area
end

json.pagination do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
