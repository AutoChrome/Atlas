# frozen_string_literal: true

# Anyone signed in (any role, including guest) can record their own
# accept/reject decisions — this isn't a privileged authoring action like the
# rest of a tutorial's structure, just "did I personally tick or cross this."
class TutorialTaskResponsePolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def destroy?
    user.present? && record.user_id == user.id
  end
end
