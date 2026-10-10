require "test_helper"

class TowersControllerTest < ActionDispatch::IntegrationTest
  test "lists towers with their coordinates and source" do
    import = create_import(filename: "towers.csv")
    import.towers.create!(code: "TWR-0003", latitude: 38.9072, longitude: -77.0369, source_line: 2)

    get towers_path

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "td", text: "38.907200"
    assert_select "td a[href=?]", import_path(import), text: "towers.csv:2"
  end

  test "explains what to upload when there are no towers" do
    get towers_path

    assert_select ".empty", text: /No towers yet/
  end
end
