# Backs rich_text_callout_controller.js's Note/Warning/Tip Trix buttons and
# the editing dialog they open afterward — see Callout for why this is an
# attachment rather than a native Trix block type. Not nested under an
# area/chart/page, same reasoning as ContentTablesController: a callout
# isn't owned by any one of those, it's just embedded in whatever rich
# text references it by signed global ID.
class CalloutsController < ApplicationController
  before_action :set_callout, only: %i[edit update]

  def create
    @callout = Callout.blank(variant: callout_variant)
    authorize @callout

    render json: {
      sgid: @callout.attachable_sgid,
      content: render_to_string(partial: "callouts/callout", formats: [ :html ], locals: { callout: @callout })
    }
  end

  # Renders the genuinely-editable version — a real page fragment loaded
  # into a dialog (see rich_text_callout_controller.js), not embedded in
  # Trix's own attachment content.
  def edit
    authorize @callout, :update?
    render partial: "callouts/editable", formats: [ :html ], locals: { callout: @callout }
  end

  def update
    authorize @callout

    if @callout.update(callout_params)
      head :ok
    else
      render json: { errors: @callout.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ArgumentError
    render json: { errors: [ "Not a valid callout type." ] }, status: :unprocessable_entity
  end

  private
    def set_callout
      @callout = Callout.find(params[:id])
    end

    def callout_variant
      Callout.variants.key?(params[:variant]) ? params[:variant] : "note"
    end

    def callout_params
      params.permit(:variant, :body)
    end
end
