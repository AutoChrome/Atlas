class TutorialTaskResponsesController < ApplicationController
  before_action :set_area
  before_action :set_tutorial
  before_action :set_tutorial_task, except: :reset_all

  # Idempotent — recording the same tick/cross twice just confirms it, and
  # flipping an existing decision overwrites it rather than erroring.
  def create
    response = @tutorial_task.tutorial_task_responses.find_or_initialize_by(user: current_user)
    authorize response

    response.accepted = ActiveModel::Type::Boolean.new.cast(params[:accepted])
    response.save!
    head :ok
  end

  def destroy
    response = @tutorial_task.tutorial_task_responses.find_by(user: current_user)
    return head :ok unless response

    authorize response
    response.destroy
    head :ok
  end

  # "Start over" — clears every response the current user has recorded
  # anywhere in this tutorial, not just one task.
  def reset_all
    authorize TutorialTaskResponse.new(user: current_user), :destroy?

    TutorialTaskResponse.where(user: current_user, tutorial_task_id: TutorialTask.where(tutorial_step_id: @tutorial.tutorial_steps.select(:id))).delete_all
    head :ok
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_tutorial
      @tutorial = @area.tutorials.friendly.find(params[:tutorial_slug])
    end

    # Scoped through this tutorial's own steps — a tutorial_task_id
    # belonging to a different tutorial 404s here instead of letting a
    # visitor mark progress on content they weren't even shown.
    def set_tutorial_task
      @tutorial_task = TutorialTask.joins(:tutorial_step)
                                    .where(tutorial_steps: { tutorial_id: @tutorial.id })
                                    .find(params[:tutorial_task_id])
    end
end
