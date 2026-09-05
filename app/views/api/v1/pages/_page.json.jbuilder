json.id page.id
json.slug page.slug
json.title page.title
json.content page.content.to_s
json.icon page.icon
json.public page.public
json.position page.position
json.area_id page.area_id
json.author page.user&.name
json.created_at page.created_at
json.updated_at page.updated_at
json.url api_v1_page_url(page)
json.web_url area_page_url(page.area, page)
