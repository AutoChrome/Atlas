class ApiTokensController < ApplicationController
  # Managing your own tokens isn't part of what guest preview simulates —
  # it should keep working normally for the real signed-in user regardless.
  def index
    @api_tokens = real_current_user.api_tokens.order(created_at: :desc)
    @api_token = ApiToken.new
    @areas = Area.ordered
  end

  def create
    @api_token = real_current_user.api_tokens.new(api_token_params)
    @api_token.area_ids = [] if @api_token.all_areas?

    if @api_token.save
      flash[:new_api_token] = @api_token.plaintext_token
      redirect_to api_tokens_path, notice: "API token \"#{@api_token.name}\" created. Copy it now — you won't see it again."
    else
      @api_tokens = real_current_user.api_tokens.order(created_at: :desc)
      @areas = Area.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    real_current_user.api_tokens.find(params[:id]).destroy
    redirect_to api_tokens_path, notice: "API token revoked.", status: :see_other
  end

  def docs
  end

  # Both generated from ApiSpec::RESOURCES — see those classes for why this
  # stays in sync with the parameter tables on the docs page automatically.
  def openapi
    document = OpenapiDocumentBuilder.build(base_url: request.base_url)
    send_data JSON.pretty_generate(document),
              filename: "atlas-openapi.json", type: "application/json", disposition: "attachment"
  end

  def bruno_collection
    send_data bruno_collection_zip,
              filename: "atlas-api-bruno-collection.zip", type: "application/zip", disposition: "attachment"
  end

  private
    def api_token_params
      params.require(:api_token).permit(:name, :all_areas, area_ids: [])
    end

    def bruno_collection_zip
      files = BrunoCollectionBuilder.build(base_url: request.base_url)

      buffer = Zip::OutputStream.write_buffer do |zip|
        files.each do |path, content|
          zip.put_next_entry(path)
          zip.write(content)
        end
      end

      buffer.string
    end
end
