class ChartTablesController < ApplicationController
  before_action :set_area
  before_action :set_chart
  before_action :set_chart_table, only: %i[update destroy reposition]

  def create
    @chart_table = @chart.chart_tables.new(chart_table_params)
    # Lay new tables out in a grid so they don't all land on top of each
    # other at the (0, 0) default — matches SqlSchemaParser's auto-layout.
    position = @chart.chart_tables.count
    @chart_table.position_x = (position % 4) * 320
    @chart_table.position_y = (position / 4) * 360
    authorize @chart_table

    if @chart_table.save
      redirect_to [ @area, @chart ], notice: "Table added."
    else
      redirect_to [ @area, @chart ], alert: @chart_table.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @chart_table

    if @chart_table.update(chart_table_params)
      redirect_to [ @area, @chart ], notice: "Table updated."
    else
      redirect_to [ @area, @chart ], alert: @chart_table.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @chart_table
    @chart_table.destroy
    redirect_to [ @area, @chart ], notice: "Table deleted.", status: :see_other
  end

  # Persists the final x/y from a canvas drag — fired once on drag end,
  # not on every pointer move (see chart_canvas_controller.js).
  def reposition
    authorize @chart_table, :reposition?
    @chart_table.update(chart_table_position_params)
    head :ok
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_chart
      @chart = @area.charts.friendly.find(params[:chart_slug])
    end

    def set_chart_table
      @chart_table = @chart.chart_tables.find(params[:id])
    end

    def chart_table_params
      params.require(:chart_table).permit(:name, :notes)
    end

    def chart_table_position_params
      params.require(:chart_table).permit(:position_x, :position_y)
    end
end
