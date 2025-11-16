# Seeds file for Booking Platform
# Run with: rails db:seed

puts "Seeding database..."

# Create admin user
admin = User.find_or_create_by(email: "admin@example.com") do |u|
  u.name = "Admin User"
  u.admin = true
  u.phone = "+1234567890"
  u.time_zone = "America/New_York"
end
puts "Admin user created: #{admin.email}"

# Create sample customers
10.times do |i|
  User.find_or_create_by(email: "customer#{i+1}@example.com") do |u|
    u.name = "Customer #{i+1}"
    u.phone = "+123456789#{i}"
    u.time_zone = ["America/New_York", "America/Chicago", "America/Los_Angeles", "Europe/London"].sample
  end
end
puts "Created #{User.where(admin: false).count} customer accounts"

# Create services
services_data = [
  {
    name: "Consultation (30 min)",
    description: "30-minute consultation session for discussing your needs and requirements",
    duration_minutes: 30,
    price: 50.00,
    buffer_time_minutes: 15,
    max_advance_days: 30,
    min_advance_hours: 24,
    color: "#3B82F6"
  },
  {
    name: "Consultation (1 hour)",
    description: "Full hour consultation with detailed analysis and recommendations",
    duration_minutes: 60,
    price: 90.00,
    buffer_time_minutes: 15,
    max_advance_days: 30,
    min_advance_hours: 24,
    color: "#10B981"
  },
  {
    name: "Strategy Session",
    description: "2-hour deep dive strategy session with actionable planning",
    duration_minutes: 120,
    price: 250.00,
    buffer_time_minutes: 30,
    max_advance_days: 45,
    min_advance_hours: 48,
    color: "#8B5CF6"
  },
  {
    name: "Training Workshop",
    description: "Half-day training workshop (4 hours) with materials included",
    duration_minutes: 240,
    price: 500.00,
    buffer_time_minutes: 60,
    max_advance_days: 60,
    min_advance_hours: 72,
    color: "#F59E0B"
  },
  {
    name: "Quick Check-in",
    description: "15-minute quick check-in call for updates and follow-ups",
    duration_minutes: 15,
    price: 25.00,
    buffer_time_minutes: 5,
    max_advance_days: 14,
    min_advance_hours: 12,
    color: "#EF4444"
  }
]

services_data.each_with_index do |service_data, index|
  service = Service.find_or_create_by(name: service_data[:name]) do |s|
    s.description = service_data[:description]
    s.duration_minutes = service_data[:duration_minutes]
    s.price = service_data[:price]
    s.buffer_time_minutes = service_data[:buffer_time_minutes]
    s.max_advance_days = service_data[:max_advance_days]
    s.min_advance_hours = service_data[:min_advance_hours]
    s.color = service_data[:color]
    s.position = index + 1
    s.active = true
  end

  # Create availability schedules (Monday to Friday, different hours for each service)
  if service.availability_schedules.empty?
    case service.name
    when "Quick Check-in"
      # Available all weekdays, multiple slots
      (1..5).each do |day|
        service.availability_schedules.create!(
          day_of_week: day,
          start_time: "08:00",
          end_time: "18:00",
          active: true
        )
      end
    when "Training Workshop"
      # Only Tuesday and Thursday
      [2, 4].each do |day|
        service.availability_schedules.create!(
          day_of_week: day,
          start_time: "09:00",
          end_time: "17:00",
          active: true
        )
      end
    else
      # Standard Monday to Friday
      (1..5).each do |day|
        service.availability_schedules.create!(
          day_of_week: day,
          start_time: "09:00",
          end_time: "17:00",
          active: true
        )
      end
    end
  end
end
puts "Created #{Service.count} services with availability schedules"

# Create some blocked dates (holidays)
BlockedDate.find_or_create_by(
  blocked_date: Date.new(Date.current.year, 12, 25),
  reason: "Christmas Day",
  recurring_yearly: true
)

BlockedDate.find_or_create_by(
  blocked_date: Date.new(Date.current.year, 1, 1),
  reason: "New Year's Day",
  recurring_yearly: true
)

BlockedDate.find_or_create_by(
  blocked_date: Date.new(Date.current.year, 7, 4),
  reason: "Independence Day",
  recurring_yearly: true
)
puts "Created #{BlockedDate.count} blocked dates"

# Create sample bookings (only in development)
if false && Rails.env.development?
  customers = User.where(admin: false).limit(5)
  services = Service.active

  # Past bookings (completed)
  10.times do |i|
    customer = customers.sample
    service = services.sample
    start_time = (i + 1).days.ago.beginning_of_day + rand(9..16).hours

    booking = Booking.create!(
      user: customer,
      service: service,
      start_time: start_time,
      end_time: start_time + service.duration_minutes.minutes,
      status: "completed",
      amount: service.price,
      confirmed_at: start_time - 1.day,
      notes: "Sample completed booking"
    )

    # Create successful payment
    Payment.create!(
      booking: booking,
      user: customer,
      amount: service.price,
      status: "succeeded",
      paid_at: start_time - 1.day,
      stripe_payment_intent_id: "pi_sample_#{SecureRandom.hex(8)}",
      stripe_charge_id: "ch_sample_#{SecureRandom.hex(8)}"
    )
  end

  # Upcoming bookings (confirmed)
  5.times do |i|
    customer = customers.sample
    service = services.sample
    start_time = (i + 1).days.from_now.beginning_of_day + rand(9..16).hours

    booking = Booking.create!(
      user: customer,
      service: service,
      start_time: start_time,
      end_time: start_time + service.duration_minutes.minutes,
      status: "confirmed",
      amount: service.price,
      confirmed_at: Time.current,
      notes: "Sample upcoming booking"
    )

    # Create successful payment
    Payment.create!(
      booking: booking,
      user: customer,
      amount: service.price,
      status: "succeeded",
      paid_at: Time.current,
      stripe_payment_intent_id: "pi_sample_#{SecureRandom.hex(8)}",
      stripe_charge_id: "ch_sample_#{SecureRandom.hex(8)}"
    )
  end

  # Pending bookings
  3.times do |i|
    customer = customers.sample
    service = services.sample
    start_time = (i + 3).days.from_now.beginning_of_day + rand(9..16).hours

    booking = Booking.create!(
      user: customer,
      service: service,
      start_time: start_time,
      end_time: start_time + service.duration_minutes.minutes,
      status: "pending",
      amount: service.price,
      notes: "Sample pending booking - awaiting payment"
    )

    # Create pending payment
    Payment.create!(
      booking: booking,
      user: customer,
      amount: service.price,
      status: "pending"
    )
  end

  puts "Created sample bookings: #{Booking.completed.count} completed, #{Booking.confirmed.count} confirmed, #{Booking.pending.count} pending"
end

puts "Database seeding completed!"
puts "\nAdmin login:"
puts "Email: admin@example.com"
puts "Use magic link authentication to login"
puts "\nSample customers:"
puts "customer1@example.com through customer10@example.com"