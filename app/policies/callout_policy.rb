# frozen_string_literal: true

# Only ever lives embedded in a page's rich text — gated the same coarse
# way editing that content already is, matching ContentTablePolicy.
class CalloutPolicy < ApplicationPolicy
  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end
end
