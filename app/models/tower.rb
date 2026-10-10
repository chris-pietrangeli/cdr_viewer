class Tower < ApplicationRecord
  belongs_to :import, counter_cache: true

  validates :code, presence: true, uniqueness: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :source_line, presence: true
end
