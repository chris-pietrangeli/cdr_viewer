class ImportsController < ApplicationController
  def create
    file = params[:file]
    return redirect_to(root_path, alert: "Choose a CSV file to import.") if file.blank?

    @result = CdrImporter.new(file.to_io).call
    @filename = file.original_filename
    render :show
  end
end
