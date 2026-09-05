# frozen_string_literal: true

class AreaPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.present? || record.publicly_visible?
  end

  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end

  def destroy?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.public_only
    end
  end
end
