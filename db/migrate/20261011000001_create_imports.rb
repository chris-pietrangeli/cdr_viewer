class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string :filename, null: false
      t.string :sha256, null: false
      t.integer :byte_size, null: false
      t.string :error
      t.integer :call_records_count, null: false, default: 0
      t.integer :rejected_rows_count, null: false, default: 0

      t.timestamps
    end

    add_index :imports, :sha256

    create_table :rejected_rows do |t|
      t.references :import, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :reason, null: false
      t.text :raw, null: false

      t.timestamps
    end

    add_reference :call_records, :import, null: false, foreign_key: true
    add_column :call_records, :source_line, :integer, null: false
  end
end
