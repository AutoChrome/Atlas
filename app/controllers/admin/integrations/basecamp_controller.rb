module Admin
  module Integrations
    class BasecampController < Admin::BaseController
      def show
        @token = ENV["BASECAMP_WEBHOOK_TOKEN"]
        @webhook_url = @token.present? ? integrations_basecamp_webhook_url(token: @token) : nil
      end
    end
  end
end
