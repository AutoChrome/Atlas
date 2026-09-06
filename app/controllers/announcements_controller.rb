class AnnouncementsController < ApplicationController
  before_action :set_announcement, only: %i[show edit update destroy publish]

  def index
    authorize Announcement
    @pagy, @announcements = pagy(policy_scope(Announcement).ordered)
  end

  def show
    authorize @announcement
  end

  def new
    @announcement = Announcement.new
    authorize @announcement
  end

  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.user = current_user
    authorize @announcement

    if @announcement.save
      redirect_to @announcement, notice: "Announcement created as a draft."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @announcement
  end

  def update
    authorize @announcement

    if @announcement.update(announcement_params)
      redirect_to @announcement, notice: "Announcement updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @announcement
    @announcement.destroy
    redirect_to announcements_path, notice: "Announcement deleted.", status: :see_other
  end

  def publish
    authorize @announcement, :publish?
    already_published = @announcement.published?
    @announcement.publish!
    notice = already_published ? "Re-sent to all active webhooks." : "Published — sending to all active webhooks now."
    redirect_to @announcement, notice: notice
  end

  private
    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(:title, :content)
    end
end
