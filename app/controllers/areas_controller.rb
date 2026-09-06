class AreasController < ApplicationController
  allow_unauthenticated_access only: %i[index show]

  before_action :set_area, only: %i[show edit update destroy]

  def index
    authorize Area
    @areas = policy_scope(Area).top_level.ordered_by(area_sort_mode)
    @latest_announcement = policy_scope(Announcement).published.includes(webhook_deliveries: :webhook).first
  end

  def show
    authorize @area
    @child_areas = policy_scope(@area.children).ordered_by(area_sort_mode)
    @pages = policy_scope(@area.pages).ordered
  end

  def new
    @area = Area.new(parent_id: params[:parent_id])
    authorize @area
  end

  def create
    @area = Area.new(area_params)
    authorize @area

    if @area.save
      redirect_to @area, notice: "Area created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @area
  end

  def update
    authorize @area

    if @area.update(area_params)
      redirect_to @area, notice: "Area updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @area
    @area.destroy
    redirect_to areas_path, notice: "Area deleted.", status: :see_other
  end

  # Persists a drag-and-drop reorder from the sidebar. area_ids is the new
  # order for one sibling group (all areas sharing the same parent) — moving
  # an area to a *different* parent isn't supported here, only reordering
  # within its current one.
  def reorder
    areas = Area.where(id: Array(params[:area_ids])).index_by { |area| area.id.to_s }
    ordered_ids = Array(params[:area_ids]).map(&:to_s) & areas.keys
    return head :unprocessable_entity if ordered_ids.empty?

    unless ordered_ids.map { |id| areas.fetch(id).parent_id }.uniq.size == 1
      return head :unprocessable_entity
    end

    ordered_ids.each { |id| authorize areas.fetch(id), :update? }

    Area.transaction do
      ordered_ids.each_with_index { |id, index| areas.fetch(id).update!(position: index) }
    end

    head :ok
  end

  private
    def set_area
      @area = Area.friendly.find(params[:slug])
    end

    def area_params
      params.require(:area).permit(:name, :description, :public, :position, :parent_id, :icon)
    end
end
