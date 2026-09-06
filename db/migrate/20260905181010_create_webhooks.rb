class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.string :description, null: false
      t.string :url, null: false
      # Encrypted at rest (see Webhook#encrypts :secret) — needs to be
      # readable back to sign outgoing requests, unlike ApiToken#token_digest
      # which is only ever compared, never decrypted.
      t.string :secret, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :webhooks, :active
  end
end
