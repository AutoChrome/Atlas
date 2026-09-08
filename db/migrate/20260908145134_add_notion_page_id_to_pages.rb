class AddNotionPageIdToPages < ActiveRecord::Migration[8.1]
  def change
    # Nil for every ordinary page — only set on ones NotionSyncJob created,
    # so a later page.content_updated event can find and update the SAME
    # Atlas page instead of creating a duplicate every time. Notion's page
    # IDs are globally unique (not just within one workspace), so this
    # doesn't need to be scoped to anything.
    add_column :pages, :notion_page_id, :string
    add_index :pages, :notion_page_id, unique: true
  end
end
