module Integrations
  # Inbound: Notion posts here itself when a page shared with the matching
  # NotionConnection's integration changes — same reasoning as
  # BasecampController for why this skips ApplicationController entirely
  # (no session/CSRF/guest-preview machinery makes sense for a receiver
  # nothing but Notion ever calls).
  #
  # Two credentials are in play, at two different points in the request:
  # see NotionConnection for the full story. The :token in the URL stands
  # in for verification only during the gap before Notion's own
  # verification_token has been captured (same role BASECAMP_WEBHOOK_TOKEN
  # plays for Basecamp, which never signs anything at all) — once that's
  # captured, every real event is also checked against X-Notion-Signature.
  class NotionController < ActionController::Base
    skip_forgery_protection

    rate_limit to: 120, within: 1.minute, only: :webhook, with: -> { head :too_many_requests }

    # The only events worth re-fetching a page for. Every other kind Notion
    # might send (comment.created, page.moved, database.schema_updated,
    # ...) still gets a 200 below rather than a 404/422 — same reasoning as
    # BasecampController's HANDLED_KIND: a non-2xx is how Notion decides a
    # webhook is broken and starts backing off deliveries to it.
    HANDLED_EVENT_TYPES = %w[page.created page.content_updated page.properties_updated].freeze

    def webhook
      @connection = NotionConnection.active.find_by(webhook_token: params[:token])
      return head :unauthorized unless @connection

      return handle_verification_handshake if params[:verification_token].present?
      return head :unauthorized unless valid_signature?

      handle_event
      head :ok
    end

    private
      # Notion's one-time proof that it can reach this URL — see
      # NotionConnection#awaiting_verification?. The admin still has to
      # copy this same value into Notion's own "Verify subscription" form
      # (Atlas has no way to hand it back automatically), which is why
      # it's stored rather than just checked and discarded.
      def handle_verification_handshake
        @connection.receive_verification_token!(params[:verification_token])
        head :ok
      end

      def valid_signature?
        @connection.valid_signature?(body: request.raw_post, signature: request.headers["X-Notion-Signature"])
      end

      def handle_event
        return unless HANDLED_EVENT_TYPES.include?(params[:type])
        return unless params.dig(:entity, :type) == "page"

        page_id = params.dig(:entity, :id)
        NotionSyncJob.perform_later(@connection.id, page_id) if page_id.present?
      end
  end
end
