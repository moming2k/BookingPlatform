class Booking < ApplicationRecord
  # Soft deletes
  acts_as_paranoid

  # Paper trail for audit (disabled until table is created)
  # has_paper_trail

  # Associations
  belongs_to :user
  belongs_to :service
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_one :payment, dependent: :destroy

  # Money - using decimal amount column instead of amount_cents
  # monetize :amount_cents, as: "amount"

  # Constants
  STATUSES = %w[pending confirmed cancelled completed no_show].freeze

  # Validations
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :booking_reference, presence: true, uniqueness: true
  validate :end_time_after_start_time
  validate :booking_in_future, on: :create
  validate :no_overlapping_bookings, on: :create
  validate :within_advance_booking_limits, on: :create

  # Scopes
  scope :upcoming, -> { where("start_time > ?", Time.current).order(start_time: :asc) }
  scope :past, -> { where("end_time < ?", Time.current).order(start_time: :desc) }
  scope :today, -> { where(start_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :pending, -> { where(status: "pending") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :completed, -> { where(status: "completed") }
  scope :no_show, -> { where(status: "no_show") }
  scope :active, -> { where(status: %w[pending confirmed]) }
  scope :needs_reminder, -> {
    confirmed
      .where("start_time > ? AND start_time <= ?", Time.current, 24.hours.from_now)
      .where(reminder_sent_at: nil)
  }

  # Callbacks
  before_validation :set_defaults
  before_validation :generate_booking_reference, on: :create
  after_create :create_payment_record
  after_update :handle_status_change

  # State machine methods
  def confirm!
    return false unless can_confirm?

    transaction do
      update!(
        status: "confirmed",
        confirmed_at: Time.current
      )
      payment&.process_payment!
      send_confirmation_email
    end
    true
  rescue => e
    Rails.logger.error "Failed to confirm booking: #{e.message}"
    false
  end

  def cancel!(user = nil, reason = nil)
    return false unless can_cancel?

    transaction do
      update!(
        status: "cancelled",
        cancelled_at: Time.current,
        cancelled_by: user,
        cancellation_reason: reason
      )
      payment&.refund! if payment&.succeeded?
      send_cancellation_email
    end
    true
  rescue => e
    Rails.logger.error "Failed to cancel booking: #{e.message}"
    false
  end

  def complete!
    return false unless can_complete?

    update!(status: "completed")
    send_completion_email
    true
  end

  def mark_no_show!
    return false unless can_mark_no_show?

    update!(status: "no_show")
    true
  end

  # Status checks
  def can_confirm?
    status == "pending" && payment&.can_process?
  end

  def can_cancel?
    %w[pending confirmed].include?(status) && start_time > Time.current
  end

  def can_complete?
    status == "confirmed" && end_time <= Time.current
  end

  def can_mark_no_show?
    status == "confirmed" && end_time <= Time.current
  end

  def pending?
    status == "pending"
  end

  def confirmed?
    status == "confirmed"
  end

  def cancelled?
    status == "cancelled"
  end

  def completed?
    status == "completed"
  end

  def no_show?
    status == "no_show"
  end

  def active?
    %w[pending confirmed].include?(status)
  end

  def past?
    end_time < Time.current
  end

  def upcoming?
    start_time > Time.current
  end

  def in_progress?
    Time.current.between?(start_time, end_time)
  end

  # Refund helpers
  def refundable?
    payment&.succeeded? && !payment&.refunded?
  end

  def cancellation_deadline
    start_time - service.min_advance_hours.hours
  end

  def free_cancellation_available?
    Time.current < cancellation_deadline
  end

  # Display helpers
  def duration_in_minutes
    ((end_time - start_time) / 60).to_i
  end

  def formatted_time_range
    "#{start_time.strftime('%l:%M %p')} - #{end_time.strftime('%l:%M %p')}".strip
  end

  def formatted_date
    start_time.strftime("%B %d, %Y")
  end

  # Email methods
  def send_confirmation_email
    BookingMailer.confirmation(self).deliver_later
  end

  def send_reminder_email
    return if reminder_sent_at.present?

    BookingMailer.reminder(self).deliver_later
    update!(reminder_sent_at: Time.current)
  end

  def send_cancellation_email
    BookingMailer.cancellation(self).deliver_later
  end

  def send_completion_email
    BookingMailer.completion(self).deliver_later if user.preferences["send_completion_emails"]
  end

  # Calendar helpers
  def to_ical_event
    event = Icalendar::Event.new
    event.dtstart = start_time
    event.dtend = end_time
    event.summary = service.name
    event.description = notes
    event.location = service.settings["location"]
    event.uid = booking_reference
    event
  end

  private

  def set_defaults
    self.amount ||= service.price if service.present?
    self.currency ||= service.currency if service.present?
    self.status ||= "pending"
  end

  def generate_booking_reference
    loop do
      self.booking_reference = "BK-#{SecureRandom.hex(4).upcase}"
      break unless Booking.exists?(booking_reference: booking_reference)
    end
  end

  def create_payment_record
    Payment.create!(
      booking: self,
      user: user,
      amount: amount,
      currency: currency,
      status: "pending"
    )
  end

  def handle_status_change
    if saved_change_to_status?
      case status
      when "confirmed"
        BookingConfirmedJob.perform_later(self)
      when "cancelled"
        BookingCancelledJob.perform_later(self)
      when "completed"
        BookingCompletedJob.perform_later(self)
      end
    end
  end

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  def booking_in_future
    return unless start_time.present?

    errors.add(:start_time, "must be in the future") if start_time <= Time.current
  end

  def no_overlapping_bookings
    return unless service.present? && start_time.present? && end_time.present?

    overlapping = service.bookings
                        .active
                        .where.not(id: id)
                        .where("start_time < ? AND end_time > ?", end_time, start_time)

    errors.add(:base, "This time slot is already booked") if overlapping.exists?
  end

  def within_advance_booking_limits
    return unless service.present? && start_time.present?

    max_date = Date.current + service.max_advance_days.days
    min_time = Time.current + service.min_advance_hours.hours

    errors.add(:start_time, "is too far in advance") if start_time.to_date > max_date
    errors.add(:start_time, "requires more advance notice") if start_time < min_time
  end
end