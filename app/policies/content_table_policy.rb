# frozen_string_literal: true

# A table only ever lives embedded in a page's rich text, so it's gated the
# same coarse way editing that content already is — admin or member,
# matching every other content-editing policy in the app — rather than
# tracking which specific page(s) reference a given table.
class ContentTablePolicy < ApplicationPolicy
  def create?
    user&.admin? || user&.member?
  end

  def update?
    user&.admin? || user&.member?
  end
end
