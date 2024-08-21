class PromoCode < ApplicationRecord
  validates :selector, inclusion: { in: %w(code email zupass badge) }
  validates :discount_type, inclusion: { in: %w(ratio amount) }
  belongs_to :event

  before_save do
    if code.blank?
      self.code = SecureRandom.hex(6)
    end
  end
end
