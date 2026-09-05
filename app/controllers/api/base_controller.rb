module Api
  class BaseController < ActionController::Base
    skip_forgery_protection
    include Pundit::Authorization
    include Pagy::Backend

    before_action :authenticate_api_token!

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from Pundit::NotAuthorizedError do
      render json: { error: "Forbidden" }, status: :forbidden
    end

    private
      def authenticate_api_token!
        token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
        api_token = ApiToken.authenticate(token)

        if api_token
          api_token.touch_last_used!
          @current_user = api_token.user
          @current_api_token = api_token
        else
          render json: { error: "Invalid or missing API token. Pass one as `Authorization: Bearer <token>`." },
                 status: :unauthorized
        end
      end

      def current_user
        @current_user
      end

      def current_api_token
        @current_api_token
      end

      def pundit_user
        current_user
      end

      def render_errors(record)
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end

      def render_area_forbidden(area)
        render json: { error: "This API token doesn't have access to the \"#{area.name}\" area." }, status: :forbidden
      end
  end
end
