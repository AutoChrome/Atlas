# frozen_string_literal: true

# Admin-only, unlike most other policies here — a webhook is server-side
# configuration that makes Atlas itself issue outbound HTTP requests to
# wherever its URL points, so it sits with the other admin-only
# infrastructure controls (Sidekiq, performance dashboard) rather than the
# member-level content permissions.
class WebhookPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  def regenerate_secret?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
