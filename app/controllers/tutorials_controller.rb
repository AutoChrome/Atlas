class TutorialsController < ApplicationController
  allow_unauthenticated_access only: %i[show]

  before_action :set_area
  before_action :set_tutorial, only: %i[show edit update destroy]

  def show
    authorize @tutorial

    @steps = @tutorial.tutorial_steps.includes(:tutorial_tasks).ordered
    @linear = @tutorial.linear?
    @total_steps = @linear ? @steps.size : nil

    task_ids = @steps.flat_map { |s| s.tutorial_tasks.map(&:id) }
    @responses = current_user ? TutorialTaskResponse.where(user: current_user, tutorial_task_id: task_ids).index_by(&:tutorial_task_id) : {}
  end

  def new
    @tutorial = @area.tutorials.new
    authorize @tutorial
  end

  def create
    @tutorial = @area.tutorials.new(tutorial_params)
    authorize @tutorial

    if @tutorial.save
      redirect_to [ @area, @tutorial ], notice: "Tutorial created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @tutorial
  end

  def update
    authorize @tutorial

    if @tutorial.update(tutorial_params)
      redirect_to [ @area, @tutorial ], notice: "Tutorial updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @tutorial
    @tutorial.destroy
    redirect_to @area, notice: "Tutorial deleted.", status: :see_other
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_tutorial
      @tutorial = @area.tutorials.friendly.find(params[:slug])
    end

    def tutorial_params
      params.require(:tutorial).permit(:title, :description, :public, :icon)
    end
end
