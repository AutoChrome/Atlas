# Fans an Announcement's lifecycle out to a set of Webhooks — published,
# edited, or deleted (Announcement#publish!, #notify_webhooks_of_update!,
# #notify_webhooks_of_deletion!). Runs in the background (Sidekiq) so none
# of those actions block on a slow or unreachable receiver, and each
# delivery is independent — one webhook failing doesn't stop the others, or
# get retried into a pile of duplicate deliveries.
#
# We don't validate or care what the receiving endpoint does with the
# payload — this only cares that the HTTP request was made and records
# what came back, for visibility on the webhook's delivery log.
class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  PUBLISHED = "announcement.published"
  UPDATED = "announcement.updated"
  DELETED = "announcement.deleted"

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # webhook_ids nil (rather than []) means "every active webhook" — only
  # relevant for a PUBLISHED job already serialized and waiting when this
  # argument didn't exist yet; every new call passes an explicit array
  # (Announcement#published_webhook_ids for UPDATED/DELETED), even an empty
  # one for "publish, but don't deliver anywhere this time".
  #
  # `title`/`url` are only ever passed for DELETED — the announcement no
  # longer exists to look up by the time this runs (this is a notification
  # that it's gone), so the caller (Announcement#notify_webhooks_of_deletion!)
  # captures what the payload needs as plain values while the record is
  # still alive, rather than this method finding nothing and silently
  # skipping the delivery entirely.
  def perform(event, announcement_id, webhook_ids = nil, title: nil, url: nil)
    webhooks = webhook_ids.nil? ? Webhook.active : Webhook.active.where(id: webhook_ids)
    return if webhooks.none?

    if event == DELETED
      deliver_deletion(webhooks, announcement_id, title, url)
    else
      deliver_content(event, webhooks, announcement_id)
    end
  end

  private
    def deliver_content(event, webhooks, announcement_id)
      announcement = Announcement.find_by(id: announcement_id)
      return unless announcement

      # Shared across every webhook below rather than one per — RichTextPayload
      # memoizes the (real ActionView partial) render internally, so this
      # costs at most one render of each format actually in use, however many
      # webhooks end up asking for it.
      payload = RichTextPayload.new(announcement.content)

      webhooks.find_each do |webhook|
        deliver(event, webhook, announcement, content_payload_json(event, announcement, payload, webhook))
      end
    end

    def deliver_deletion(webhooks, announcement_id, title, url)
      webhooks.find_each do |webhook|
        # No `announcement:` — the record is already gone by the time this
        # runs, and WebhookDelivery#announcement is optional for exactly
        # this reason (see its own comment).
        deliver(DELETED, webhook, nil, deletion_payload_json(announcement_id, title, url, webhook))
      end
    end

    def deliver(event, webhook, announcement, body)
      response = post(event, webhook, body)

      WebhookDelivery.create!(
        webhook: webhook,
        announcement: announcement,
        status_code: response.code.to_i,
        success: response.is_a?(Net::HTTPSuccess),
        response_body: response.body.to_s.first(2000)
      )
    rescue => e
      WebhookDelivery.create!(
        webhook: webhook,
        announcement: announcement,
        success: false,
        error_message: "#{e.class}: #{e.message}".first(500)
      )
    end

    def post(event, webhook, body)
      uri = URI.parse(webhook.url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri.presence || "/")
      request["Content-Type"] = "application/json"
      request["X-Atlas-Event"] = event
      request["X-Atlas-Signature"] = "sha256=#{signature_for(webhook, body)}"
      request.body = body

      http.request(request)
    end

    def signature_for(webhook, body)
      OpenSSL::HMAC.hexdigest("SHA256", webhook.secret, body)
    end

    # See RichTextPayload for what each Webhook#content_format value
    # actually produces, and Webhook#custom_parameters for the arbitrary
    # per-webhook data merged in here — top-level, alongside `announcement`
    # rather than nested inside it, since it describes this delivery/
    # webhook, not a property of the announcement itself.
    def content_payload_json(event, announcement, payload, webhook)
      {
        event: event,
        announcement: {
          id: announcement.id,
          title: announcement.title,
          content: webhook.plain_text? ? payload.plain_text : payload.html,
          content_format: webhook.content_format,
          author: announcement.user&.name,
          published_at: announcement.published_at&.iso8601,
          # Date, not DateTime, so this comes out as plain "YYYY-MM-DD" —
          # announcements run whole days, not exact instants.
          starts_on: announcement.starts_on&.iso8601,
          ends_on: announcement.ends_on&.iso8601,
          url: Rails.application.routes.url_helpers.announcement_url(announcement, host: ENV.fetch("SITE_ADDRESS", "localhost"))
        },
        custom_parameters: webhook.custom_parameters
      }.to_json
    end

    # Deliberately lean — no content/content_format/author/dates, since
    # there's no longer any content to speak of. Just enough for a receiver
    # to identify and remove/deactivate its own copy, which is exactly what
    # a delete notification is for.
    def deletion_payload_json(announcement_id, title, url, webhook)
      {
        event: DELETED,
        announcement: {
          id: announcement_id,
          title: title,
          url: url
        },
        custom_parameters: webhook.custom_parameters
      }.to_json
    end
end
