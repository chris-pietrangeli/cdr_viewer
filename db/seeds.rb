%w[calls.csv calls_split_datetime.csv].each do |name|
  import = CdrImporter.import_file(Rails.root.join("db/sample", name))
  puts "#{name}: imported #{import.call_records_count} calls, rejected #{import.rejected_rows_count} rows"
end
