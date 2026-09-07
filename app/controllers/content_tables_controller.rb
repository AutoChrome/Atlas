# Backs rich_text_table_controller.js's "Insert table" Trix button and the
# cell-editing it wires up afterward (see content_table_controller.js and
# ContentTable). Not nested under an area/chart/page — a table isn't owned
# by any one of those, it's just embedded in whatever rich text references
# it by signed global ID, same as an ActiveStorage blob.
class ContentTablesController < ApplicationController
  before_action :set_content_table, only: %i[edit update]

  def create
    @content_table = ContentTable.blank
    authorize @content_table

    render json: {
      sgid: @content_table.attachable_sgid,
      content: render_to_string(partial: "content_tables/content_table", formats: [ :html ], locals: { content_table: @content_table })
    }
  end

  # Renders the genuinely-editable version of the table — a real page
  # fragment loaded into a dialog (see rich_text_table_controller.js), not
  # embedded in Trix's own attachment content, so contenteditable/
  # data-action actually work here unlike in the in-editor preview.
  def edit
    authorize @content_table, :update?
    render partial: "content_tables/editable", formats: [ :html ], locals: { content_table: @content_table }
  end

  # `data` arrives as a JSON string, not nested strong-params arrays —
  # Rails' strong parameters has no clean way to permit an array of arrays,
  # and the actual shape is validated by the model regardless (see
  # ContentTable#data_is_a_grid_of_text), so there's nothing extra a
  # permit list would be guarding here.
  def update
    authorize @content_table

    data = JSON.parse(params.require(:content_table).require(:data))
    if @content_table.update(data: data)
      head :ok
    else
      render json: { errors: @content_table.errors.full_messages }, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    render json: { errors: [ "Malformed table data." ] }, status: :unprocessable_entity
  end

  private
    def set_content_table
      @content_table = ContentTable.find(params[:id])
    end
end
