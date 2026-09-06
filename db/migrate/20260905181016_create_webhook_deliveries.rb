class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.references :announcement, null: false, foreign_key: true
      t.integer :status_code
      t.boolean :success, null: false, default: false
      t.text :response_body
      t.string :error_message

      t.timestamps
    end
  end
end
