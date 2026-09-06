# frozen_string_literal: true

class ChartTablePolicy < ApplicationPolicy
  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end

  def destroy?
    user&.admin? || user&.member?
  end

  def reposition?
    update?
  end
end
