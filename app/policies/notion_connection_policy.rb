# frozen_string_literal: true

# Admin-only, same reasoning as WebhookPolicy — a Notion connection holds
# credentials that let Notion create/edit content in Atlas, so it sits with
# the other admin-only infrastructure controls, not member-level content
# permissions.
class NotionConnectionPolicy < ApplicationPolicy
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

  def regenerate_webhook_token?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
