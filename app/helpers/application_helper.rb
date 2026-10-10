module ApplicationHelper
  def format_time(time)
    time.utc.strftime("%Y-%m-%d %H:%M:%S")
  end
end
