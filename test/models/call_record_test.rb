require "test_helper"

class CallRecordTest < ActiveSupport::TestCase
  def create_call(started_at)
    CallRecord.create!(started_at: started_at, from_number: "+12025550101", to_number: "+12025550142", duration_seconds: 10)
  end

  test "date scopes include the whole of the boundary days" do
    before = create_call(Time.utc(2026, 3, 1, 23, 59, 59))
    first = create_call(Time.utc(2026, 3, 2, 0, 0, 0))
    last = create_call(Time.utc(2026, 3, 3, 23, 59, 59))
    after = create_call(Time.utc(2026, 3, 4, 0, 0, 0))

    range = CallRecord.on_or_after(Date.new(2026, 3, 2)).on_or_before(Date.new(2026, 3, 3))

    assert_equal [ first, last ], range.chronological.to_a
    assert_not_includes range, before
    assert_not_includes range, after
  end

  test "rejects a negative duration" do
    call = CallRecord.new(started_at: Time.current, from_number: "+12025550101", to_number: "+12025550142", duration_seconds: -1)

    assert_not call.valid?
  end
end
