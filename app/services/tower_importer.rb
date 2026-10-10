# Imports a tower list: the file that says where each cell tower in a set of
# call records is.
class TowerImporter < CsvImporter
  KIND = "towers"

  LAYOUTS = {
    "standard" => { code: "tower_id", latitude: "latitude", longitude: "longitude" }
  }.freeze

  private

  def save_row(import, columns, row, line)
    code = row[columns[:code]].to_s.strip.upcase
    raise RowError, "tower id is missing" if code.empty?

    latitude = parse_coordinate(row[columns[:latitude]], "latitude", 90)
    longitude = parse_coordinate(row[columns[:longitude]], "longitude", 180)

    # 0, 0 is a point in the Atlantic that exports use when a location was
    # never filled in. Plotting it would be worse than having no location.
    raise RowError, "coordinates 0, 0 are a placeholder, not a location" if latitude.zero? && longitude.zero?

    # A tower that is already known is never overwritten: moving a tower would
    # silently move every call already plotted at it.
    if (existing = Tower.find_by(code: code))
      moved = existing.latitude != latitude || existing.longitude != longitude
      raise RowError, "tower #{code} already imported#{' with a different location' if moved} " \
                      "(#{existing.import.filename}, line #{existing.source_line})"
    end

    import.towers.create!(code: code, latitude: latitude, longitude: longitude, source_line: line)
  end

  # Plain decimal degrees only, rounded to the 6 places the database stores
  # (about 10 cm).
  def parse_coordinate(value, label, limit)
    value = value.to_s.strip
    raise RowError, "#{label} is missing" if value.empty?

    number = BigDecimal(value).round(6) if value.match?(/\A-?\d+(\.\d+)?\z/)
    unless number && number.abs <= limit
      raise RowError, "#{label} #{value.inspect} is not a number between -#{limit} and #{limit}"
    end

    number
  end
end
