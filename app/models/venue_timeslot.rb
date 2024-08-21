class VenueTimeslot < ApplicationRecord
  belongs_to :venue

  validates :day_of_week, inclusion: { in: %w(mon tue wed thu fri sat sun) }
end
