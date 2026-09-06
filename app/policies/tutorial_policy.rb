# frozen_string_literal: true

class TutorialPolicy < ApplicationPolicy
  def index?
    user.present?
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
    user&.admin? || user&.member?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.public_only
    end
  end
end
