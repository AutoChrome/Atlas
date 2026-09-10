class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[show]

  before_action :set_area
  before_action :set_page, only: %i[show edit update destroy move]

  def show
    authorize @page
  end

  def new
    @page = @area.pages.new
    authorize @page
  end

  def create
    @page = @area.pages.new(page_params)
    @page.user = current_user
    authorize @page

    if @page.save
      redirect_to [ @area, @page ], notice: "Page created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @page
  end

  def update
    authorize @page

    if @page.update(page_params)
      # Not [@area, @page] — the edit form lets a page move to a different
      # area (see _form.html.erb), so @area (from the URL this request came
      # in on) may no longer be where the page actually lives. @page.area
      # reflects whatever area_id update just set; reload first since
      # belongs_to's inverse-of caching would otherwise still hand back the
      # original @area instance the association was loaded through.
      redirect_to [ @page.reload.area, @page ], notice: "Page updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @page
    @page.destroy
    redirect_to @area, notice: "Page deleted.", status: :see_other
  end

  # Swap this page's position with the sibling directly above/below it,
  # for simple reordering within an area (used by the sidebar reorder controls).
  def move
    authorize @page, :update?

    direction = params[:direction].to_s
    sibling = case direction
    when "up" then @area.pages.where("position < ?", @page.position).order(position: :desc).first
    when "down" then @area.pages.where("position > ?", @page.position).order(position: :asc).first
    end

    if sibling
      Page.transaction do
        @page.update!(position: sibling.position)
        sibling.update!(position: @page.position_previously_was)
      end
    end

    redirect_to @area
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_page
      @page = @area.pages.friendly.find(params[:slug])
    end

    def page_params
      params.require(:page).permit(
        :title, :content, :public, :position, :icon, :area_id,
        page_attachments_attributes: %i[id label download_filename file _destroy]
      )
    end
end
