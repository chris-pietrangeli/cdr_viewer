import = CdrImporter.import_file(Rails.root.join("db/sample/calls.csv"))
puts "Imported #{import.call_records_count} calls, rejected #{import.rejected_rows_count} rows"
