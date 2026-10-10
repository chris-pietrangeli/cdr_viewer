class CallRecordsController < ApplicationController
  MAX_ROWS = 500

  def index
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])

    calls = CallRecord.chronological
    calls = calls.on_or_after(@from) if @from
    calls = calls.on_or_before(@to) if @to

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
