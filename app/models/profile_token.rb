class ProfileToken < ApplicationRecord
  validates :status, inclusion: { in: %w(set-email-verifier signin-email-verifier) }
end
