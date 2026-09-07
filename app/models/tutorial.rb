class Tutorial < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :description

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :area

  audited

  belongs_to :area
  has_rich_text :description
  has_many :tutorial_steps, -> { order(:position) }, dependent: :destroy, inverse_of: :tutorial

  # word_start on steps_content too — a tutorial's own description is just
  # its overview; the actual instructional content lives in its steps, so
  # without this a search for something a step's body actually says
  # wouldn't find the tutorial it's in at all.
  searchkick word_start: [ :title, :description, :steps_content ]

  def search_data
    {
      title: title,
      description: description.to_plain_text,
      steps_content: tutorial_steps.includes(:rich_text_content).map { |s| "#{s.title} #{s.content.to_plain_text}" }.join(" "),
      area_name: area.name,
      public: publicly_visible?
    }
  end

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :area_id }

  scope :ordered, -> { order(:position, :title) }
  scope :public_only, -> { where(public: true) }

  def should_generate_new_friendly_id?
    title_changed? || super
  end

  # Visible without logging in if the tutorial itself, or its area (or an
  # ancestor area), has been made public.
  def publicly_visible?
    public? || area.publicly_visible?
  end

  def total_tasks_count
    TutorialTask.where(tutorial_step_id: tutorial_steps.select(:id)).count
  end

  def answered_tasks_count(user)
    return 0 unless user

    TutorialTaskResponse.where(user: user, tutorial_task_id: TutorialTask.where(tutorial_step_id: tutorial_steps.select(:id))).count
  end

  # True only when this tutorial's viewing experience has a well-defined,
  # fixed total step count — no task anywhere branches to a different step
  # depending on accept/reject. Only then does a plain "X% through Y steps"
  # progress bar mean anything; a branching path can't have a stable
  # denominator, so the viewer falls back to just counting steps completed
  # instead.
  def linear?
    tutorial_steps.all? do |step|
      step.tutorial_tasks.none? { |task| task.next_step_if_accepted_id || task.next_step_if_rejected_id }
    end
  end
end
