json.id page.id
json.slug page.slug
json.title page.title
# Deliberately still .content.to_s, not .body.fragment.source.to_html
# (unlike WebhookDeliveryJob/Announcement) — this renders inline attachments
# into real <img>/download-card HTML, matching "content comes back as
# rendered HTML" below; the raw fragment source would leave unresolved
# <action-text-attachment> placeholder tags instead. In development,
# annotate_rendered_view_with_filenames wraps that render in HTML comments
# for template-hunting in the browser — harmless there, but not something an
# API response should ever leak, so it's stripped explicitly.
json.content page.content.to_s.gsub(/<!--\s*(?:BEGIN|END)\s+\S+\s*-->/, "")
json.icon page.icon
json.public page.public
json.position page.position
json.area_id page.area_id
json.author page.user&.name
json.created_at page.created_at
json.updated_at page.updated_at
# api_v1_page_url(page) would call page.to_param, which FriendlyId overrides
# to return the slug — but the show route looks pages up by numeric id
# (Page.find(params[:id]), not .friendly.find), so that URL would 404.
# Passing id: explicitly sidesteps to_param entirely.
json.url api_v1_page_url(id: page.id)
json.web_url area_page_url(page.area, page)
