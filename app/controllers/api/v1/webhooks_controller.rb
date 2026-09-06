module Api
  module V1
    # Read-only, and admin-only per WebhookPolicy — same trust boundary as
    # the web admin UI, just exposed for integrations that need to discover
    # what's configured. Never renders the signing secret; see the
    # _webhook.json.jbuilder partial.
    class WebhooksController < Api::BaseController
      before_action :set_webhook, only: %i[show]

      def index
        authorize Webhook
        @pagy, @webhooks = pagy(policy_scope(Webhook).ordered)
      end

      def show
        authorize @webhook
      end

      private
        def set_webhook
          @webhook = Webhook.find(params[:id])
        end
    end
  end
end
