class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  before_action :remember_area_sort_preference

  helper_method :current_user, :real_current_user, :guest_preview?, :area_sort_mode, :expanded_area_ids

  AREA_SORT_MODES = %w[sequence alphabetical].freeze

  private
    # The signed-in user for authorization/visibility purposes — nil while
    # an admin has guest preview on, even though they're still genuinely
    # signed in (see real_current_user). This is what pundit_user delegates
    # to, so it's what every `authorize`/`policy_scope` call sees, and it's
    # also the `current_user` most views check to decide what to render —
    # which is the point: guest preview should make the page look and
    # behave exactly as it would for a real anonymous visitor.
    def current_user
      guest_preview? ? nil : real_current_user
    end

    # The actual signed-in identity, regardless of guest preview. Used only
    # where that distinction matters: rendering the preview toggle itself,
    # admin-panel access (previewing as a guest shouldn't also lock an
    # admin out of turning preview back off), and Audited attribution.
    def real_current_user
      resume_session
      Current.user
    end

    def guest_preview?
      real_current_user&.admin? && cookies[:guest_preview] == "1"
    end

    def pundit_user
      current_user
    end

    def handle_unauthorized
      if guest_preview?
        # Not redirect_back: the referer is very often the very page that
        # just got blocked (you were looking at it, then turned preview on,
        # or just refreshed it while previewing) — bouncing back there would
        # immediately fail this same check again, looping until the browser
        # gives up entirely rather than landing anywhere.
        redirect_to root_path,
                     alert: "A visitor without an account couldn't see that. Exit guest preview to check further."
      elsif current_user.nil?
        session[:return_to_after_authenticating] = request.url
        redirect_to new_session_path, alert: "Please sign in to continue."
      else
        redirect_back fallback_location: root_path, alert: "You are not authorized to do that."
      end
    end

    # A ?area_sort=alphabetical (or =sequence) param on any request updates
    # the sticky preference, so a link carrying it works from anywhere
    # without a dedicated endpoint.
    def remember_area_sort_preference
      return unless AREA_SORT_MODES.include?(params[:area_sort])

      cookies[:area_sort] = { value: params[:area_sort], expires: 1.year }
    end

    def area_sort_mode
      cookies[:area_sort] == "alphabetical" ? "alphabetical" : "sequence"
    end

    # Area IDs whose sidebar children should be expanded by default: the
    # area (or the area of the page) currently being viewed, plus all of
    # its ancestors — so drilling into a deeply nested area doesn't also
    # require manually expanding every level down to it.
    def expanded_area_ids
      area = @page&.area || @area
      ids = []

      while area
        ids << area.id
        area = area.parent
      end

      ids
    end
end
