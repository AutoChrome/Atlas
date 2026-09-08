class AddPublishedWebhookIdsToAnnouncements < ActiveRecord::Migration[8.1]
  def change
    add_column :announcements, :published_webhook_ids, :jsonb, default: [], null: false
  end
end
