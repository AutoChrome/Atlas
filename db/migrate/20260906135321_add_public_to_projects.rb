class AddPublicToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :public, :boolean, default: false, null: false
    add_index :projects, :public
  end
end
