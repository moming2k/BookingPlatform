require 'csv'

module Admin
  class BookingsController < BaseController
    def index
      @stats = fetch_booking_stats
      @bookings = fetch_bookings

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_csv(fetch_bookings(paginate: false)),
                    filename: "bookings-#{Date.current}.csv",
                    type: 'text/csv'
        end
      end
    end

    def show
      @booking = Booking.includes(:user, :service, :payment).find(params[:id])
      @related_bookings = @booking.user.bookings.where.not(id: @booking.id).order(start_time: :desc).limit(5)
    end

    def confirm
      @booking = Booking.find(params[:id])
      if @booking.update(status: 'confirmed')
        redirect_to admin_booking_path(@booking), notice: 'Booking confirmed successfully.'
      else
        redirect_to admin_booking_path(@booking), alert: 'Failed to confirm booking.'
      end
    end

    def cancel
      @booking = Booking.find(params[:id])
      if @booking.update(status: 'cancelled')
        # TODO: Process refund if needed
        redirect_to admin_booking_path(@booking), notice: 'Booking cancelled successfully.'
      else
        redirect_to admin_booking_path(@booking), alert: 'Failed to cancel booking.'
      end
    end

    def mark_complete
      @booking = Booking.find(params[:id])
      if @booking.update(status: 'completed')
        redirect_to admin_booking_path(@booking), notice: 'Booking marked as complete.'
      else
        redirect_to admin_booking_path(@booking), alert: 'Failed to mark booking as complete.'
      end
    end

    def mark_no_show
      @booking = Booking.find(params[:id])
      if @booking.update(status: 'no_show')
        redirect_to admin_booking_path(@booking), notice: 'Booking marked as no-show.'
      else
        redirect_to admin_booking_path(@booking), alert: 'Failed to mark booking as no-show.'
      end
    end

    def calendar
      @bookings = Booking.includes(:user, :service)
                         .where(start_time: params[:start]..params[:end])
                         .order(:start_time)

      render json: @bookings.map { |booking|
        {
          id: booking.id,
          title: "#{booking.user.name} - #{booking.service.name}",
          start: booking.start_time,
          end: booking.end_time,
          color: status_color(booking.status)
        }
      }
    end

    def export
      @bookings = fetch_bookings(paginate: false)

      respond_to do |format|
        format.csv do
          send_data generate_csv(@bookings),
                    filename: "bookings-#{Date.current}.csv",
                    type: 'text/csv'
        end
      end
    end

    private

    def fetch_booking_stats
      {
        total_bookings: Booking.where('created_at >= ?', Date.current.beginning_of_month).count,
        pending_confirmations: Booking.where(status: 'pending').count,
        today_bookings: Booking.where(start_time: Date.current.beginning_of_day..Date.current.end_of_day).count,
        upcoming_week: Booking.where(start_time: Date.current..7.days.from_now).count
      }
    end

    def fetch_bookings(paginate: true)
      bookings = Booking.includes(:user, :service, :payment).order(start_time: :desc)

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        bookings = bookings.joins(:user).where(
          'bookings.booking_reference LIKE ? OR users.name LIKE ? OR users.email LIKE ?',
          search_term, search_term, search_term
        )
      end

      # Filter by status
      bookings = bookings.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

      # Filter by date range
      if params[:date_range].present?
        case params[:date_range]
        when 'today'
          bookings = bookings.where(start_time: Date.current.beginning_of_day..Date.current.end_of_day)
        when 'this_week'
          bookings = bookings.where(start_time: Date.current.beginning_of_week..Date.current.end_of_week)
        when 'this_month'
          bookings = bookings.where(start_time: Date.current.beginning_of_month..Date.current.end_of_month)
        when 'custom'
          if params[:start_date].present? && params[:end_date].present?
            bookings = bookings.where(start_time: params[:start_date]..params[:end_date])
          end
        end
      end

      # Filter by service
      bookings = bookings.where(service_id: params[:service_id]) if params[:service_id].present?

      # Filter by payment status
      if params[:payment_status].present?
        bookings = bookings.joins(:payment).where(payments: { status: params[:payment_status] })
      end

      paginate ? bookings.page(params[:page]).per(25) : bookings
    end

    def status_color(status)
      case status
      when 'confirmed' then '#10b981'
      when 'pending' then '#f59e0b'
      when 'completed' then '#3b82f6'
      when 'cancelled' then '#ef4444'
      when 'no_show' then '#6b7280'
      else '#9ca3af'
      end
    end

    def generate_csv(bookings)
      CSV.generate(headers: true) do |csv|
        csv << ['Reference', 'Customer', 'Email', 'Service', 'Date', 'Time', 'Amount', 'Status', 'Payment Status']

        bookings.each do |booking|
          csv << [
            booking.booking_reference,
            booking.user.name,
            booking.user.email,
            booking.service.name,
            booking.start_time.strftime('%Y-%m-%d'),
            booking.start_time.strftime('%I:%M %p'),
            booking.amount,
            booking.status,
            booking.payment&.status || 'N/A'
          ]
        end
      end
    end
  end
end
