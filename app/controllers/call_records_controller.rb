class CallRecordsController < ApplicationController
  MAX_ROWS = 500

  def index
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @import = Import.find_by(id: params[:import_id])

    calls = CallRecord.chronological.includes(:import)
    calls = calls.on_or_after(@from) if @from
    calls = calls.on_or_before(@to) if @to
    calls = calls.where(import: @import) if @import

    @total = calls.count
    @call_records = calls.limit(MAX_ROWS)
  end

  private

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
