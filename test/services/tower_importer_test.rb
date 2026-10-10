require "test_helper"

class TowerImporterTest < ActiveSupport::TestCase
  HEADER = "tower_id,latitude,longitude".freeze

  def import(*rows, filename: "towers.csv")
    TowerImporter.new(StringIO.new([ HEADER, *rows ].join("\n")), filename: filename).call
  end

  test "imports a tower and records where it came from" do
    result = import("TWR-0003,38.9072,-77.0369")

    assert result.success?
    assert_equal "towers", result.kind
    assert_equal 1, result.imported_count

    tower = Tower.sole
    assert_equal "TWR-0003", tower.code
    assert_equal BigDecimal("38.9072"), tower.latitude
    assert_equal BigDecimal("-77.0369"), tower.longitude
    assert_equal [ result, 2 ], [ tower.import, tower.source_line ]
  end

  test "strips whitespace and upcases the tower id so it matches the call records" do
    import(" twr-0012 , 38.8816 , -76.9950 ")

    assert_equal "TWR-0012", Tower.sole.code
  end

  test "rejects coordinates that are missing, not numbers or out of range" do
    result = import("TWR-1,,-77.0369",
                    "TWR-2,N/A,-77.0369",
                    "TWR-3,138.9072,-77.0369",
                    "TWR-4,38.9072,-277.0369",
                    "TWR-5,38.9072N,77.0369W")

    assert_equal 0, Tower.count
    assert_equal [
      "latitude is missing",
      'latitude "N/A" is not a number between -90 and 90',
      'latitude "138.9072" is not a number between -90 and 90',
      'longitude "-277.0369" is not a number between -180 and 180',
      'latitude "38.9072N" is not a number between -90 and 90'
    ], result.rejected_rows.order(:line_number).pluck(:reason)
  end

  test "rejects the 0, 0 placeholder location" do
    result = import("TWR-1,0,0", "TWR-2,0.000000,-0.0")

    assert_equal 0, Tower.count
    assert_equal [ "coordinates 0, 0 are a placeholder, not a location" ], result.rejected_rows.pluck(:reason).uniq
  end

  test "accepts a tower on the equator or the prime meridian" do
    assert_equal 2, import("TWR-1,0,-78.4678", "TWR-2,51.4779,0").imported_count
  end

  test "rejects a row with no tower id" do
    assert_equal "tower id is missing", import(",38.9072,-77.0369").rejected_rows.sole.reason
  end

  test "never moves a tower that is already known" do
    import("TWR-1,38.9072,-77.0369", filename: "january.csv")
    result = import("TWR-1,38.9510,-77.0120", filename: "february.csv")

    assert_equal "tower TWR-1 already imported with a different location (january.csv, line 2)", result.rejected_rows.sole.reason
    assert_equal BigDecimal("38.9072"), Tower.sole.latitude
  end

  test "rejects a repeat of a tower at the same location as a plain duplicate" do
    result = import("TWR-1,38.9072,-77.0369", "twr-1,38.907200,-77.036900")

    assert_equal "tower TWR-1 already imported (towers.csv, line 2)", result.rejected_rows.sole.reason
  end

  test "refuses a call records file" do
    result = TowerImporter.import_file(Rails.root.join("db/sample/calls.csv"))

    assert_not result.success?
    assert_match(/\AUnrecognised column layout/, result.error)
  end

  test "imports the bundled sample file" do
    result = TowerImporter.import_file(Rails.root.join("db/sample/towers.csv"))

    assert result.success?
    assert_equal 4, result.imported_count
    assert_equal 6, result.rejected_rows_count
  end
end
