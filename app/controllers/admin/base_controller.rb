module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private
      def require_admin
        redirect_to root_path, alert: "You are not authorized to do that." unless current_user&.admin?
      end
  end
end
