class ChartColumnsController < ApplicationController
  before_action :set_area
  before_action :set_chart
  before_action :set_chart_table, only: %i[new]
  before_action :set_chart_column, only: %i[edit update destroy]

  # Rendered on demand (see modal_controller.js's lazy-load support) rather
  # than inline for every table — a chart with hundreds of tables was
  # otherwise eagerly rendering this same static form hundreds of times
  # over for content nobody was currently looking at.
  def new
    authorize ChartColumn.new(chart_table: @chart_table), :create?
    render partial: "chart_columns/new_form", locals: { area: @area, chart: @chart, table: @chart_table }
  end

  # Same reasoning as #new, but for editing — this one matters far more:
  # one of these was being rendered for *every column on every table*, by
  # far the single biggest contributor to a large chart's page weight.
  def edit
    authorize @chart_column, :update?
    render partial: "chart_columns/edit_form",
      locals: { area: @area, chart: @chart, table: @chart_column.chart_table, column: @chart_column }
  end

  def create
    chart_table = @chart.chart_tables.find(params[:chart_column][:chart_table_id])
    @chart_column = chart_table.chart_columns.new(chart_column_params)
    @chart_column.position = chart_table.chart_columns.maximum(:position).to_i + 1
    authorize @chart_column

    if @chart_column.save
      redirect_to [ @area, @chart ], notice: "Column added."
    else
      redirect_to [ @area, @chart ], alert: @chart_column.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @chart_column

    if @chart_column.update(chart_column_params)
      redirect_to [ @area, @chart ], notice: "Column updated."
    else
      redirect_to [ @area, @chart ], alert: @chart_column.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @chart_column
    @chart_column.destroy
    redirect_to [ @area, @chart ], notice: "Column deleted.", status: :see_other
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

    # Scoped through this chart's own tables — a chart_column_id belonging
    # to a different chart 404s here instead of being editable.
    def set_chart_column
      @chart_column = ChartColumn.joins(:chart_table).where(chart_tables: { chart_id: @chart.id }).find(params[:id])
    end

    def chart_column_params
      params.require(:chart_column).permit(:name, :data_type, :primary_key, :nullable, :unique, :default_value)
    end
end
