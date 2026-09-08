class CreateNotionConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :notion_connections do |t|
      t.string :name, null: false
      # Both encrypted at rest (config/initializers/active_record_encryption.rb)
      # — same reasoning as Webhook#secret: read back later to call the
      # Notion API / verify inbound signatures, not just compared, so a
      # digest won't do.
      t.string :integration_token, null: false
      # Notion hands this to us on the first webhook delivery (a one-time
      # handshake payload), rather than us generating it — nil until that
      # happens. See NotionConnection#awaiting_verification?.
      t.string :verification_token
      # The URL-path secret (see Webhook's own webhook_token-less design —
      # its secret is a real HMAC key already; Notion's inbound webhook has
      # no signature to check until verification_token exists, so this is
      # the ONLY thing standing in for verification during that gap, same
      # reasoning as BASECAMP_WEBHOOK_TOKEN).
      t.string :webhook_token, null: false
      t.references :area, null: false, foreign_key: true
      t.boolean :active, default: true, null: false
      # Purely informational (what's shown in Notion's own UI, e.g. "IAN's
      # Notion") — never used to authenticate or address anything.
      t.string :notion_workspace_name

      t.timestamps
    end
    add_index :notion_connections, :webhook_token, unique: true
  end
end
