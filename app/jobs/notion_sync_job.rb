# Fetches a single Notion page's current title + content and creates or
# updates the matching Atlas Page — see Integrations::NotionController for
# what enqueues this (a page.created / page.content_updated /
# page.properties_updated webhook event) and NotionConnection for the
# credentials used. Runs in the background so the webhook receiver can
# return quickly regardless of how long Notion's API takes to answer.
#
# `delivery_id` is the NotionSyncDelivery row the controller already
# created for this event (see NotionSyncDelivery) — updated here as the
# sync actually progresses, so the connection's own page can show "this
# page is syncing right now" and, once done, exactly what happened.
# Optional and defaulted to nil purely so a job already serialized and
# queued from before this argument existed doesn't fail outright — every
# new enqueue passes a real one.
class NotionSyncJob < ApplicationJob
  queue_as :default

  def perform(notion_connection_id, notion_page_id, delivery_id = nil)
    delivery = NotionSyncDelivery.find_by(id: delivery_id)
    connection = NotionConnection.active.find_by(id: notion_connection_id)
    unless connection
      delivery&.mark_failed!("Connection no longer exists or is inactive")
      return
    end

    delivery&.mark_syncing!

    client = NotionClient.new(connection.integration_token)
    notion_page = client.retrieve_page(notion_page_id)
    if notion_page["archived"] || notion_page["in_trash"]
      delivery&.mark_ignored!("Notion page is archived or in the trash")
      return
    end

    blocks = client.retrieve_block_children(notion_page_id)

    page = connection.area.pages.find_or_initialize_by(notion_page_id: notion_page_id)
    page.title = NotionClient.extract_title(notion_page)
    page.content = NotionBlocksToHtml.convert(blocks)
    # Never made public automatically, even on the first sync — same
    # reasoning as the Basecamp integration landing as a draft rather than
    # a live announcement: content pulled from an external system should
    # be reviewed before anyone outside the team can see it, not go live
    # the instant someone saves a Notion page. Left alone on later syncs —
    # if a person has since made it public, a content update shouldn't
    # silently revert that.
    page.public = false if page.new_record?
    page.save!

    delivery&.mark_succeeded!(page)
  rescue NotionClient::Error => e
    Rails.logger.error("Notion sync failed for page #{notion_page_id}: #{e.message}")
    delivery&.mark_failed!(e.message)
  end
end
