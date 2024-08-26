class PaymentMethod < ApplicationRecord
  belongs_to :item, polymorphic: true, optional: true

  validates :chain, inclusion: { in: %w(ethereum op arb polygon base stripe) }
  enum :kind, { crypto: 'crypto', fiat: 'fiat', credit: 'credit' }
end
