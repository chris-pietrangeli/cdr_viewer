require "application_system_test_case"

# Drives the app in a real browser, the way someone would use it: load the
# files, check what was rejected, then narrow down to one phone on the map.
class InvestigationTest < ApplicationSystemTestCase
  test "import calls and towers, then filter to one phone number on the map" do
    visit root_path
    assert_text "No calls found"

    attach_file "file", Rails.root.join("db/sample/calls.csv")
    click_on "Import CSV"

    assert_text "19 calls imported, 8 rows rejected."
    assert_text 'timestamp "yesterday afternoon" is not a recognised date/time'

    click_on "Towers"
    attach_file "file", Rails.root.join("db/sample/towers.csv")
    click_on "Import tower list"

    assert_text "4 towers imported, 6 rows rejected."
    assert_text "tower TWR-0007 already imported with a different location (towers.csv, line 3)"

    click_on "Call records"
    assert_text "19 calls"
    assert_selector ".map path.leaflet-interactive", count: 3
    assert_text "Not on the map: 4 calls at a tower with no known location (TWR-0021) and 1 call with no tower recorded."

    # Set a marker on the page. If filtering reloaded the whole page instead of
    # replacing the Turbo Frame, the marker would be gone afterwards.
    execute_script "document.body.dataset.loadedOnce = 'yes'"

    fill_in "Phone number", with: "(202) 555-0188"
    fill_in "From", with: Date.new(2026, 3, 2)
    click_on "Filter"

    assert_text "4 calls · to or from +12025550188"
    assert_selector "tbody tr", count: 4
    assert_selector ".map path.leaflet-interactive", count: 1
    assert_equal "yes", evaluate_script("document.body.dataset.loadedOnce")

    # The filter is still in the address bar, so the view can be shared.
    assert_equal({ "from" => "2026-03-02", "to" => "", "number" => "(202) 555-0188" },
                 Rack::Utils.parse_query(URI(current_url).query))

    find(".map path.leaflet-interactive").click
    within ".leaflet-popup" do
      assert_text "TWR-0003"
      assert_text "1 call"
    end

    click_on "calls.csv:8"
    assert_text "Import #1"
    assert_text Digest::SHA256.file(Rails.root.join("db/sample/calls.csv")).hexdigest
  end
end
