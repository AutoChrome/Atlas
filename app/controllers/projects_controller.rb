class ProjectsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_project, only: %i[show edit update destroy]

  def index
    authorize Project
    @projects = policy_scope(Project).order(:name)
  end

  def show
    authorize @project
    @roadmap_sections = @project.roadmap_sections.includes(:roadmap_cards)
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project

    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: "Project deleted.", status: :see_other
  end

  private
    def set_project
      @project = Project.friendly.find(params[:slug])
    end

    def project_params
      params.require(:project).permit(:name, :description, :public)
    end
end
