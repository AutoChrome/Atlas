class CreateCallouts < ActiveRecord::Migration[8.1]
  def change
    create_table :callouts do |t|
      t.integer :variant, null: false, default: 0
      t.text :body, null: false, default: ""

      t.timestamps
    end
  end
end
