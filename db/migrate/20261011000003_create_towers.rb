class CreateTowers < ActiveRecord::Migration[8.1]
  def change
    create_table :towers do |t|
      t.string :code, null: false
      t.decimal :latitude, precision: 9, scale: 6, null: false
      t.decimal :longitude, precision: 9, scale: 6, null: false
      t.references :import, null: false, foreign_key: true
      t.integer :source_line, null: false

      t.timestamps
    end

    add_index :towers, :code, unique: true
    add_index :call_records, :cell_tower_id

    add_column :imports, :kind, :string, null: false, default: "calls"
    add_column :imports, :towers_count, :integer, null: false, default: 0
  end
end
