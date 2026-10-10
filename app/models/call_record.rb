class CallRecord < ApplicationRecord
  validates :started_at, :from_number, :to_number, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :started_at, uniqueness: { scope: [ :from_number, :to_number ] }

  scope :on_or_after, ->(date) { where(started_at: date.beginning_of_day..) }
  scope :on_or_before, ->(date) { where(started_at: ..date.end_of_day) }
  scope :chronological, -> { order(:started_at) }
end
