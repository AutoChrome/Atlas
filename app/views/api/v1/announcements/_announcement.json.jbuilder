json.id announcement.id
json.title announcement.title
# .body.fragment.source.to_html, not .content.to_s — see WebhookDeliveryJob
# for why (avoids ActionView's dev-mode annotation comments leaking in).
json.content_html announcement.content.body&.fragment&.source&.to_html
json.author announcement.user&.name
json.published_at announcement.published_at&.iso8601
json.starts_on announcement.starts_on&.iso8601
json.ends_on announcement.ends_on&.iso8601
json.created_at announcement.created_at
json.updated_at announcement.updated_at
json.url api_v1_announcement_url(announcement)
json.web_url announcement_url(announcement)
