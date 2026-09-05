# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin? && user != record
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
