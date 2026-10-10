namespace :cdr do
  desc "Import call detail records from a CSV: bin/rails 'cdr:import[path/to/file.csv]'"
  task :import, [ :path ] => :environment do |_task, args|
    abort "Usage: bin/rails 'cdr:import[path/to/file.csv]'" if args[:path].blank?

    report CdrImporter.import_file(args[:path])
  end

  desc "Import a tower list from a CSV: bin/rails 'cdr:import_towers[path/to/file.csv]'"
  task :import_towers, [ :path ] => :environment do |_task, args|
    abort "Usage: bin/rails 'cdr:import_towers[path/to/file.csv]'" if args[:path].blank?

    report TowerImporter.import_file(args[:path])
  end

  def report(import)
    abort import.error unless import.success?

    puts "Import ##{import.id} (sha256 #{import.sha256})"
    puts "Imported #{import.imported_count} #{import.kind}, rejected #{import.rejected_rows_count} rows"
    import.rejected_rows.order(:line_number).each { |row| puts "  line #{row.line_number}: #{row.reason}" }
  end
end
