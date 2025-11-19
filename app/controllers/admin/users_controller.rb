require 'csv'

module Admin
  class UsersController < BaseController
    def index
      @stats = fetch_user_stats
      @users = fetch_users

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_csv(fetch_users(paginate: false)),
                    filename: "users-#{Date.current}.csv",
                    type: 'text/csv',
                    disposition: 'attachment'
        end
      end
    end

    def show
      @user = User.find(params[:id])
      @bookings = @user.bookings.order(start_time: :desc).limit(10)
      @user_stats = calculate_user_stats(@user)
    end

    def make_admin
      @user = User.find(params[:id])
      if @user.update(admin: true)
        redirect_to admin_user_path(@user), notice: 'User granted admin privileges.'
      else
        redirect_to admin_user_path(@user), alert: 'Failed to grant admin privileges.'
      end
    end

    def revoke_admin
      @user = User.find(params[:id])
      if @user.update(admin: false)
        redirect_to admin_user_path(@user), notice: 'Admin privileges revoked.'
      else
        redirect_to admin_user_path(@user), alert: 'Failed to revoke admin privileges.'
      end
    end

    def impersonate
      @user = User.find(params[:id])
      # Store the admin user ID in session to allow returning
      session[:admin_user_id] = current_user.id
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Now impersonating #{@user.name}"
    end

    def stop_impersonating
      admin_id = session[:admin_user_id]
      if admin_id
        session[:user_id] = admin_id
        session.delete(:admin_user_id)
        redirect_to admin_dashboard_path, notice: 'Stopped impersonating user'
      else
        redirect_to root_path, alert: 'Not currently impersonating'
      end
    end

    private

    def fetch_user_stats
      {
        total_users: User.count,
        new_this_month: User.where('created_at >= ?', Date.current.beginning_of_month).count,
        active_users: User.joins(:bookings).where('bookings.created_at >= ?', 30.days.ago).distinct.count,
        admin_users: User.where(admin: true).count
      }
    end

    def fetch_users(paginate: true)
      users = User.left_joins(:bookings, :payments)
                  .select('users.*, COUNT(DISTINCT bookings.id) as bookings_count, COALESCE(SUM(payments.amount), 0) as total_spent')
                  .group('users.id')
                  .order(created_at: :desc)

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        users = users.where('users.name LIKE ? OR users.email LIKE ?', search_term, search_term)
      end

      # Filter by role
      users = users.where(admin: params[:role] == 'admin') if params[:role].present? && params[:role] != 'all'

      # Filter by booking count
      if params[:booking_count].present?
        case params[:booking_count]
        when '0'
          users = users.having('COUNT(DISTINCT bookings.id) = 0')
        when '1-5'
          users = users.having('COUNT(DISTINCT bookings.id) BETWEEN 1 AND 5')
        when '6-10'
          users = users.having('COUNT(DISTINCT bookings.id) BETWEEN 6 AND 10')
        when '10+'
          users = users.having('COUNT(DISTINCT bookings.id) > 10')
        end
      end

      paginate ? users.page(params[:page]).per(25) : users
    end

    def calculate_user_stats(user)
      {
        total_bookings: user.bookings.count,
        total_spent: user.payments.succeeded.sum(:amount),
        avg_booking_value: user.payments.succeeded.average(:amount) || 0,
        cancellation_rate: calculate_cancellation_rate(user)
      }
    end

    def calculate_cancellation_rate(user)
      total = user.bookings.count
      return 0 if total.zero?

      cancelled = user.bookings.where(status: 'cancelled').count
      ((cancelled.to_f / total) * 100).round(1)
    end

    def generate_csv(users)
      CSV.generate(headers: true) do |csv|
        csv << ['Name', 'Email', 'Role', 'Total Bookings', 'Total Spent', 'Member Since', 'Status']

        users.each do |user|
          csv << [
            user.name,
            user.email,
            user.admin? ? 'Admin' : 'Customer',
            user.bookings_count || 0,
            user.total_spent || 0,
            user.created_at.strftime('%Y-%m-%d'),
            'Active'
          ]
        end
      end
    end
  end
end
