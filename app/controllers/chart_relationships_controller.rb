class ChartRelationshipsController < ApplicationController
  before_action :set_area
  before_action :set_chart
  before_action :set_chart_relationship, only: %i[update destroy]

  def create
    @chart_relationship = @chart.chart_relationships.new(chart_relationship_params)
    authorize @chart_relationship

    respond_to do |format|
      format.json do
        if valid_relationship_columns? && @chart_relationship.save
          render json: { id: @chart_relationship.id }, status: :created
        else
          render json: { errors: @chart_relationship.errors.full_messages }, status: :unprocessable_entity
        end
      end
      format.html do
        if valid_relationship_columns? && @chart_relationship.save
          redirect_to [ @area, @chart ], notice: "Relationship added."
        else
          redirect_to [ @area, @chart ], alert: @chart_relationship.errors.full_messages.to_sentence.presence || "Couldn't add that relationship."
        end
      end
    end
  end

  def update
    authorize @chart_relationship

    if @chart_relationship.update(chart_relationship_edit_params)
      redirect_to [ @area, @chart ], notice: "Relationship updated."
    else
      redirect_to [ @area, @chart ], alert: @chart_relationship.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @chart_relationship
    @chart_relationship.destroy

    respond_to do |format|
      format.json { head :ok }
      format.html { redirect_to [ @area, @chart ], notice: "Relationship deleted.", status: :see_other }
    end
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_chart
      @chart = @area.charts.friendly.find(params[:chart_slug])
    end

    def set_chart_relationship
      @chart_relationship = @chart.chart_relationships.find(params[:id])
    end

    def chart_relationship_params
      params.require(:chart_relationship).permit(:from_chart_column_id, :to_chart_column_id, :on_delete, :on_update)
    end

    def chart_relationship_edit_params
      params.require(:chart_relationship).permit(:on_delete, :on_update)
    end

    # Both columns must belong to a table on THIS chart — without this, a
    # crafted column id from a different chart would let one chart link to
    # another's data.
    def valid_relationship_columns?
      table_ids = @chart.chart_tables.pluck(:id)
      from_ok = ChartColumn.where(id: @chart_relationship.from_chart_column_id, chart_table_id: table_ids).exists?
      to_ok = ChartColumn.where(id: @chart_relationship.to_chart_column_id, chart_table_id: table_ids).exists?
      return true if from_ok && to_ok

      @chart_relationship.errors.add(:base, "Both columns must belong to this chart.")
      false
    end
end
