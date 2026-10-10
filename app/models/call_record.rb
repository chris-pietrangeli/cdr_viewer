class CallRecord < ApplicationRecord
  belongs_to :import, counter_cache: true
  # Matched on the tower's code, not a database id, because a call file and
  # the tower list that locates it arrive separately and in either order.
  belongs_to :tower, foreign_key: :cell_tower_id, primary_key: :code, optional: true

  validates :started_at, :from_number, :to_number, :source_line, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :started_at, uniqueness: { scope: [ :from_number, :to_number ] }

  scope :on_or_after, ->(date) { where(started_at: date.beginning_of_day..) }
  scope :on_or_before, ->(date) { where(started_at: ..date.end_of_day) }
  scope :involving, ->(number) { where(from_number: number).or(where(to_number: number)) }
  scope :chronological, -> { order(:started_at) }
end
