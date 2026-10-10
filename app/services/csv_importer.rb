require "csv"
require "digest"

# The parts of importing a CSV that do not depend on what the file contains:
# recording the upload, working out which column layout it uses, walking the
# rows with their real line numbers, and saving a reason for every row that is
# rejected. One bad row never aborts the import.
#
# A subclass supplies KIND (the Import kind), LAYOUTS (the column layouts it
# understands: for each one, which file column, after trimming and
# lower-casing, holds each field) and save_row.
class CsvImporter
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
    import = Import.create!(kind: self.class::KIND, filename: @filename, sha256: Digest::SHA256.hexdigest(@content), byte_size: @content.bytesize)

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
  # fails the file: guessing which column is which could produce records that
  # look right and are wrong.
  # A layout matches when the file has every column it needs. Anything else
  # fails the file: guessing which column is which could produce records that
  # look right and are wrong.
  def detect_layout(headers)
    matches = self.class::LAYOUTS.select { |_name, columns| (columns.values.flatten - headers).empty? }
    return matches.first if matches.one?

    known = self.class::LAYOUTS.map { |name, columns| "#{name} (#{columns.values.flatten.join(', ')})" }.join("; ")
    problem = matches.any? ? "Columns match more than one known layout" : "Unrecognised column layout"
    raise FileError, "#{problem}: #{headers.join(', ')}. Known layouts: #{known}"
  end

  def import_row(import, columns, row, line, raw)
    save_row(import, columns, row, line)
  rescue RowError => e
    import.rejected_rows.create!(line_number: line, reason: e.message, raw: raw)
  end

  # Saves one record, or raises RowError with the reason the row is rejected.
  def save_row(import, columns, row, line)
    raise NotImplementedError
  end
end
