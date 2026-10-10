require "test_helper"

class CallRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @import = create_import(filename: "march.csv")
    [ [ 1, "+12025550101" ], [ 2, "+12025550133" ], [ 3, "+12025550177" ] ].each do |day, from|
      @import.call_records.create!(started_at: Time.utc(2026, 3, day, 12), from_number: from, to_number: "+12025550142",
                                   duration_seconds: 60, source_line: day + 1)
    end
  end

  test "lists every call when no filter is given" do
    get root_path

    assert_response :success
    assert_select "tbody tr", 3
  end

  test "filters calls by date range" do
    get call_records_path, params: { from: "2026-03-02", to: "2026-03-02" }

    assert_select "tbody tr", 1
    assert_select "td", text: "+12025550133"
  end

  test "ignores an unparseable date instead of erroring" do
    get call_records_path, params: { from: "not-a-date" }

    assert_response :success
    assert_select "tbody tr", 3
  end

  test "shows the file and line each call came from" do
    get root_path

    assert_select "td a[href=?]", import_path(@import), text: "march.csv:2"
  end

  test "filters calls by the import they came from" do
    other = create_import(filename: "april.csv")
    other.call_records.create!(started_at: Time.utc(2026, 4, 1, 12), from_number: "+12025550155", to_number: "+12025550142",
                               duration_seconds: 60, source_line: 2)

    get call_records_path, params: { import_id: other.id }

    assert_select "tbody tr", 1
    assert_select "td", text: "+12025550155"
  end
end
