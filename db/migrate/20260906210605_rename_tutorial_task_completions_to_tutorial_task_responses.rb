class RenameTutorialTaskCompletionsToTutorialTaskResponses < ActiveRecord::Migration[8.1]
  def change
    rename_table :tutorial_task_completions, :tutorial_task_responses

    # A row used to mean "done"; now it means "decided," with `accepted`
    # telling ticked from crossed — existing completions were all ticks, so
    # backfilling true via the column default is correct for them.
    add_column :tutorial_task_responses, :accepted, :boolean, default: true, null: false
  end
end
