module Admin
  class WebhooksController < BaseController
    before_action :set_webhook, only: %i[edit update destroy regenerate_secret]

    def index
      authorize Webhook
      @webhooks = policy_scope(Webhook).ordered
    end

    def new
      @webhook = Webhook.new
      authorize @webhook
    end

    def create
      @webhook = Webhook.new(webhook_params)
      authorize @webhook

      if @webhook.save
        redirect_to admin_webhooks_path, notice: "Webhook \"#{@webhook.description}\" created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @webhook
    end

    def update
      authorize @webhook

      if @webhook.update(webhook_params)
        redirect_to admin_webhooks_path, notice: "Webhook updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @webhook
      @webhook.destroy
      redirect_to admin_webhooks_path, notice: "Webhook removed.", status: :see_other
    end

    def regenerate_secret
      authorize @webhook
      @webhook.regenerate_secret!
      redirect_to admin_webhooks_path, notice: "New secret generated for \"#{@webhook.description}\" — update the receiving end."
    end

    def docs
    end

    private
      def set_webhook
        @webhook = Webhook.find(params[:id])
      end

      def webhook_params
        params.require(:webhook).permit(:description, :url, :active, :content_format, :custom_parameters_json)
      end
  end
end
