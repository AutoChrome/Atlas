class RoadmapSectionsController < ApplicationController
  before_action :set_project
  before_action :set_roadmap_section, only: %i[update destroy]

  def create
    @roadmap_section = @project.roadmap_sections.new(roadmap_section_params)
    @roadmap_section.position = @project.roadmap_sections.maximum(:position).to_i + 1
    authorize @roadmap_section

    if @roadmap_section.save
      redirect_to @project, notice: "Section added."
    else
      redirect_to @project, alert: @roadmap_section.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @roadmap_section

    if @roadmap_section.update(roadmap_section_params)
      redirect_to @project, notice: "Section updated."
    else
      redirect_to @project, alert: @roadmap_section.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @roadmap_section
    @roadmap_section.destroy
    redirect_to @project, notice: "Section deleted.", status: :see_other
  end

  # Persists a drag-and-drop reorder of this project's sections (edit mode).
  def reorder
    sections = @project.roadmap_sections.where(id: Array(params[:section_ids])).index_by { |section| section.id.to_s }
    ordered_ids = Array(params[:section_ids]).map(&:to_s) & sections.keys
    return head :unprocessable_entity if ordered_ids.empty?

    ordered_ids.each { |id| authorize sections.fetch(id), :reorder? }

    RoadmapSection.transaction do
      ordered_ids.each_with_index { |id, index| sections.fetch(id).update!(position: index) }
    end

    head :ok
  end

  private
    def set_project
      @project = Project.friendly.find(params[:project_slug])
    end

    def set_roadmap_section
      @roadmap_section = @project.roadmap_sections.find(params[:id])
    end

    def roadmap_section_params
      params.require(:roadmap_section).permit(:name)
    end
end
