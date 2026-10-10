module CallRecordsHelper
  def format_duration(seconds)
    minutes, secs = seconds.divmod(60)
    hours, minutes = minutes.divmod(60)
    hours.positive? ? format("%d:%02d:%02d", hours, minutes, secs) : format("%d:%02d", minutes, secs)
  end
end
