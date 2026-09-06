# frozen_string_literal: true

class AnnouncementPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
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

  def publish?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
