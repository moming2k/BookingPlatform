class AvailabilitySchedule < ApplicationRecord
  belongs_to :service

  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end