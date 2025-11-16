class BookingMailer < ApplicationMailer
  def confirmation(booking)
    @booking = booking
    @user = booking.user
    @service = booking.service
    @calendar_attachment = generate_ics_attachment

    attachments["booking_#{@booking.booking_reference}.ics"] = @calendar_attachment

    mail(
      to: @user.email,
      subject: "Booking Confirmed - #{@service.name}",
      from: default_from_email
    )
  end

  def reminder(booking)
    @booking = booking
    @user = booking.user
    @service = booking.service

    mail(
      to: @user.email,
      subject: "Booking Reminder - #{@service.name} Tomorrow",
      from: default_from_email
    )
  end

  def cancellation(booking)
    @booking = booking
    @user = booking.user
    @service = booking.service
    @refund_status = booking.payment&.refunded? ? "Refund is being processed" : nil

    mail(
      to: @user.email,
      subject: "Booking Cancelled - #{@service.name}",
      from: default_from_email
    )
  end

  def completion(booking)
    @booking = booking
    @user = booking.user
    @service = booking.service

    mail(
      to: @user.email,
      subject: "Thank You - #{@service.name}",
      from: default_from_email
    )
  end

  def reschedule_notification(booking, old_booking)
    @booking = booking
    @old_booking = old_booking
    @user = booking.user
    @service = booking.service

    mail(
      to: @user.email,
      subject: "Booking Rescheduled - #{@service.name}",
      from: default_from_email
    )
  end

  private

  def default_from_email
    Rails.application.credentials.dig(:email, :from_address) || "noreply@bookingplatform.com"
  end

  def generate_ics_attachment
    cal = Icalendar::Calendar.new
    cal.event do |e|
      e.dtstart = @booking.start_time
      e.dtend = @booking.end_time
      e.summary = @service.name
      e.description = "Booking Reference: #{@booking.booking_reference}\n\n#{@booking.notes}"
      e.location = @service.settings["location"] if @service.settings["location"].present?
      e.uid = @booking.booking_reference
      e.status = "CONFIRMED"
      e.organizer = "mailto:#{default_from_email}"
      e.attendee = "mailto:#{@user.email}"
    end
    cal.to_ical
  end
end