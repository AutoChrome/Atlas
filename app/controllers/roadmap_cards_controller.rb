class RoadmapCardsController < ApplicationController
  before_action :set_project
  before_action :set_roadmap_card, only: %i[update destroy]

  def create
    section = @project.roadmap_sections.find(params[:roadmap_card][:roadmap_section_id])
    @roadmap_card = section.roadmap_cards.new(roadmap_card_params)
    @roadmap_card.position = section.roadmap_cards.maximum(:position).to_i + 1
    authorize @roadmap_card

    if @roadmap_card.save
      redirect_to @project, notice: "Card added."
    else
      redirect_to @project, alert: @roadmap_card.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @roadmap_card

    if @roadmap_card.update(roadmap_card_params)
      redirect_to @project, notice: "Card updated."
    else
      redirect_to @project, alert: @roadmap_card.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @roadmap_card
    @roadmap_card.destroy
    redirect_to @project, notice: "Card deleted.", status: :see_other
  end

  # Persists a drag-and-drop move: the full new card order for one
  # destination section, whether the drop reordered cards within that
  # section or moved them in from a different one. Unifying both cases
  # keeps this to a single bulk update, mirroring RoadmapSectionsController#reorder.
  def move
    section = @project.roadmap_sections.find(params[:roadmap_section_id])
    authorize section.roadmap_cards.new, :move?

    cards = RoadmapCard.joins(:roadmap_section)
                        .where(roadmap_sections: { project_id: @project.id })
                        .where(id: Array(params[:card_ids]))
                        .index_by { |card| card.id.to_s }
    ordered_ids = Array(params[:card_ids]).map(&:to_s) & cards.keys
    return head :unprocessable_entity if ordered_ids.empty?

    RoadmapCard.transaction do
      ordered_ids.each_with_index do |id, index|
        cards.fetch(id).update!(roadmap_section: section, position: index)
      end
    end

    head :ok
  end

  private
    def set_project
      @project = Project.friendly.find(params[:project_slug])
    end

    def set_roadmap_card
      @roadmap_card = RoadmapCard.joins(:roadmap_section)
                                  .where(roadmap_sections: { project_id: @project.id })
                                  .find(params[:id])
    end

    def roadmap_card_params
      params.require(:roadmap_card).permit(:title, :description, :estimated_release_on)
    end
end
