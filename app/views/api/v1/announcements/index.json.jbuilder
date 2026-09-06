json.announcements @announcements do |announcement|
  json.partial! "announcement", announcement: announcement
end

json.pagination do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
