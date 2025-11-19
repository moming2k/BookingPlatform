module Admin
  class DashboardController < BaseController
    def index
      @stats = fetch_dashboard_stats
      @next_three_days_bookings = fetch_next_three_days_bookings
      @recent_bookings = fetch_recent_bookings
      @upcoming_bookings = fetch_upcoming_bookings
      @recent_payments = fetch_recent_payments
      @top_services = fetch_top_services
      @revenue_chart_data = fetch_revenue_chart_data
      @bookings_chart_data = fetch_bookings_chart_data
    end

    private

    def fetch_dashboard_stats
      {
        total_bookings: Booking.count,
        active_bookings: Booking.active.count,
        today_bookings: Booking.today.count,
        total_revenue: Payment.succeeded.sum(:amount),
        month_revenue: Payment.succeeded.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).sum(:amount),
        total_users: User.count,
        new_users_this_month: User.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count,
        active_services: Service.active.count
      }
    end

    def fetch_recent_bookings
      Booking.includes(:user, :service, :payment)
             .order(created_at: :desc)
             .limit(10)
    end

    def fetch_upcoming_bookings
      Booking.upcoming
             .includes(:user, :service)
             .limit(10)
    end

    def fetch_recent_payments
      Payment.includes(:booking, :user)
             .order(created_at: :desc)
             .limit(10)
    end

    def fetch_top_services
      Service.joins(:bookings)
             .where(bookings: { status: %w[confirmed completed] })
             .group('services.id')
             .order('COUNT(bookings.id) DESC')
             .limit(5)
             .pluck('services.name', 'COUNT(bookings.id)', 'SUM(bookings.amount)')
             .map { |name, count, revenue| { name: name, bookings: count, revenue: revenue } }
    end

    def fetch_revenue_chart_data
      Payment.succeeded
             .where(created_at: 30.days.ago..Date.current)
             .group_by_day(:created_at)
             .sum(:amount)
    end

    def fetch_bookings_chart_data
      Booking.where(created_at: 30.days.ago..Date.current)
             .group_by_day(:created_at)
             .count
    end

    def fetch_next_three_days_bookings
      today = Date.current
      next_three_days = (today..today + 2.days).to_a

      bookings_by_date = {}
      next_three_days.each do |date|
        bookings_by_date[date] = Booking.includes(:user, :service)
                                        .where(start_time: date.beginning_of_day..date.end_of_day)
                                        .where(status: %w[pending confirmed])
                                        .order(:start_time)
      end
      bookings_by_date
    end
  end
end
