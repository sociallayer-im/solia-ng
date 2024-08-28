class PromoCode < ApplicationRecord
  validates :selector, inclusion: { in: %w(code email zupass badge) }
  validates :discount_type, inclusion: { in: %w(ratio amount) }
  belongs_to :event

  before_save do
    if code.blank?
      self.code = SecureRandom.hex(6)
    end
  end

  def get_discounted_price(amount)
    if self.expiry_time > DateTime.now || self.max_allowed_usages > self.order_usage_count
      return [amount, nil, nil]
    end
    if self.discount_type == "ratio"
      amount = amount * self.discount / 10000
    elsif self.discount_type == "amount"
      discount = paymethod.chain == "stripe" ? discount : discount * 10000
      amount = amount - self.discount
    end
    discount_value = paymethod.price - amount
    discount_data = "id=#{id}|#{discount_type}|#{discount}"
    [amount, discount_value, discount_data]
  end
end
