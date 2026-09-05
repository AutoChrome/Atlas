module Api
  module V1
    class PagesController < Api::BaseController
      before_action :set_page, only: %i[show update destroy]
      before_action :authorize_area_scope!, only: %i[show update destroy]

      def index
        authorize Page
        scope = policy_scope(Page).ordered
        scope = scope.where(area_id: current_api_token.areas) unless current_api_token.all_areas?
        scope = scope.where(area_id: params[:area_id]) if params[:area_id].present?
        @pagy, @pages = pagy(scope)
      end

      def show
        authorize @page
      end

      def create
        area = Area.find_by(id: page_params[:area_id])
        return render json: { error: "area_id is required and must reference an existing area." },
                       status: :unprocessable_entity unless area
        return render_area_forbidden(area) unless current_api_token.authorized_for_area?(area)

        @page = Page.new(page_params)
        @page.user = current_user
        authorize @page

        if @page.save
          render :show, status: :created
        else
          render_errors(@page)
        end
      end

      def update
        authorize @page

        # Moving a page to a different area requires access to that area too.
        if page_params[:area_id].present? && page_params[:area_id].to_s != @page.area_id.to_s
          new_area = Area.find_by(id: page_params[:area_id])
          return render json: { error: "area_id must reference an existing area." },
                         status: :unprocessable_entity unless new_area
          return render_area_forbidden(new_area) unless current_api_token.authorized_for_area?(new_area)
        end

        if @page.update(page_params)
          render :show
        else
          render_errors(@page)
        end
      end

      def destroy
        authorize @page
        @page.destroy
        head :no_content
      end

      private
        def set_page
          @page = Page.find(params[:id])
        end

        def page_params
          params.permit(:area_id, :title, :content, :public, :position, :icon)
        end

        def authorize_area_scope!
          render_area_forbidden(@page.area) unless current_api_token.authorized_for_area?(@page.area)
        end
    end
  end
end
