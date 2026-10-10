require "test_helper"

class CdrImporterTest < ActiveSupport::TestCase
  HEADER = "timestamp,from_number,to_number,duration,cell_tower_id".freeze

  def import(*rows, header: HEADER)
    CdrImporter.new(StringIO.new([ header, *rows ].join("\n"))).call
  end

  test "imports a clean row" do
    result = import("2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-0012")

    assert result.success?
    assert_equal 1, result.imported
    assert_empty result.rejections

    call = CallRecord.sole
    assert_equal Time.utc(2026, 3, 1, 8, 14, 22), call.started_at
    assert_equal "+12025550101", call.from_number
    assert_equal "+12025550142", call.to_number
    assert_equal 187, call.duration_seconds
    assert_equal "TWR-0012", call.cell_tower_id
  end

  test "normalises phone number formats to E.164" do
    import("2026-03-01 08:00:00,(202) 555-0142,202.555.0177,10,TWR-1",
           "2026-03-01 09:00:00,+1 202 555 0101,12025550133,10,TWR-1")

    assert_equal [ %w[+12025550142 +12025550177], %w[+12025550101 +12025550133] ],
                 CallRecord.chronological.pluck(:from_number, :to_number)
  end

  test "accepts US-style and ISO 8601 timestamps" do
    import("03/02/2026 2:15 PM,+12025550101,+12025550142,10,TWR-1",
           "2026-03-03T09:12:00Z,+12025550101,+12025550142,10,TWR-1",
           "2026-03-04T09:00:00-05:00,+12025550101,+12025550142,10,TWR-1")

    assert_equal [ Time.utc(2026, 3, 2, 14, 15), Time.utc(2026, 3, 3, 9, 12), Time.utc(2026, 3, 4, 14, 0) ],
                 CallRecord.chronological.pluck(:started_at)
  end

  test "accepts durations as seconds, m:ss or h:mm:ss" do
    import("2026-03-01 08:00:00,+12025550101,+12025550142,47,TWR-1",
           "2026-03-01 09:00:00,+12025550101,+12025550142,2:05,TWR-1",
           "2026-03-01 10:00:00,+12025550101,+12025550142,01:10:30,TWR-1")

    assert_equal [ 47, 125, 4230 ], CallRecord.chronological.pluck(:duration_seconds)
  end

  test "strips whitespace and upcases the tower id" do
    import("  2026-03-02 18:40:11 , +12025550101 ,2025550133, 47 , twr-0007 ")

    call = CallRecord.sole
    assert_equal 47, call.duration_seconds
    assert_equal "TWR-0007", call.cell_tower_id
  end

  test "imports a call with no tower id rather than dropping it" do
    result = import("2026-03-03 11:00:00,+12025550142,+12025550188,60,")

    assert_equal 1, result.imported
    assert_nil CallRecord.sole.cell_tower_id
  end

  test "keeps unanswered calls with a zero duration" do
    assert_equal 1, import("2026-03-01 19:30:01,+12025550142,+12025550188,0,TWR-1").imported
  end

  test "skips blank lines" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1", "",
                    "2026-03-01 09:00:00,+12025550101,+12025550142,10,TWR-1")

    assert_equal 2, result.imported
    assert_empty result.rejections
  end

  test "rejects bad rows with a reason and keeps importing" do
    result = import(
      "2026-02-30 10:00:00,+12025550101,+12025550133,120,TWR-1",
      "yesterday afternoon,+12025550101,+12025550133,120,TWR-1",
      "2026-03-03 15:20:00,555-0101,+12025550133,75,TWR-1",
      "2026-03-03 16:05:44,+12025550188,+12025550177,-30,TWR-1",
      "2026-03-03 17:31:02,+12025550133,+12025550142,a few minutes,TWR-1",
      "2026-03-04 08:03:15,+12025550155,,240,TWR-1",
      "2026-03-04 09:10:00,+12025550101",
      "2026-03-04 09:44:51,+12025550101,+12025550177,158,TWR-1"
    )

    assert_equal 1, result.imported
    assert_equal [
      [ 2, 'timestamp "2026-02-30 10:00:00" is not a recognised date/time' ],
      [ 3, 'timestamp "yesterday afternoon" is not a recognised date/time' ],
      [ 4, 'from number "555-0101" is not a valid 10-digit phone number' ],
      [ 5, 'duration "-30" is not a number of seconds or m:ss' ],
      [ 6, 'duration "a few minutes" is not a number of seconds or m:ss' ],
      [ 7, "to number is missing" ],
      [ 8, "to number is missing" ]
    ], result.rejections.map { |r| [ r.line, r.reason ] }
  end

  test "reports the original row text for a rejection" do
    result = import("2026-03-04 08:03:15,+12025550155,,240,TWR-1")

    assert_equal "2026-03-04 08:03:15,+12025550155,,240,TWR-1", result.rejections.sole.raw
  end

  test "rejects duplicates within a file, even when formatted differently" do
    result = import("2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1",
                    "03/01/2026 08:14:22,(202) 555-0101,202-555-0142,187,TWR-1")

    assert_equal 1, result.imported
    assert_equal "duplicate of a call already imported", result.rejections.sole.reason
  end

  test "importing the same file twice adds nothing" do
    row = "2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1"
    import(row)
    result = import(row)

    assert_equal 0, result.imported
    assert_equal 1, CallRecord.count
  end

  test "tolerates header case and spacing" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1",
                    header: "Timestamp, From_Number ,TO_NUMBER,duration,Cell_Tower_ID")

    assert_equal 1, result.imported
  end

  test "fails the whole file when a column is missing" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10",
                    header: "timestamp,from_number,to_number,duration")

    assert_not result.success?
    assert_equal "Missing column(s): cell_tower_id", result.error
    assert_equal 0, CallRecord.count
  end

  test "fails cleanly on an empty file" do
    result = CdrImporter.new(StringIO.new("")).call

    assert_not result.success?
    assert_equal 0, result.imported
  end

  test "fails cleanly on malformed CSV" do
    result = import('2026-03-01 08:00:00,"+12025550101,+12025550142,10,TWR-1')

    assert_not result.success?
    assert_match(/Could not read CSV/, result.error)
  end

  test "imports the bundled sample file" do
    result = CdrImporter.import_file(Rails.root.join("db/sample/calls.csv"))

    assert result.success?
    assert_equal 19, result.imported
    assert_equal 8, result.rejections.size
  end
end
