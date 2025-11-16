class PaymentsController < ApplicationController
  before_action :set_booking
  before_action :set_payment

  def show
    authorize @payment

    # Generate Stripe Payment Intent client secret for frontend
    if @payment.pending? && @payment.stripe_payment_intent_id.blank?
      @payment.create_payment_intent
    end

    @client_secret = fetch_client_secret
  end

  def process_payment
    authorize @payment

    if @payment.process_payment!
      log_activity("payment_processed", @payment)
      redirect_to booking_path(@booking), notice: "Payment successful! Your booking is confirmed."
    else
      redirect_to booking_payment_path(@booking), alert: "Payment failed. Please try again."
    end
  end

  def webhook
    # Stripe webhook endpoint
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )

      Payment.handle_stripe_webhook(event)

      render json: { success: true }, status: :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid Stripe webhook payload: #{e.message}"
      render json: { error: "Invalid payload" }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Invalid Stripe webhook signature: #{e.message}"
      render json: { error: "Invalid signature" }, status: :unauthorized
    rescue StandardError => e
      Rails.logger.error "Stripe webhook error: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def refund
    authorize @payment

    refund_amount = params[:amount].present? ? params[:amount].to_f : nil

    if @payment.refund!(refund_amount)
      log_activity("payment_refunded", @payment, { amount: refund_amount })
      redirect_to booking_path(@booking), notice: "Refund processed successfully."
    else
      redirect_to booking_path(@booking), alert: "Unable to process refund. Please contact support."
    end
  end

  private

  def set_booking
    @booking = current_user.bookings.find(params[:booking_id])
  end

  def set_payment
    @payment = @booking.payment
    redirect_to booking_path(@booking), alert: "No payment found for this booking." unless @payment
  end

  def fetch_client_secret
    return nil unless @payment.stripe_payment_intent_id.present?

    intent = Stripe::PaymentIntent.retrieve(@payment.stripe_payment_intent_id)
    intent.client_secret
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to retrieve payment intent: #{e.message}"
    nil
  end
end