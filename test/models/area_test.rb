require "test_helper"

class AreaTest < ActiveSupport::TestCase
  test "path_name is just the area's own name at the top level" do
    assert_equal "Area One", areas(:one).path_name
  end

  test "path_name walks up through every ancestor" do
    grandparent = Area.create!(name: "Sales")
    parent = Area.create!(name: "EMEA", parent: grandparent)
    child = Area.create!(name: "Onboarding", parent: parent)

    assert_equal "Sales > EMEA > Onboarding", child.path_name
  end

  test "path_name tells apart two areas that share a name under different parents" do
    sales = Area.create!(name: "Sales")
    support = Area.create!(name: "Support")
    sales_general = Area.create!(name: "General", parent: sales)
    support_general = Area.create!(name: "General", parent: support)

    assert_equal "Sales > General", sales_general.path_name
    assert_equal "Support > General", support_general.path_name
    assert_not_equal sales_general.path_name, support_general.path_name
  end
end
