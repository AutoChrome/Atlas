# Lets an Area or Page carry a Font Awesome icon name (e.g. "rocket"),
# rendered in the sidebar instead of the generic default. `icon` is free
# text, not an enum — ALL_ICONS (every solid-style icon in the self-hosted
# Font Awesome Free set, app/assets/fontawesome) is what IconSuggestionsController
# searches for the picker's dropdown, generated via:
#
#   names = JSON.parse(File.read("icons.json"))
#     .select { |_, v| Array(v["styles"]).include?("solid") }.keys.sort
#
# from Font Awesome's own metadata/icons.json (ships in the "web" package
# alongside the CSS/webfonts already vendored in app/assets/fontawesome).
module Iconable
  ALL_ICONS = Rails.root.join("config/font_awesome_icons.txt").readlines(chomp: true).freeze
end
