class ChartTablesController < ApplicationController
  before_action :set_area
  before_action :set_chart
  before_action :set_chart_table, only: %i[update destroy]

  def create
    @chart_table = @chart.chart_tables.new(chart_table_params)
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
end
