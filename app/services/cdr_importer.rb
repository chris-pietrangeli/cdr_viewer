require "csv"
require "digest"

# Imports call detail records from a CSV. Real CDR exports are messy, so each
# row is normalised where the intent is unambiguous and rejected (with a line
# number and a reason) where it is not. One bad row never aborts the import.
class CdrImporter
  # The column layouts this importer understands: for each one, which file
  # column (after trimming and lower-casing) holds each field. Different
  # sources name and arrange the same data differently, so supporting a new
  # source means adding an entry here, not changing the parsing code.
  LAYOUTS = {
    "standard" => {
      timestamp: [ "timestamp" ],
      from_number: "from_number",
      to_number: "to_number",
      duration: "duration",
      cell_tower_id: "cell_tower_id"
    },
    "split_datetime" => {
      timestamp: [ "call date", "call time" ],
      from_number: "calling party",
      to_number: "called party",
      duration: "duration (sec)",
      cell_tower_id: "site id"
    }
  }.freeze

  # Timestamps without an offset are treated as UTC.
  TIMESTAMP_FORMATS = [
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%m/%d/%Y %H:%M:%S",
    "%m/%d/%Y %H:%M",
    "%m/%d/%Y %I:%M %p"
  ].freeze

  class RowError < StandardError; end
  class FileError < StandardError; end

  def initialize(io, filename:)
    @content = io.read
    @filename = filename
  end

  def self.import_file(path)
    File.open(path, "rb") { |file| new(file, filename: File.basename(path)).call }
  end

  # Returns the Import that records this attempt. The fingerprint is taken
  # from the bytes exactly as received, before any parsing.
  def call
    import = Import.create!(filename: @filename, sha256: Digest::SHA256.hexdigest(@content), byte_size: @content.bytesize)

    begin
      # requires_new so a file-level failure undoes this file's rows and
      # nothing else, even when the caller already has a transaction open.
      Import.transaction(requires_new: true) { import_rows(import) }
    rescue FileError => e
      import.reload.update!(error: e.message)
    rescue CSV::MalformedCSVError => e
      import.reload.update!(error: "Could not read CSV: #{e.message}")
    end

    import.reload
  end

  private

  def import_rows(import)
    # Spreadsheet exports often start with a byte order mark, which would
    # otherwise become part of the first column's name.
    text = @content.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
    csv = CSV.new(text, headers: true, header_converters: ->(h) { h.to_s.strip.downcase })

    row = csv.shift
    raise FileError, "File has no header row" if csv.headers == true

    layout, columns = detect_layout(csv.headers)
    import.update!(layout: layout)
    line = 2 # line 1 is the header

    while row
      # csv.line is the text as it appears in the file, which is what a
      # rejection should quote; row.to_csv would be a re-serialised copy.
      raw = csv.line
      import_row(import, columns, row, line, raw.chomp) unless raw.strip.empty?

      # csv.lineno counts rows, not lines: it skips blank lines and counts a
      # quoted field containing a line break as one. Count from the raw text
      # so the number matches what someone sees when they open the file.
      line += [ raw.count("\n"), 1 ].max
      row = csv.shift
    end
  end

  # A layout matches when the file has every column it needs. Anything else
  # fails the file: guessing which column is the caller and which the callee
  # could produce records that look right and are wrong.
  def detect_layout(headers)
    matches = LAYOUTS.select { |_name, columns| (columns.values.flatten - headers).empty? }
    return matches.first if matches.one?

    known = LAYOUTS.map { |name, columns| "#{name} (#{columns.values.flatten.join(', ')})" }.join("; ")
    problem = matches.any? ? "Columns match more than one known layout" : "Unrecognised column layout"
    raise FileError, "#{problem}: #{headers.join(', ')}. Known layouts: #{known}"
  end

  def import_row(import, columns, row, line, raw)
    attributes = {
      started_at: parse_timestamp(row.values_at(*columns[:timestamp]).join(" ")),
      from_number: normalize_number(row[columns[:from_number]], "from number"),
      to_number: normalize_number(row[columns[:to_number]], "to number"),
      duration_seconds: parse_duration(row[columns[:duration]]),
      cell_tower_id: row[columns[:cell_tower_id]].to_s.strip.upcase.presence
    }

    if (original = CallRecord.find_by(attributes.slice(:started_at, :from_number, :to_number)))
      raise RowError, "duplicate of a call already imported (#{original.import.filename}, line #{original.source_line})"
    end

    import.call_records.create!(attributes.merge(source_line: line))
  rescue RowError => e
    import.rejected_rows.create!(line_number: line, reason: e.message, raw: raw)
  end

  def parse_timestamp(value)
    value = value.to_s.strip
    raise RowError, "timestamp is missing" if value.empty?

    begin
      return Time.iso8601(value).utc
    rescue ArgumentError
      # not ISO 8601, fall through to the known formats
    end

    TIMESTAMP_FORMATS.each do |format|
      # strptime ignores trailing text ("2:15 PM" would parse as 02:15), so
      # only accept a format that consumes the whole value.
      next if DateTime._strptime(value, format)&.key?(:leftover) != false

      return DateTime.strptime(value, format).to_time.utc
    rescue Date::Error
      next
    end

    raise RowError, "timestamp #{value.inspect} is not a recognised date/time"
  end

  # Normalises North American numbers to E.164 (+1XXXXXXXXXX).
  def normalize_number(value, label)
    value = value.to_s.strip
    raise RowError, "#{label} is missing" if value.empty?

    digits = value.gsub(/\D/, "")
    digits = "1#{digits}" if digits.length == 10
    unless digits.length == 11 && digits.start_with?("1")
      raise RowError, "#{label} #{value.inspect} is not a valid 10-digit phone number"
    end

    "+#{digits}"
  end

  # Accepts whole seconds ("125"), "m:ss" or "h:mm:ss".
  def parse_duration(value)
    value = value.to_s.strip
    raise RowError, "duration is missing" if value.empty?

    case value
    when /\A\d+\z/
      value.to_i
    when /\A(\d+):([0-5]\d)\z/
      $1.to_i * 60 + $2.to_i
    when /\A(\d+):([0-5]\d):([0-5]\d)\z/
      $1.to_i * 3600 + $2.to_i * 60 + $3.to_i
    else
      raise RowError, "duration #{value.inspect} is not a number of seconds or m:ss"
    end
  end
end
