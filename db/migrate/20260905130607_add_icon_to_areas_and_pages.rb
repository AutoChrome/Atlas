class AddIconToAreasAndPages < ActiveRecord::Migration[8.1]
  def change
    add_column :areas, :icon, :string
    add_column :pages, :icon, :string
  end
end
