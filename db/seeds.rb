result = CdrImporter.import_file(Rails.root.join("db/sample/calls.csv"))
puts "Imported #{result.imported} calls, rejected #{result.rejections.size} rows"
