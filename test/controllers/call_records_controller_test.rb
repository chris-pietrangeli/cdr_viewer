require "test_helper"

class CallRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    [ [ 1, "+12025550101" ], [ 2, "+12025550133" ], [ 3, "+12025550177" ] ].each do |day, from|
      CallRecord.create!(started_at: Time.utc(2026, 3, day, 12), from_number: from, to_number: "+12025550142", duration_seconds: 60)
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

  test "uploading a CSV imports it and shows the rejected rows" do
    file = fixture_file_upload("calls.csv", "text/csv")

    assert_difference -> { CallRecord.count }, 1 do
      post imports_path, params: { file: file }
    end

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "td", text: "duration is missing"
  end

  test "importing without a file redirects with a message" do
    post imports_path

    assert_redirected_to root_path
  end
end
