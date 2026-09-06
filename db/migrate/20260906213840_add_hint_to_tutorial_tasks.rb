class AddHintToTutorialTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tutorial_tasks, :hint, :text
  end
end
