class TutorialStep < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  audited

  belongs_to :tutorial
  has_rich_text :content
  has_many_attached :attachments
  has_many :tutorial_tasks, -> { order(:position) }, dependent: :destroy, inverse_of: :tutorial_step
  has_many :incoming_accept_branches, class_name: "TutorialTask", foreign_key: :next_step_if_accepted_id,
                                       dependent: :nullify, inverse_of: :next_step_if_accepted
  has_many :incoming_reject_branches, class_name: "TutorialTask", foreign_key: :next_step_if_rejected_id,
                                       dependent: :nullify, inverse_of: :next_step_if_rejected

  # Lets the step's own form manage its tasks as nested fieldsets —
  # added/removed client-side (see nested_fields_controller.js) and saved
  # together with the step in one submission, on both the new and edit
  # forms. `reject_if` drops a fieldset the user added but never touched,
  # rather than saving an empty task.
  accepts_nested_attributes_for :tutorial_tasks, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true

  scope :ordered, -> { order(:position) }

  # Nested attributes assign children in submission order, not a meaningful
  # position — reassign from that order on every save (new or existing) so
  # drag-free reordering-by-editing still keeps positions sane.
  before_save :reposition_nested_children

  def decided_for?(user)
    return false unless user
    return false if tutorial_tasks.none?

    tutorial_tasks.all? { |task| task.decided_for?(user) }
  end

  # Where a viewer lands after this step absent any per-task branching —
  # the next step in authoring order, or nil at the end of the tutorial.
  # A task's own next_step_if_accepted/next_step_if_rejected (evaluated
  # client-side against the viewer's actual answers) takes priority over
  # this when present.
  def default_next_step
    tutorial.tutorial_steps.where("position > ?", position).ordered.first
  end

  private
    def reposition_nested_children
      tutorial_tasks.each_with_index { |task, index| task.position = index }
    end
end
