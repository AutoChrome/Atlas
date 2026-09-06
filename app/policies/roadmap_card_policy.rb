# frozen_string_literal: true

class RoadmapCardPolicy < ApplicationPolicy
  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end

  def destroy?
    user&.admin? || user&.member?
  end

  def move?
    update?
  end
end
