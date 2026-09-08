# Page already declares `belongs_to :user, optional: true`, and
# pages/show.html.erb already guards every read with `if @page.user` — the
# DB's own NOT NULL constraint was the one place still disagreeing.
# NotionSyncJob is the first real case that creates a page with no human
# user behind the request at all (a webhook-triggered background sync, not
# someone clicking "New page"), which is what surfaced this.
class MakePagesUserIdOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :pages, :user_id, true
  end
end
