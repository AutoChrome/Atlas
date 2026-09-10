class Page < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :area

  audited

  belongs_to :area
  belongs_to :user, optional: true
  has_rich_text :content
  has_many :page_attachments, dependent: :destroy
  has_many :notion_sync_deliveries, dependent: :nullify

  # `file` blank AND no `id` means an empty fieldset that was never
  # actually given a file (the template itself, or one added then cleared
  # before submitting) — reject rather than create a PageAttachment with
  # nothing attached. A fieldset WITH an id but no new file is a normal
  # edit to an existing attachment's label/filename, not a re-upload —
  # left alone here, not rejected.
  accepts_nested_attributes_for :page_attachments, allow_destroy: true,
    reject_if: ->(attrs) { attrs["id"].blank? && attrs["file"].blank? }

  # word_start on both fields so a partial word like "onbo" matches
  # "Onboarding" whether it's in the title or the body content.
  searchkick word_start: [ :title, :content ]

  def search_data
    { title: title, content: content.to_plain_text, area_name: area.name, public: publicly_visible? }
  end

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :area_id }

  scope :ordered, -> { order(:position, :title) }
  scope :public_only, -> { where(public: true) }

  def should_generate_new_friendly_id?
    title_changed? || super
  end

  # Visible without logging in if the page itself, or its area (or an
  # ancestor area), has been made public.
  def publicly_visible?
    public? || area.publicly_visible?
  end

  # The most recent Notion sync attempt for this page, if it's one
  # NotionSyncJob manages — matched by Notion's own page ID rather than
  # this row's own #notion_sync_deliveries association, since that only
  # gets linked once a sync actually *succeeds* (see
  # NotionSyncDelivery#mark_succeeded!) — a page's very first sync is
  # still "in progress" from a delivery that has no page_id yet to look up
  # by, but does share the same notion_page_id.
  def current_notion_sync
    return nil if notion_page_id.blank?

    NotionSyncDelivery.where(notion_page_id: notion_page_id).ordered.first
  end

  def notion_syncing?
    current_notion_sync&.syncing? || false
  end
end
