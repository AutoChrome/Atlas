module Api
  module V1
    class AnnouncementsController < Api::BaseController
      before_action :set_announcement, only: %i[show update destroy]

      def index
        authorize Announcement
        @pagy, @announcements = pagy(policy_scope(Announcement).ordered)
      end

      def show
        authorize @announcement
      end

      def create
        @announcement = Announcement.new(announcement_params)
        @announcement.user = current_user
        authorize @announcement

        if @announcement.save
          render :show, status: :created
        else
          render_errors(@announcement)
        end
      end

      def update
        authorize @announcement

        if @announcement.update(announcement_params)
          render :show
        else
          render_errors(@announcement)
        end
      end

      def destroy
        authorize @announcement
        @announcement.destroy
        head :no_content
      end

      private
        def set_announcement
          @announcement = Announcement.find(params[:id])
        end

        def announcement_params
          params.permit(:title, :content, :starts_on, :ends_on)
        end
    end
  end
end
