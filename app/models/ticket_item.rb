class TicketItem < ApplicationRecord
  belongs_to :profile
  belongs_to :participant
  belongs_to :ticket
  belongs_to :event
  belongs_to :payment_method
  belongs_to :group, optional: true

  enum ticket_type: { event: 'event', group: 'group' }
  enum auth_type: { free: 'free', payment: 'payment', zupass: 'zupass', badge: 'badge', invite: 'invite' }
end
