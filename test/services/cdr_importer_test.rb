require "test_helper"

class CdrImporterTest < ActiveSupport::TestCase
  HEADER = "timestamp,from_number,to_number,duration,cell_tower_id".freeze
  SPLIT_HEADER = "Call Date,Call Time,Calling Party,Called Party,Duration (sec),Site ID".freeze

  def import(*rows, header: HEADER, filename: "test.csv")
    CdrImporter.new(StringIO.new([ header, *rows ].join("\n")), filename: filename).call
  end

  test "imports a clean row" do
    result = import("2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-0012")

    assert result.success?
    assert_equal 1, result.call_records_count
    assert_empty result.rejected_rows

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

    assert_equal 1, result.call_records_count
    assert_nil CallRecord.sole.cell_tower_id
  end

  test "keeps unanswered calls with a zero duration" do
    assert_equal 1, import("2026-03-01 19:30:01,+12025550142,+12025550188,0,TWR-1").call_records_count
  end

  test "line numbers match the file when a quoted field spans two lines" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,\"TWR\n-1\"",
                    "2026-03-01 09:00:00,+12025550101,,10,TWR-1")

    assert_equal 4, result.rejected_rows.sole.line_number
  end

  test "skips blank lines" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1", "",
                    "2026-03-01 09:00:00,+12025550101,+12025550142,10,TWR-1")

    assert_equal 2, result.call_records_count
    assert_empty result.rejected_rows
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

    assert_equal 1, result.call_records_count
    assert_equal [
      [ 2, 'timestamp "2026-02-30 10:00:00" is not a recognised date/time' ],
      [ 3, 'timestamp "yesterday afternoon" is not a recognised date/time' ],
      [ 4, 'from number "555-0101" is not a valid 10-digit phone number' ],
      [ 5, 'duration "-30" is not a number of seconds or m:ss' ],
      [ 6, 'duration "a few minutes" is not a number of seconds or m:ss' ],
      [ 7, "to number is missing" ],
      [ 8, "to number is missing" ]
    ], result.rejected_rows.order(:line_number).pluck(:line_number, :reason)
  end

  test "keeps a rejected row exactly as it appears in the file" do
    result = import(' 2026-03-04 08:03:15 ,"+12025550155",,240,twr-1')

    assert_equal ' 2026-03-04 08:03:15 ,"+12025550155",,240,twr-1', result.rejected_rows.sole.raw
  end

  test "rejects duplicates within a file, even when formatted differently" do
    result = import("2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1",
                    "03/01/2026 08:14:22,(202) 555-0101,202-555-0142,187,TWR-1")

    assert_equal 1, result.call_records_count
    assert_equal "duplicate of a call already imported (test.csv, line 2)", result.rejected_rows.sole.reason
  end

  test "importing the same file twice adds no calls but records both attempts" do
    row = "2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1"
    first = import(row)
    second = import(row)

    assert_equal 0, second.call_records_count
    assert_equal 1, CallRecord.count
    assert_equal [ first ], second.identical_uploads.to_a
  end

  test "records the file name, size and SHA-256 of the bytes received" do
    content = "#{HEADER}\n2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1\n"
    result = CdrImporter.new(StringIO.new(content), filename: "carrier_export.csv").call

    assert_equal "carrier_export.csv", result.filename
    assert_equal content.bytesize, result.byte_size
    assert_equal Digest::SHA256.hexdigest(content), result.sha256
  end

  test "a one-character change to the file changes its fingerprint" do
    first = import("2026-03-01 08:14:22,+12025550101,+12025550142,187,TWR-1")
    second = import("2026-03-01 08:14:22,+12025550101,+12025550142,188,TWR-1")

    assert_not_equal first.sha256, second.sha256
    assert_empty second.identical_uploads
  end

  test "links each call to the file and line it came from" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1", "",
                    "2026-03-01 09:00:00,+12025550101,+12025550142,10,TWR-1")

    assert_equal [ [ result.id, 2 ], [ result.id, 4 ] ], CallRecord.chronological.pluck(:import_id, :source_line)
  end

  test "tolerates header case and spacing" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1",
                    header: "Timestamp, From_Number ,TO_NUMBER,duration,Cell_Tower_ID")

    assert_equal 1, result.call_records_count
  end

  test "fails the whole file when a column is missing" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10",
                    header: "timestamp,from_number,to_number,duration")

    assert_not result.success?
    assert_match(/\AUnrecognised column layout: timestamp, from_number, to_number, duration\. Known layouts: standard \(/, result.error)
    assert_equal 0, CallRecord.count
  end

  test "imports the split date and time layout" do
    result = import("03/06/2026,14:05:09,(202) 555-0101,202-555-0142,187,twr-0012", header: SPLIT_HEADER)

    assert result.success?
    assert_equal "split_datetime", result.layout

    call = CallRecord.sole
    assert_equal Time.utc(2026, 3, 6, 14, 5, 9), call.started_at
    assert_equal "+12025550101", call.from_number
    assert_equal "+12025550142", call.to_number
    assert_equal 187, call.duration_seconds
    assert_equal "TWR-0012", call.cell_tower_id
  end

  test "records which layout a standard file was read as" do
    assert_equal "standard", import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1").layout
  end

  test "rejects a split layout row with a date but no time" do
    result = import("03/06/2026,,+12025550101,+12025550142,187,TWR-1", header: SPLIT_HEADER)

    assert_equal 'timestamp "03/06/2026" is not a recognised date/time', result.rejected_rows.sole.reason
  end

  test "the same call arriving in both layouts is a duplicate" do
    import("2026-03-06 14:05:09,+12025550101,+12025550142,187,TWR-1", filename: "a.csv")
    result = import("03/06/2026,14:05:09,+12025550101,+12025550142,187,TWR-1", header: SPLIT_HEADER, filename: "b.csv")

    assert_equal "duplicate of a call already imported (a.csv, line 2)", result.rejected_rows.sole.reason
  end

  test "ignores extra columns and column order" do
    result = import("TWR-1,10,voice,+12025550142,+12025550101,2026-03-01 08:00:00",
                    header: "cell_tower_id,duration,call_type,to_number,from_number,timestamp")

    assert_equal 1, result.call_records_count
    assert_equal %w[+12025550101 +12025550142], CallRecord.sole.values_at(:from_number, :to_number)
  end

  test "refuses a file whose columns fit more than one layout" do
    result = import(header: "#{HEADER},#{SPLIT_HEADER}")

    assert_not result.success?
    assert_match(/\AColumns match more than one known layout/, result.error)
  end

  test "reads a file that starts with a byte order mark" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1", header: "\uFEFF#{HEADER}")

    assert result.success?
    assert_equal 1, result.call_records_count
  end

  test "accepts a file with a header and no rows" do
    result = import

    assert result.success?
    assert_equal "standard", result.layout
    assert_equal 0, result.call_records_count
  end

  test "a file that fails part-way saves none of its rows but is still recorded" do
    result = import("2026-03-01 08:00:00,+12025550101,+12025550142,10,TWR-1",
                    "not a date,+12025550101,+12025550142,10,TWR-1",
                    '2026-03-01 09:00:00,"+12025550101,+12025550142,10,TWR-1')

    assert_not result.success?
    assert_match(/Could not read CSV/, result.error)
    assert_equal 0, CallRecord.count
    assert_equal 0, RejectedRow.count
    assert_equal [ 0, 0 ], [ result.call_records_count, result.rejected_rows_count ]
    assert_equal [ result ], Import.all.to_a
  end

  test "fails cleanly on an empty file" do
    result = CdrImporter.new(StringIO.new(""), filename: "empty.csv").call

    assert_not result.success?
    assert_equal 0, result.call_records_count
  end

  test "fails cleanly on malformed CSV" do
    result = import('2026-03-01 08:00:00,"+12025550101,+12025550142,10,TWR-1')

    assert_not result.success?
    assert_match(/Could not read CSV/, result.error)
  end

  test "imports the bundled sample file" do
    result = CdrImporter.import_file(Rails.root.join("db/sample/calls.csv"))

    assert result.success?
    assert_equal 19, result.call_records_count
    assert_equal 8, result.rejected_rows_count
  end

  test "imports the bundled split layout sample file" do
    result = CdrImporter.import_file(Rails.root.join("db/sample/calls_split_datetime.csv"))

    assert result.success?
    assert_equal "split_datetime", result.layout
    assert_equal 6, result.call_records_count
    assert_equal [ [ 6, "to number is missing" ], [ 8, 'timestamp "03/07/2026" is not a recognised date/time' ] ],
                 result.rejected_rows.order(:line_number).pluck(:line_number, :reason)
  end
end
