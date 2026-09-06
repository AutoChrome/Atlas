class AddDateRangeToAnnouncements < ActiveRecord::Migration[8.1]
  def change
    add_column :announcements, :starts_on, :date
    add_column :announcements, :ends_on, :date
  end
end
