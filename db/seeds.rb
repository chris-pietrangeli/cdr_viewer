{
  "calls.csv" => CdrImporter,
  "calls_split_datetime.csv" => CdrImporter,
  "towers.csv" => TowerImporter
}.each do |name, importer|
  import = importer.import_file(Rails.root.join("db/sample", name))
  puts "#{name}: imported #{import.imported_count} #{import.kind}, rejected #{import.rejected_rows_count} rows"
end
