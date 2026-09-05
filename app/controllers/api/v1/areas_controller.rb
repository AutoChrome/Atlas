module Api
  module V1
    class AreasController < Api::BaseController
      before_action :set_area, only: %i[show update destroy]
      before_action :authorize_area_scope!, only: %i[show update destroy]

      def index
        authorize Area
        scope = policy_scope(Area).ordered
        scope = scope.where(id: current_api_token.areas) unless current_api_token.all_areas?
        @pagy, @areas = pagy(scope)
      end

      def show
        authorize @area
      end

      # Only tokens with access to all areas can create new ones — a scoped
      # token has no area to create it "into" (see authorize_area_scope!
      # for how existing areas are checked).
      def create
        unless current_api_token.all_areas?
          return render json: { error: "This API token is scoped to specific areas and can't create new ones." },
                         status: :forbidden
        end

        @area = Area.new(area_params)
        authorize @area

        if @area.save
          render :show, status: :created
        else
          render_errors(@area)
        end
      end

      def update
        authorize @area

        if @area.update(area_params)
          render :show
        else
          render_errors(@area)
        end
      end

      def destroy
        authorize @area
        @area.destroy
        head :no_content
      end

      private
        def set_area
          @area = Area.friendly.find(params[:slug])
        end

        def area_params
          params.permit(:name, :description, :public, :position, :parent_id, :icon)
        end

        def authorize_area_scope!
          render_area_forbidden(@area) unless current_api_token.authorized_for_area?(@area)
        end
    end
  end
end
