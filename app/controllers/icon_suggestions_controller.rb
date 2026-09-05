# Backs the icon picker's dropdown (see javascript/controllers/icon_picker_controller.js)
# with the full Font Awesome Free solid icon set, rather than embedding all
# ~1,400 names in every area/page form page load.
class IconSuggestionsController < ApplicationController
  def index
    query = params[:q].to_s.strip.downcase
    matches = query.blank? ? Iconable::ALL_ICONS.first(20) : Iconable::ALL_ICONS.grep(/#{Regexp.escape(query)}/).first(20)
    render json: { icons: matches }
  end
end
