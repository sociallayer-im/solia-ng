class Participant < ApplicationRecord
  belongs_to :event
  belongs_to :profile
  belongs_to :badge, optional: true
  has_many :ticket_items

  validates :status, inclusion: { in: %w(attending waiting pending disapproved checked cancelled) }
end
