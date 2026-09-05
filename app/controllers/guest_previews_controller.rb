# Lets an admin see the app as an anonymous visitor would, without actually
# signing out — see ApplicationController#current_user / #guest_preview?.
class GuestPreviewsController < ApplicationController
  before_action :require_real_admin

  def create
    cookies[:guest_preview] = { value: "1", expires: 8.hours }
    # Always the home page, not redirect_back — the page you're currently
    # on might not be visible to a guest at all (that's often exactly why
    # you're turning this on), and bouncing back to it would immediately
    # fail Pundit's check again under the new, more restricted identity.
    redirect_to root_path, notice: "Now previewing as a guest — you can still exit any time."
  end

  def destroy
    cookies.delete(:guest_preview)
    # Turning preview off only ever restores access, never removes it, so
    # wherever the admin came from is safe to return to.
    redirect_back fallback_location: root_path, notice: "Exited guest preview."
  end

  private
    def require_real_admin
      redirect_to root_path, alert: "You are not authorized to do that." unless real_current_user&.admin?
    end
end
