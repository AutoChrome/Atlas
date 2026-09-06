class RemoveDescriptionFromTutorials < ActiveRecord::Migration[8.1]
  def change
    # Moving to a WYSIWYG (ActionText) description, same as TutorialStep's
    # own content — has_rich_text stores it via the existing polymorphic
    # action_text_rich_texts table, not a column on this table.
    remove_column :tutorials, :description, :text
  end
end
