require "csv"

# Imports call detail records from a CSV. Real CDR exports are messy, so each
# row is normalised where the intent is unambiguous and rejected (with a line
# number and a reason) where it is not. One bad row never aborts the import.
class CdrImporter
  REQUIRED_HEADERS = %w[timestamp from_number to_number duration cell_tower_id].freeze

  # Timestamps without an offset are treated as UTC.
  TIMESTAMP_FORMATS = [
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%m/%d/%Y %H:%M:%S",
    "%m/%d/%Y %H:%M",
    "%m/%d/%Y %I:%M %p"
  ].freeze

  Rejection = Struct.new(:line, :reason, :raw)

  class Result
    attr_reader :imported, :rejections
    attr_accessor :error

    def initialize
      @imported = 0
      @rejections = []
    end

    def imported!
      @imported += 1
    end

    def reject(line, reason, raw)
      @rejections << Rejection.new(line, reason, raw)
    end

    def success?
      error.nil?
    end
  end

  class RowError < StandardError; end

  def initialize(io)
    @io = io
  end

  def self.import_file(path)
    File.open(path) { |file| new(file).call }
  end

  def call
    result = Result.new
    csv = CSV.new(@io, headers: true, skip_blanks: true, header_converters: ->(h) { h.to_s.strip.downcase })

    CallRecord.transaction do
      while (row = csv.shift)
        if (missing = REQUIRED_HEADERS - csv.headers).any?
          result.error = "Missing column(s): #{missing.join(', ')}"
          break
        end

        import_row(row, csv.lineno, result)
      end
    end

    result.error ||= "File has no header row" if csv.headers == true
    result
  rescue CSV::MalformedCSVError => e
    result.error = "Could not read CSV: #{e.message}"
    result
  end

  private

  def import_row(row, line, result)
    attributes = {
      started_at: parse_timestamp(row["timestamp"]),
      from_number: normalize_number(row["from_number"], "from number"),
      to_number: normalize_number(row["to_number"], "to number"),
      duration_seconds: parse_duration(row["duration"]),
      cell_tower_id: row["cell_tower_id"].to_s.strip.upcase.presence
    }

    if CallRecord.exists?(attributes.slice(:started_at, :from_number, :to_number))
      raise RowError, "duplicate of a call already imported"
    end

    CallRecord.create!(attributes)
    result.imported!
  rescue RowError => e
    result.reject(line, e.message, row.to_csv.chomp)
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
