class CreateContentTables < ActiveRecord::Migration[8.1]
  def change
    create_table :content_tables do |t|
      t.jsonb :data, null: false, default: []

      t.timestamps
    end
  end
end
