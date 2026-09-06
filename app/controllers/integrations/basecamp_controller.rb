module Integrations
  # Inbound: Basecamp posts here itself, so this has none of
  # ApplicationController's session/CSRF/guest-preview machinery — same
  # reasoning as Api::BaseController, just for a webhook receiver instead
  # of a token-authenticated API.
  #
  # Basecamp doesn't sign its webhook payloads (no HMAC header the way
  # Atlas's own outbound webhooks work — see WebhookDeliveryJob), so the
  # :token in the URL is the only thing standing in for verification; see
  # /admin/integrations/basecamp for the actual URL and setup steps.
  class BasecampController < ActionController::Base
    skip_forgery_protection

    rate_limit to: 60, within: 1.minute, only: :webhook, with: -> { head :too_many_requests }

    # The one event this creates an announcement from. Every other kind
    # Basecamp might send (comment_created, todo_completed, ...) still gets
    # a 200 below rather than a 404/422 — an error response is how Basecamp
    # decides a webhook is broken and starts backing off deliveries to it,
    # and this integration is only meant to react to new posts anyway.
    HANDLED_KIND = "message_created"

    def webhook
      return head :unauthorized unless valid_token?

      create_draft_announcement if params[:kind] == HANDLED_KIND

      head :ok
    end

    private
      def valid_token?
        expected = ENV["BASECAMP_WEBHOOK_TOKEN"]
        return false if expected.blank?

        ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, expected)
      end

      def create_draft_announcement
        recording = params[:recording]
        return if recording.blank?

        Announcement.create!(
          title: recording[:title].presence || "Untitled Basecamp post",
          content: (recording[:content].presence || "") + source_footer(recording),
          starts_on: Date.current,
          ends_on: Date.current + 1.month
        )
      rescue => e
        # Never let a malformed payload or a validation failure turn into a
        # non-2xx response — see HANDLED_KIND above for why. This is the
        # only place that failure is visible, so it's logged loudly.
        Rails.logger.error("Basecamp webhook: failed to create announcement — #{e.class}: #{e.message}")
      end

      # Provenance, inline in the content itself — a draft with no visible
      # link back to where it actually came from is much harder to sanity
      # check before hitting Publish.
      def source_footer(recording)
        project = recording.dig(:bucket, :name)
        author = params.dig(:creator, :name)
        url = recording[:app_url]

        line = +"Posted in Basecamp"
        line << " (#{ERB::Util.h(project)})" if project.present?
        line << " by #{ERB::Util.h(author)}" if author.present?
        line << " — <a href=\"#{ERB::Util.h(url)}\">View original</a>" if url.present?

        "<p><em>#{line}.</em></p>"
      end
  end
end
