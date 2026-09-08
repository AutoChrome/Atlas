# Lets a WebhookDelivery outlive the Announcement it was about — needed for
# "announcement.deleted" deliveries, whose whole point is a notification
# sent AFTER the announcement is already gone, and for existing
# published/updated delivery history to survive that same deletion instead
# of being cascade-destroyed with it (see Announcement's has_many change
# from dependent: :destroy to dependent: :nullify).
class ChangeWebhookDeliveriesAnnouncementIdToOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :webhook_deliveries, :announcement_id, true
  end
end
