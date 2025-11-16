class Service < ApplicationRecord
  # Soft deletes
  acts_as_paranoid

  # Friendly URLs
  extend FriendlyId
  friendly_id :name, use: :slugged

  # Associations
  has_many :availability_schedules, dependent: :destroy
  has_many :bookings, dependent: :restrict_with_error
  has_many :blocked_dates, dependent: :destroy

  # Money - using decimal price column instead of price_cents
  # monetize :price_cents, as: "price"

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :buffer_time_minutes, numericality: { greater_than_or_equal_to: 0 }
  validates :max_advance_days, numericality: { greater_than: 0 }
  validates :min_advance_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, allow_blank: true }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }
  scope :with_availability, -> { joins(:availability_schedules).distinct }

  # Callbacks
  before_validation :set_defaults
  after_create :create_default_availability

  # Availability Methods
  def available_on?(date)
    return false unless active?
    return false if blocked_on?(date)
    return false unless has_schedule_for?(date)
    true
  end

  def available_slots(date)
    return [] unless available_on?(date)

    day_schedule = availability_schedules_for(date)
    return [] if day_schedule.empty?

    slots = []
    day_schedule.each do |schedule|
      current_time = DateTime.parse("#{date} #{schedule.start_time}")
      end_time = DateTime.parse("#{date} #{schedule.end_time}")

      while current_time + duration_minutes.minutes <= end_time
        slot_end = current_time + duration_minutes.minutes

        # Check if slot is not already booked
        unless slot_booked?(current_time, slot_end)
          slots << {
            start_time: current_time,
            end_time: slot_end,
            available: true,
            service_id: id
          }
        end

        current_time += (duration_minutes + buffer_time_minutes).minutes
      end
    end

    slots
  end

  def next_available_slot
    (Date.current..Date.current + max_advance_days.days).each do |date|
      slots = available_slots(date)
      return slots.first if slots.any?
    end
    nil
  end

  def blocked_on?(date)
    blocked_dates.where(blocked_date: date).exists? ||
      blocked_dates.where(service_id: nil, blocked_date: date).exists?
  end

  def has_schedule_for?(date)
    day_of_week = date.wday
    availability_schedules
      .active
      .where(day_of_week: day_of_week)
      .where("valid_from IS NULL OR valid_from <= ?", date)
      .where("valid_until IS NULL OR valid_until >= ?", date)
      .exists?
  end

  def availability_schedules_for(date)
    day_of_week = date.wday
    availability_schedules
      .active
      .where(day_of_week: day_of_week)
      .where("valid_from IS NULL OR valid_from <= ?", date)
      .where("valid_until IS NULL OR valid_until >= ?", date)
  end

  def slot_booked?(start_time, end_time)
    bookings
      .where(status: ["pending", "confirmed"])
      .where("start_time < ? AND end_time > ?", end_time, start_time)
      .exists?
  end

  # Booking Methods
  def book_slot!(user, start_time, options = {})
    end_time = start_time + duration_minutes.minutes

    raise "Slot not available" if slot_booked?(start_time, end_time)
    raise "Service not available on this date" unless available_on?(start_time.to_date)

    bookings.create!(
      user: user,
      start_time: start_time,
      end_time: end_time,
      amount: price,
      currency: currency,
      status: "pending",
      notes: options[:notes],
      metadata: options[:metadata] || {}
    )
  end

  # Statistics
  def booking_count
    bookings.where(status: ["confirmed", "completed"]).count
  end

  def revenue
    bookings
      .joins(:payments)
      .where(payments: { status: "succeeded" })
      .sum("payments.amount")
  end

  def utilization_rate(start_date, end_date)
    total_available_hours = calculate_available_hours(start_date, end_date)
    return 0 if total_available_hours == 0

    booked_hours = bookings
      .where(status: ["confirmed", "completed"])
      .where("start_time >= ? AND end_time <= ?", start_date, end_date)
      .sum { |b| (b.end_time - b.start_time) / 1.hour }

    (booked_hours / total_available_hours * 100).round(2)
  end

  private

  def set_defaults
    self.currency ||= "USD"
    self.buffer_time_minutes ||= 0
    self.max_advance_days ||= 60
    self.min_advance_hours ||= 24
    self.color ||= "#" + "%06x" % (rand * 0xffffff)
  end

  def create_default_availability
    # Create default Monday-Friday 9 AM - 5 PM availability
    (1..5).each do |day|
      availability_schedules.create!(
        day_of_week: day,
        start_time: "09:00",
        end_time: "17:00",
        active: true
      )
    end
  end

  def calculate_available_hours(start_date, end_date)
    total_hours = 0
    (start_date..end_date).each do |date|
      schedules = availability_schedules_for(date)
      schedules.each do |schedule|
        total_hours += (schedule.end_time - schedule.start_time) / 1.hour
      end
    end
    total_hours
  end
end