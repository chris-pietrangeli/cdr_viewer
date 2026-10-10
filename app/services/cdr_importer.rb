# Imports call detail records. Real CDR exports are messy, so each row is
# normalised where the intent is unambiguous and rejected with a reason where
# it is not.
class CdrImporter < CsvImporter
  KIND = "calls"

  # Different sources name and arrange the same data differently, so supporting
  # a new source means adding an entry here, not changing the parsing code.
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

  private

  def save_row(import, columns, row, line)
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

  def normalize_number(value, label)
    value = value.to_s.strip
    raise RowError, "#{label} is missing" if value.empty?

    PhoneNumber.normalize(value) || raise(RowError, "#{label} #{value.inspect} is not a valid 10-digit phone number")
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
