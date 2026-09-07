class ChartIndicesController < ApplicationController
  before_action :set_area
  before_action :set_chart
  before_action :set_chart_table, only: %i[new]
  before_action :set_chart_index, only: %i[update destroy]

  # Rendered on demand (see modal_controller.js's lazy-load support) rather
  # than inline for every table.
  def new
    authorize ChartIndex.new(chart_table: @chart_table), :create?
    render partial: "chart_indices/form", locals: { area: @area, chart: @chart, table: @chart_table }
  end

  def create
    chart_table = @chart.chart_tables.find(params[:chart_index][:chart_table_id])
    @chart_index = chart_table.chart_indices.new(chart_index_params)
    authorize @chart_index

    if @chart_index.save
      redirect_to [ @area, @chart ], notice: "Index added."
    else
      redirect_to [ @area, @chart ], alert: @chart_index.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @chart_index

    if @chart_index.update(chart_index_params)
      redirect_to [ @area, @chart ], notice: "Index updated."
    else
      redirect_to [ @area, @chart ], alert: @chart_index.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @chart_index
    @chart_index.destroy
    redirect_to [ @area, @chart ], notice: "Index deleted.", status: :see_other
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_chart
      @chart = @area.charts.friendly.find(params[:chart_slug])
    end

    def set_chart_table
      @chart_table = @chart.chart_tables.find(params[:chart_table_id])
    end

    def set_chart_index
      @chart_index = ChartIndex.joins(:chart_table).where(chart_tables: { chart_id: @chart.id }).find(params[:id])
    end

    def chart_index_params
      params.require(:chart_index).permit(:name, :columns, :unique)
    end
end
