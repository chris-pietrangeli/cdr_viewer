# One uploaded file. A row is written for every attempt, including files that
# fail, so there is always a record of what was received and what became of it.
class Import < ApplicationRecord
  has_many :call_records
  has_many :rejected_rows

  validates :filename, :sha256, :byte_size, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def success?
    error.nil?
  end

  # Other uploads of a byte-for-byte identical file.
  def identical_uploads
    Import.where(sha256: sha256).where.not(id: id).newest_first
  end
end
