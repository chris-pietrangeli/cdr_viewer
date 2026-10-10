class CallRecordsController < ApplicationController
  MAX_ROWS = 500

  def index
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @number = PhoneNumber.normalize(params[:number])
    @import = Import.find_by(id: params[:import_id])

    calls = CallRecord.all
    calls = calls.on_or_after(@from) if @from
    calls = calls.on_or_before(@to) if @to
    calls = calls.involving(@number) if @number
    calls = calls.where(import: @import) if @import

    @total = calls.count
    @call_records = calls.chronological.includes(:import).limit(MAX_ROWS)

    # The map covers every matching call, not only the rows on this page, and
    # the page accounts for every call it could not place.
    @markers = tower_markers(calls.joins(:tower))
    @unlisted_towers = calls.where.missing(:tower).where.not(cell_tower_id: nil).group(:cell_tower_id).order(:cell_tower_id).count
    @no_tower_total = calls.where(cell_tower_id: nil).count
  end

  private

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end

  # One entry per tower: where it is and how the matching calls used it.
  def tower_markers(calls)
    counts = calls.group(:cell_tower_id).count
    first = calls.group(:cell_tower_id).minimum(:started_at)
    last = calls.group(:cell_tower_id).maximum(:started_at)

    Tower.where(code: counts.keys).order(:code).map do |tower|
      {
        code: tower.code,
        lat: tower.latitude.to_f,
        lng: tower.longitude.to_f,
        calls: counts[tower.code],
        first: helpers.format_time(first[tower.code]),
        last: helpers.format_time(last[tower.code])
      }
    end
  end
end
