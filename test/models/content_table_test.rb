require "test_helper"

class ContentTableTest < ActiveSupport::TestCase
  test ".blank creates a grid of empty text cells at the requested size" do
    table = ContentTable.blank(rows: 2, columns: 3)

    assert_equal 2, table.data.size
    assert table.data.all? { |row| row == [ "", "", "" ] }
  end

  test "is invalid when a row isn't an array" do
    table = ContentTable.new(data: [ "not a row" ])
    assert_not table.valid?
  end

  test "is invalid when a cell isn't a string" do
    table = ContentTable.new(data: [ [ 1, 2 ] ])
    assert_not table.valid?
  end

  test "is invalid when rows have different column counts" do
    table = ContentTable.new(data: [ [ "a", "b" ], [ "c" ] ])
    assert_not table.valid?
  end

  test "is valid with a consistent grid of text, including an empty table" do
    assert ContentTable.new(data: [ [ "a", "b" ], [ "c", "d" ] ]).valid?
    assert ContentTable.new(data: []).valid?
  end

  test "column_count reflects the first row, and is zero for an empty table" do
    assert_equal 2, ContentTable.new(data: [ [ "a", "b" ] ]).column_count
    assert_equal 0, ContentTable.new(data: []).column_count
  end

  test "renders as a real ActionText attachable, the same read-only partial in both contexts" do
    table = content_tables(:one)

    assert_equal "content_tables/content_table", table.to_attachable_partial_path
    assert_equal "content_tables/content_table", table.to_trix_content_attachment_partial_path
    assert table.attachable_sgid.present?
  end
end
