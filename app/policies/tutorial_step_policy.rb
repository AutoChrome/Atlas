# frozen_string_literal: true

class TutorialStepPolicy < ApplicationPolicy
  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end

  def destroy?
    user&.admin? || user&.member?
  end

  def reorder?
    update?
  end
end
