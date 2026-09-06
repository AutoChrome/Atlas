class TutorialStepsController < ApplicationController
  before_action :set_area
  before_action :set_tutorial
  before_action :set_tutorial_step, only: %i[edit update destroy]

  def new
    @tutorial_step = @tutorial.tutorial_steps.new
    # A step starts as one big task by default — "broken into multiple
    # tasks" is something the author opts into by adding more fieldsets
    # before ever saving.
    @tutorial_step.tutorial_tasks.build(description: "Complete this step")
    authorize @tutorial_step
  end

  def create
    @tutorial_step = @tutorial.tutorial_steps.new(tutorial_step_params)
    @tutorial_step.position = @tutorial.tutorial_steps.maximum(:position).to_i + 1
    authorize @tutorial_step

    if @tutorial_step.save
      redirect_to [ @area, @tutorial ], notice: "Step added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @tutorial_step
  end

  def update
    authorize @tutorial_step

    if @tutorial_step.update(tutorial_step_params)
      redirect_to [ @area, @tutorial ], notice: "Step updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @tutorial_step
    @tutorial_step.destroy
    redirect_to [ @area, @tutorial ], notice: "Step deleted.", status: :see_other
  end

  # Persists a drag-and-drop reorder of this tutorial's steps.
  def reorder
    steps = @tutorial.tutorial_steps.where(id: Array(params[:step_ids])).index_by { |step| step.id.to_s }
    ordered_ids = Array(params[:step_ids]).map(&:to_s) & steps.keys
    return head :unprocessable_entity if ordered_ids.empty?

    ordered_ids.each { |id| authorize steps.fetch(id), :reorder? }

    TutorialStep.transaction do
      ordered_ids.each_with_index { |id, index| steps.fetch(id).update!(position: index) }
    end

    head :ok
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_tutorial
      @tutorial = @area.tutorials.friendly.find(params[:tutorial_slug])
    end

    def set_tutorial_step
      @tutorial_step = @tutorial.tutorial_steps.find(params[:id])
    end

    def tutorial_step_params
      params.require(:tutorial_step).permit(
        :title, :content, attachments: [],
        tutorial_tasks_attributes: %i[id description hint next_step_if_accepted_id next_step_if_rejected_id _destroy]
      )
    end
end
