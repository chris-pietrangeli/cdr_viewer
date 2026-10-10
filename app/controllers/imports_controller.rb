class ImportsController < ApplicationController
  IMPORTERS = { "calls" => CdrImporter, "towers" => TowerImporter }.freeze

  def index
    @imports = Import.newest_first
  end

  def show
    @import = Import.find(params[:id])
    @rejected_rows = @import.rejected_rows.order(:line_number)
  end

  def create
    file = params[:file]
    return redirect_back_or_to(root_path, alert: "Choose a CSV file to import.") if file.blank?

    importer = IMPORTERS.fetch(params[:kind], CdrImporter)
    redirect_to importer.new(file.to_io, filename: file.original_filename).call
  end
end
