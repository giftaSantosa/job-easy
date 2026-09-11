class JobOpening < ApplicationRecord
  belongs_to :company
  belongs_to :user, optional: true
  has_many :job_applications

  validates :title, presence: true

  scope :ordered, -> { order(deadline: :asc) }
  scope :open, -> { where(closed: false) }
  scope :close, -> { where(closed: true) }
end
