class AddAllAreasToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :all_areas, :boolean, null: false, default: true
  end
end
