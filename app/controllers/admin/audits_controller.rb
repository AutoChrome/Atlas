module Admin
  class AuditsController < BaseController
    def index
      @pagy, @audits = pagy(Audited::Audit.order(created_at: :desc).includes(:user))
    end

    def show
      @audit = Audited::Audit.find(params[:id])
    end
  end
end
