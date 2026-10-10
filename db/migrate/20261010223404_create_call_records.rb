class CreateCallRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :call_records do |t|
      t.datetime :started_at, null: false
      t.string :from_number, null: false
      t.string :to_number, null: false
      t.integer :duration_seconds, null: false
      t.string :cell_tower_id

      t.timestamps
    end

    add_index :call_records, :started_at
    add_index :call_records, [ :started_at, :from_number, :to_number ], unique: true, name: "index_call_records_uniqueness"
  end
end
