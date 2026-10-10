namespace :cdr do
  desc "Import call detail records from a CSV: bin/rails 'cdr:import[path/to/file.csv]'"
  task :import, [ :path ] => :environment do |_task, args|
    abort "Usage: bin/rails 'cdr:import[path/to/file.csv]'" if args[:path].blank?

    result = CdrImporter.import_file(args[:path])
    abort result.error unless result.success?

    puts "Imported #{result.imported} calls, rejected #{result.rejections.size} rows"
    result.rejections.each { |r| puts "  line #{r.line}: #{r.reason}" }
  end
end
