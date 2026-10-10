class AddLayoutToImports < ActiveRecord::Migration[8.1]
  def change
    add_column :imports, :layout, :string
  end
end
