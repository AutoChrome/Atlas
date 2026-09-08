module Admin
  class NotionConnectionsController < BaseController
    before_action :set_notion_connection, only: %i[show edit update destroy regenerate_webhook_token]

    def index
      authorize NotionConnection
      @notion_connections = policy_scope(NotionConnection).order(:name)
    end

    # The setup dashboard — webhook URL to paste into Notion, and the
    # verification_token once Notion's handshake has delivered it (see
    # NotionConnection#awaiting_verification?), not just a record viewer.
    def show
      authorize @notion_connection
      @webhook_url = integrations_notion_webhook_url(token: @notion_connection.webhook_token, host: request.base_url)
    end

    def new
      @notion_connection = NotionConnection.new
      authorize @notion_connection
    end

    def create
      @notion_connection = NotionConnection.new(notion_connection_params)
      authorize @notion_connection

      if @notion_connection.save
        redirect_to admin_notion_connection_path(@notion_connection), notice: "Notion connection \"#{@notion_connection.name}\" created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @notion_connection
    end

    def update
      authorize @notion_connection

      # A blank integration_token field means "leave it as-is", not "clear
      # it" — the field is intentionally never pre-filled with the current
      # (decrypted) value (see the edit form), so submitting the form
      # without retyping it must not wipe out a working token.
      params_to_apply = notion_connection_params
      params_to_apply = params_to_apply.except(:integration_token) if params_to_apply[:integration_token].blank?

      if @notion_connection.update(params_to_apply)
        redirect_to admin_notion_connection_path(@notion_connection), notice: "Notion connection updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @notion_connection
      @notion_connection.destroy
      redirect_to admin_notion_connections_path, notice: "Notion connection removed.", status: :see_other
    end

    # Rotates the URL-path secret (see NotionConnection#webhook_token) —
    # deliberately does NOT touch verification_token, since that's Notion's
    # own value tied to the *subscription*, not this URL; rotating the path
    # just means updating the Payload URL on Notion's Webhooks tab, no
    # re-verification needed.
    def regenerate_webhook_token
      authorize @notion_connection
      @notion_connection.regenerate_webhook_token!
      redirect_to admin_notion_connection_path(@notion_connection),
        notice: "New webhook URL generated — update it in Notion's Webhooks tab for this connection."
    end

    private
      def set_notion_connection
        @notion_connection = NotionConnection.find(params[:id])
      end

      def notion_connection_params
        params.require(:notion_connection).permit(:name, :integration_token, :area_id, :active, :notion_workspace_name)
      end
  end
end
