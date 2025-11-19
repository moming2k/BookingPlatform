require 'csv'

module Admin
  class PaymentsController < BaseController
    def index
      @stats = fetch_payment_stats
      @payments = fetch_payments

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_csv(fetch_payments(paginate: false)),
                    filename: "payments-#{Date.current}.csv",
                    type: 'text/csv',
                    disposition: 'attachment'
        end
      end
    end

    def show
      @payment = Payment.includes(:booking, :user).find(params[:id])
    end

    def refund
      @payment = Payment.find(params[:id])

      # TODO: Implement Stripe refund logic
      # For now, just update the status
      if @payment.update(status: 'refunded')
        redirect_to admin_payment_path(@payment), notice: 'Payment refunded successfully.'
      else
        redirect_to admin_payment_path(@payment), alert: 'Failed to refund payment.'
      end
    end

    private

    def fetch_payment_stats
      {
        total_revenue: Payment.succeeded.sum(:amount),
        month_revenue: Payment.succeeded.where('created_at >= ?', Date.current.beginning_of_month).sum(:amount),
        week_revenue: Payment.succeeded.where('created_at >= ?', Date.current.beginning_of_week).sum(:amount),
        today_revenue: Payment.succeeded.where('created_at >= ?', Date.current.beginning_of_day).sum(:amount),
        avg_booking_value: Payment.succeeded.average(:amount) || 0,
        refund_rate: calculate_refund_rate
      }
    end

    def fetch_payments(paginate: true)
      payments = Payment.includes(:booking, :user).order(created_at: :desc)

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        payments = payments.joins(:booking, :user).where(
          'payments.stripe_payment_intent_id LIKE ? OR bookings.booking_reference LIKE ? OR users.name LIKE ?',
          search_term, search_term, search_term
        )
      end

      # Filter by status
      payments = payments.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

      # Filter by date range
      if params[:date_range].present?
        case params[:date_range]
        when 'today'
          payments = payments.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
        when 'this_week'
          payments = payments.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
        when 'this_month'
          payments = payments.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
        end
      end

      # Filter by amount range
      payments = payments.where('amount >= ?', params[:min_amount]) if params[:min_amount].present?
      payments = payments.where('amount <= ?', params[:max_amount]) if params[:max_amount].present?

      paginate ? payments.page(params[:page]).per(25) : payments
    end

    def calculate_refund_rate
      total = Payment.succeeded.count
      return 0 if total.zero?

      refunded = Payment.where(status: 'refunded').count
      ((refunded.to_f / total) * 100).round(1)
    end

    def generate_csv(payments)
      CSV.generate(headers: true) do |csv|
        csv << ['Transaction ID', 'Booking Reference', 'Customer', 'Email', 'Amount', 'Status', 'Date']

        payments.each do |payment|
          csv << [
            payment.stripe_payment_intent_id || 'N/A',
            payment.booking.booking_reference,
            payment.user.name,
            payment.user.email,
            payment.amount,
            payment.status,
            payment.created_at.strftime('%Y-%m-%d %H:%M')
          ]
        end
      end
    end
  end
end
