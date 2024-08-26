class TicketItem < ApplicationRecord
  belongs_to :profile
  belongs_to :participant
  belongs_to :ticket
  belongs_to :event
  belongs_to :payment_method
  belongs_to :group, optional: true

  validates :ticket_type, inclusion: { in: %w(event group) }
  enum :auth_type, { free: 'free', payment: 'payment', zupass: 'zupass', badge: 'badge', invite: 'invite' }
end
