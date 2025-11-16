class BookingsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :availability, :calendar, :select_time, :review, :create_guest_booking]
  before_action :set_booking, only: [:show, :cancel, :reschedule, :receipt]
  before_action :set_service, only: [:new, :create, :availability, :select_time]

  def index
    @upcoming_bookings = current_user.bookings
                                     .where(status: ['confirmed', 'pending'])
                                     .where('start_time > ?', Time.current)
                                     .includes(:service, :payment)
                                     .order(start_time: :asc)
                                     .page(params[:page])
                                     .per(per_page)

    @past_bookings = current_user.bookings
                                 .where(status: ['confirmed', 'completed'])
                                 .where('end_time < ?', Time.current)
                                 .includes(:service, :payment)
                                 .order(start_time: :desc)
                                 .page(params[:past_page])
                                 .per(per_page)

    @cancelled_bookings = current_user.bookings
                                      .where(status: 'cancelled')
                                      .includes(:service, :payment)
                                      .order(cancelled_at: :desc)
                                      .page(params[:cancelled_page])
                                      .per(per_page)
  end

  def show
    authorize @booking
  end

  def new
    @available_dates = calculate_available_dates
  end

  def select_time
    # Store booking details in session
    session[:pending_booking] = {
      service_id: @service.id,
      start_time: params[:start_time],
      end_time: params[:end_time],
      notes: params[:notes]
    }

    # Redirect to review page for both guests and signed-in users
    redirect_to review_booking_path
  end

  def review
    # Show booking review page with service details and guest information form
    unless session[:pending_booking]
      redirect_to services_path, alert: "No booking in progress"
      return
    end

    @service = Service.find(session[:pending_booking]['service_id'])
    @start_time = Time.parse(session[:pending_booking]['start_time'])
    @end_time = Time.parse(session[:pending_booking]['end_time'])
    @notes = session[:pending_booking]['notes']
  end

  def create_guest_booking
    # Handle guest booking submission - create user, send magic link, prepare booking
    email = params[:email]&.strip&.downcase
    name = params[:name]&.strip
    phone = params[:phone]&.strip
    notes = params[:notes]

    unless email.present?
      redirect_to review_booking_path, alert: "Email is required"
      return
    end

    # Find or create user by email
    user = User.find_or_initialize_by(email: email)
    user.name = name if name.present?
    user.phone = phone if phone.present?

    if user.save
      # Generate and send magic link
      user.generate_magic_link!

      # Send magic link email
      MagicLinkMailer.send_magic_link(user).deliver_now

      # Store guest booking details in session to create after login
      session[:pending_booking].merge!({
        'guest_email' => email,
        'guest_name' => name,
        'guest_phone' => phone,
        'notes' => notes
      })

      # Set return path to confirm and create booking after magic link login
      session[:return_to] = confirm_booking_path

      # Redirect to check email page
      redirect_to login_path, notice: "We've sent a magic link to #{email}. Please check your email to confirm your booking."
    else
      redirect_to review_booking_path, alert: "Error: #{user.errors.full_messages.join(', ')}"
    end
  end

  def confirm
    # This page shows booking details and asks user to confirm
    unless session[:pending_booking]
      redirect_to services_path, alert: "No booking in progress"
      return
    end

    @service = Service.find(session[:pending_booking]['service_id'])
    @start_time = Time.parse(session[:pending_booking]['start_time'])
    @end_time = Time.parse(session[:pending_booking]['end_time'])
    @notes = session[:pending_booking]['notes']
  end

  def create
    Rails.logger.info "CREATE ACTION: session[:pending_booking] = #{session[:pending_booking].inspect}"

    unless session[:pending_booking]
      Rails.logger.info "CREATE ACTION: No pending booking found, redirecting"
      redirect_to confirm_booking_path, alert: "No booking in progress"
      return
    end

    booking_data = session[:pending_booking]
    @service = Service.find(booking_data['service_id'])

    # Use notes from params if provided (for signed-in users), otherwise use from session
    notes = params[:notes].presence || booking_data['notes']

    @booking = current_user.bookings.build(
      service: @service,
      start_time: booking_data['start_time'],
      end_time: booking_data['end_time'],
      notes: notes
    )

    if @booking.save
      log_activity("booking_created", @booking)
      session.delete(:pending_booking)

      # Redirect to payment page
      redirect_to booking_payment_path(@booking), notice: "Booking created. Please complete payment to confirm."
    else
      redirect_to new_booking_path(service_id: @service), alert: @booking.errors.full_messages.join(", ")
    end
  end

  def availability
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @available_slots = @service.available_slots(date)

    respond_to do |format|
      format.json { render json: @available_slots }
      format.html { render partial: "available_slots", locals: { slots: @available_slots } }
    end
  rescue ArgumentError
    render json: { error: "Invalid date format" }, status: :unprocessable_entity
  end

  def calendar
    @services = Service.active.ordered
    @selected_service = params[:service_id].present? ? Service.find(params[:service_id]) : @services.first
    @month = if params[:month].present?
               # Handle YYYY-MM format by appending -01
               month_str = params[:month].match?(/^\d{4}-\d{2}$/) ? "#{params[:month]}-01" : params[:month]
               Date.parse(month_str)
             else
               Date.current
             end
    @available_days = calculate_available_days(@selected_service, @month)

    respond_to do |format|
      format.html
      format.json { render json: @available_days }
    end
  end

  def cancel
    authorize @booking

    if @booking.can_cancel?
      reason = params[:cancellation_reason] || "Cancelled by user"

      if @booking.cancel!(current_user, reason)
        log_activity("booking_cancelled", @booking, { reason: reason })
        redirect_to bookings_path, notice: "Booking successfully cancelled."
      else
        redirect_to @booking, alert: "Unable to cancel booking. Please contact support."
      end
    else
      redirect_to @booking, alert: "This booking cannot be cancelled."
    end
  end

  def reschedule
    authorize @booking

    if @booking.can_cancel? && params[:new_time].present?
      new_time = DateTime.parse(params[:new_time])

      ActiveRecord::Base.transaction do
        # Create new booking with same service
        new_booking = current_user.bookings.create!(
          service: @booking.service,
          start_time: new_time,
          end_time: new_time + @booking.service.duration_minutes.minutes,
          notes: "Rescheduled from #{@booking.formatted_date} #{@booking.formatted_time_range}\n#{@booking.notes}"
        )

        # Cancel old booking
        @booking.cancel!(current_user, "Rescheduled to #{new_booking.formatted_date}")

        log_activity("booking_rescheduled", new_booking, {
          old_booking_id: @booking.id,
          old_time: @booking.start_time,
          new_time: new_time
        })

        redirect_to new_booking, notice: "Booking successfully rescheduled."
      end
    else
      redirect_to @booking, alert: "Unable to reschedule booking."
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @booking, alert: "Invalid reschedule request: #{e.message}"
  end

  def receipt
    authorize @booking
    @payment = @booking.payment

    respond_to do |format|
      format.html
      format.pdf { render pdf: "receipt_#{@booking.booking_reference}" }
    end
  end

  private

  def set_booking
    @booking = current_user.bookings.find(params[:id])
  end

  def set_service
    @service = Service.active.friendly.find(params[:service_id])
  end

  def booking_params
    params.require(:booking).permit(:start_time, :end_time, :notes, :metadata)
  end

  def calculate_available_dates
    dates = {}
    (Date.current..Date.current + @service.max_advance_days.days).each do |date|
      dates[date] = @service.available_slots(date).any?
    end
    dates
  end

  def calculate_available_days(service, month)
    start_date = month.beginning_of_month
    end_date = month.end_of_month
    available_days = []

    (start_date..end_date).each do |date|
      if service.available_on?(date) && service.available_slots(date).any?
        available_days << date.day
      end
    end

    available_days
  end
end