# One row per inbound Notion webhook request — see
# Integrations::NotionController and NotionSyncJob. Deliberately logs
# EVERYTHING received (a verification handshake, an event type Atlas
# doesn't act on, a bad signature), not just successful syncs — the whole
# point is answering "did Notion even contact us, and what happened" when
# nothing seems to be arriving.
class CreateNotionSyncDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :notion_sync_deliveries do |t|
      t.references :notion_connection, null: false, foreign_key: true
      # Nullable and set only on success — a delivery is created (status
      # "syncing") before the Atlas page necessarily exists yet, for a
      # brand new Notion page's first-ever sync.
      t.references :page, null: true, foreign_key: true
      t.string :event_type, null: false
      # Notion's own page ID, not this row's own id — used to look up "is
      # THIS page currently syncing" (see Page#current_notion_sync)
      # independent of whether an Atlas page has been linked yet.
      t.string :notion_page_id
      t.integer :status, null: false, default: 0
      t.string :error_message
      t.datetime :completed_at

      t.timestamps
    end
    add_index :notion_sync_deliveries, :notion_page_id
    add_index :notion_sync_deliveries, [ :notion_connection_id, :created_at ]
  end
end
