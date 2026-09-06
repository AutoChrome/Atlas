class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.references :user, foreign_key: true
      t.datetime :published_at

      t.timestamps
    end
    add_index :announcements, :published_at
  end
end
