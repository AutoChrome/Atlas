class TutorialTaskResponse < ApplicationRecord
  audited

  belongs_to :tutorial_task
  belongs_to :user

  validates :user_id, uniqueness: { scope: :tutorial_task_id }
end
