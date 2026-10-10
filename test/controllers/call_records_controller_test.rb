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
  test "filters calls to or from a phone number, however it is typed" do
    get call_records_path, params: { number: "(202) 555-0133" }

    assert_select "tbody tr", 1
    assert_select ".summary", text: /to or from \+12025550133/

    get call_records_path, params: { number: "202.555.0142" }

    assert_select "tbody tr", 3
  end

  test "says so when the phone number filter is not a full number" do
    get call_records_path, params: { number: "555-0133" }

    assert_select ".alert", text: /555-0133 is not a full 10-digit phone number/
    assert_select "tbody tr", 3
  end

  test "renders the results inside a turbo frame the filter form targets" do
    get root_path

    assert_select "form.filter-form[data-turbo-frame=calls]"
    assert_select "turbo-frame#calls tbody tr", 3
  end

  test "gives the map one marker per located tower, counting only the filtered calls" do
    place_calls_at_towers

    get call_records_path, params: { to: "2026-03-02" }

    markers = JSON.parse(css_select("[data-controller=map]").sole["data-map-towers-value"])
    assert_equal [ { "code" => "TWR-A", "lat" => 38.9072, "lng" => -77.0369, "calls" => 2,
                     "first" => "2026-03-01 12:00:00", "last" => "2026-03-02 12:00:00" } ], markers
  end

  test "accounts for every call that cannot be placed on the map" do
    place_calls_at_towers
    @import.call_records.create!(started_at: Time.utc(2026, 3, 4, 12), from_number: "+12025550101", to_number: "+12025550142",
                                 duration_seconds: 60, source_line: 5)

    get root_path

    assert_select ".summary", text: "Not on the map: 1 call at a tower with no known location (TWR-B) and 1 call with no tower recorded."
  end

  test "shows no map when no call can be located" do
    get root_path

    assert_select "[data-controller=map]", 0
    assert_select ".summary", text: "Not on the map: 3 calls with no tower recorded."
  end

  private

  # Days 1 and 2 at TWR-A, which has a location; day 3 at TWR-B, which does not.
  def place_calls_at_towers
    @import.towers.create!(code: "TWR-A", latitude: 38.9072, longitude: -77.0369, source_line: 2)
    CallRecord.where(started_at: ..Time.utc(2026, 3, 2, 23)).update_all(cell_tower_id: "TWR-A")
    CallRecord.where(started_at: Time.utc(2026, 3, 3)..).update_all(cell_tower_id: "TWR-B")
  end
end
