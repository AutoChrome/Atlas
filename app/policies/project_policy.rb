# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user.present? || record.public?
  end

  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end

  def destroy?
    user&.admin? || user&.member?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.public_only
    end
  end
end
