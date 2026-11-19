class Insight < ApplicationRecord
  belongs_to :study_record

  enum :kind, {
    went_well: "went_well",
    to_improve: "to_improve"
  }, prefix: true, validate: true

  normalizes :body, with: ->(value) { value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "") }

  validates :body, presence: true, length: { maximum: 100 }
  validates :kind, uniqueness: { scope: :study_record_id }
end
