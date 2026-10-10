module CallRecordsHelper
  def format_duration(seconds)
    minutes, secs = seconds.divmod(60)
    hours, minutes = minutes.divmod(60)
    hours.positive? ? format("%d:%02d:%02d", hours, minutes, secs) : format("%d:%02d", minutes, secs)
  end

  # Says which calls the map leaves out and why, so none go missing silently.
  # unlisted_towers maps a tower code with no known location to its call count.
  def unlocated_summary(unlisted_towers, no_tower_total)
    reasons = []
    if unlisted_towers.any?
      reasons << "#{pluralize(unlisted_towers.values.sum, 'call')} at #{unlisted_towers.one? ? 'a tower' : 'towers'} " \
                 "with no known location (#{unlisted_towers.keys.join(', ')})"
    end
    reasons << "#{pluralize(no_tower_total, 'call')} with no tower recorded" if no_tower_total.positive?

    "Not on the map: #{reasons.to_sentence}." if reasons.any?
  end
end
