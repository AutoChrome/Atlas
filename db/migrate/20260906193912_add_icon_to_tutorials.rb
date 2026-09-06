class AddIconToTutorials < ActiveRecord::Migration[8.1]
  def change
    add_column :tutorials, :icon, :string
  end
end
