class RejectedRow < ApplicationRecord
  belongs_to :import, counter_cache: true

  validates :line_number, :reason, :raw, presence: true
end
