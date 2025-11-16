class BlockedDate < ApplicationRecord
  belongs_to :service, optional: true

  # Validations
  validates :blocked_date, presence: true

  # Scopes
  scope :for_service, ->(service) { where(service: service) }
  scope :global, -> { where(service_id: nil) }
  scope :for_date, ->(date) { where(blocked_date: date) }
  scope :recurring, -> { where(recurring_yearly: true) }
end