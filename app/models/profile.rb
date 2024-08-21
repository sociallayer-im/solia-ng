class Profile < ApplicationRecord
  belongs_to :group, optional: true

  has_many :vouchers, class_name: "Voucher", inverse_of: "sender", foreign_key: "sender_id"
  has_many :received_vouchers, class_name: "Voucher", inverse_of: "sender", foreign_key: "receiver_id"

  has_many :badge_classes, class_name: "BadgeClass", inverse_of: "creator", foreign_key: "creator_id"
  has_many :created_badges, class_name: "Badge", inverse_of: "creator", foreign_key: "creator_id"
  has_many :owned_badges, class_name: "Badge", inverse_of: "owner", foreign_key: "owner_id"

  has_many :events, class_name: "Event", inverse_of: "owner", foreign_key: "owner_id"
  has_many :event_sites, class_name: "EventSite", inverse_of: "owner", foreign_key: "owner_id"

  has_many :point_classes, class_name: "PointClass", inverse_of: "creator", foreign_key: "creator_id"
  has_many :points, class_name: "Point", inverse_of: "owner", foreign_key: "owner_id"
  has_many :point_items, class_name: "PointItem", inverse_of: "owner", foreign_key: "owner_id"
  has_many :sent_point_items, class_name: "PointItem", inverse_of: "sender", foreign_key: "sender_id"

  has_many :memberships
  has_many :group_passes

  has_many :source_contacts, class_name: "Contact", inverse_of: "source", foreign_key: "source_id"
  has_many :target_contacts, class_name: "Contact", inverse_of: "target", foreign_key: "target_id"

  has_many :contact_sources, :through => :target_contacts, :source => "source", foreign_key: "target_id"
  has_many :contact_targets, :through => :source_contacts, :source => "target", foreign_key: "source_id"

  validates :status, inclusion: { in: %w(active freezed) }
end
