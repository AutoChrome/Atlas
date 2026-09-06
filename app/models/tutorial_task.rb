class TutorialTask < ApplicationRecord
  include Autocorrectable
  autocorrects :description, :hint

  audited

  belongs_to :tutorial_step
  belongs_to :next_step_if_accepted, class_name: "TutorialStep", optional: true
  belongs_to :next_step_if_rejected, class_name: "TutorialStep", optional: true
  has_many :tutorial_task_responses, dependent: :destroy, inverse_of: :tutorial_task

  validates :description, presence: true
  validate :next_steps_belong_to_same_tutorial

  scope :ordered, -> { order(:position) }

  def response_for(user)
    return nil unless user

    tutorial_task_responses.find_by(user: user)
  end

  def accepted_for?(user)
    response_for(user)&.accepted == true
  end

  def rejected_for?(user)
    response_for(user)&.accepted == false
  end

  def decided_for?(user)
    response_for(user).present?
  end

  private
    # Without this, a malicious or buggy submission could redirect a viewer
    # into any step in the app, not just steps from this task's own
    # tutorial — mirrors the equivalent guard the old TutorialStepChoice
    # carried for its navigation target.
    def next_steps_belong_to_same_tutorial
      [ next_step_if_accepted, next_step_if_rejected ].compact.each do |step|
        next if step.tutorial_id == tutorial_step&.tutorial_id

        errors.add(:base, "Conditional steps must belong to the same tutorial")
      end
    end
end
