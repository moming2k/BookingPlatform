require 'ostruct'

class Payment < ApplicationRecord
  # Paper trail for audit (disabled until table is created)
  # has_paper_trail

  # Associations
  belongs_to :booking
  belongs_to :user

  # Money - using decimal amount columns instead of cents columns
  # monetize :amount_cents, as: "amount"
  # monetize :refund_amount_cents, as: "refund_amount", allow_nil: true

  # Constants
  STATUSES = %w[pending processing succeeded failed refunded partially_refunded].freeze
  PAYMENT_METHODS = %w[card bank_transfer apple_pay google_pay].freeze

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS, allow_nil: true }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :succeeded, -> { where(status: "succeeded") }
  scope :failed, -> { where(status: "failed") }
  scope :refunded, -> { where(status: %w[refunded partially_refunded]) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :set_defaults
  after_update :handle_status_change

  # Stripe Payment Processing
  def process_payment!
    return false unless can_process?

    begin
      update!(status: "processing")

      # Create or retrieve payment intent
      payment_intent = if stripe_payment_intent_id.present?
                        Stripe::PaymentIntent.retrieve(stripe_payment_intent_id)
                      else
                        create_payment_intent
                      end

      # Confirm payment intent if needed
      if payment_intent.status == "requires_confirmation"
        payment_intent = Stripe::PaymentIntent.confirm(payment_intent.id)
      end

      handle_payment_intent_status(payment_intent)
      true
    rescue Stripe::StripeError => e
      handle_stripe_error(e)
      false
    end
  end

  def create_payment_intent
    # Skip Stripe for test users
    if user.email.match?(/@example\.(com|org)$/)
      # Create a mock payment intent ID for test users
      test_intent_id = "pi_test_#{SecureRandom.hex(12)}"
      update!(stripe_payment_intent_id: test_intent_id)
      return OpenStruct.new(
        id: test_intent_id,
        client_secret: "#{test_intent_id}_secret_#{SecureRandom.hex(16)}"
      )
    end

    intent = Stripe::PaymentIntent.create(
      amount: (amount * 100).to_i, # Convert to cents
      currency: currency.downcase,
      customer: user.stripe_customer_id,
      description: "Booking #{booking.booking_reference} - #{booking.service.name}",
      metadata: {
        booking_id: booking.id,
        user_id: user.id,
        booking_reference: booking.booking_reference
      },
      receipt_email: user.email,
      statement_descriptor_suffix: booking.booking_reference[0..21]
    )

    update!(stripe_payment_intent_id: intent.id)
    intent
  end

  def refund!(amount_to_refund = nil)
    return false unless can_refund?

    begin
      refund_amount = amount_to_refund || amount

      refund = Stripe::Refund.create(
        payment_intent: stripe_payment_intent_id,
        amount: (refund_amount * 100).to_i,
        reason: "requested_by_customer",
        metadata: {
          booking_id: booking.id,
          user_id: user.id
        }
      )

      update!(
        stripe_refund_id: refund.id,
        refund_amount: refund_amount,
        refunded_at: Time.current,
        status: refund_amount == amount ? "refunded" : "partially_refunded",
        stripe_response: stripe_response.merge(refund: refund.to_h)
      )

      # TODO: Implement PaymentMailer for refund notifications
      # send_refund_email
      true
    rescue Stripe::StripeError => e
      handle_stripe_error(e)
      false
    end
  end

  def capture_payment!
    return false unless stripe_payment_intent_id.present?

    begin
      intent = Stripe::PaymentIntent.capture(stripe_payment_intent_id)
      handle_payment_intent_status(intent)
      true
    rescue Stripe::StripeError => e
      handle_stripe_error(e)
      false
    end
  end

  def cancel_payment!
    return false unless can_cancel?

    begin
      Stripe::PaymentIntent.cancel(stripe_payment_intent_id)
      update!(status: "failed", failure_reason: "Payment cancelled")
      true
    rescue Stripe::StripeError => e
      handle_stripe_error(e)
      false
    end
  end

  # Status checks
  def can_process?
    status == "pending" && booking.present? && booking.confirmed?
  end

  def can_refund?
    status == "succeeded" && stripe_payment_intent_id.present?
  end

  def can_cancel?
    %w[pending processing].include?(status) && stripe_payment_intent_id.present?
  end

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def succeeded?
    status == "succeeded"
  end

  def failed?
    status == "failed"
  end

  def refunded?
    %w[refunded partially_refunded].include?(status)
  end

  def fully_refunded?
    status == "refunded"
  end

  def partially_refunded?
    status == "partially_refunded"
  end

  # Webhook handlers
  def self.handle_stripe_webhook(event)
    case event.type
    when "payment_intent.succeeded"
      handle_payment_intent_succeeded(event.data.object)
    when "payment_intent.payment_failed"
      handle_payment_intent_failed(event.data.object)
    when "charge.refunded"
      handle_charge_refunded(event.data.object)
    end
  end

  def self.handle_payment_intent_succeeded(payment_intent)
    payment = find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment

    payment.update!(
      status: "succeeded",
      paid_at: Time.current,
      stripe_charge_id: payment_intent.charges.data.first&.id,
      stripe_response: payment.stripe_response.merge(payment_intent: payment_intent.to_h)
    )
    payment.booking.confirm!
  end

  def self.handle_payment_intent_failed(payment_intent)
    payment = find_by(stripe_payment_intent_id: payment_intent.id)
    return unless payment

    payment.update!(
      status: "failed",
      failure_reason: payment_intent.last_payment_error&.message,
      stripe_response: payment.stripe_response.merge(payment_intent: payment_intent.to_h)
    )
  end

  def self.handle_charge_refunded(charge)
    payment = find_by(stripe_charge_id: charge.id)
    return unless payment

    payment.update!(
      status: charge.refunded ? "refunded" : "partially_refunded",
      refund_amount: (charge.amount_refunded / 100.0),
      refunded_at: Time.current,
      stripe_response: payment.stripe_response.merge(charge: charge.to_h)
    )
  end

  # Email notifications
  def send_receipt_email
    PaymentMailer.receipt(self).deliver_later
  end

  def send_refund_email
    PaymentMailer.refund(self).deliver_later
  end

  def send_failure_email
    PaymentMailer.failure(self).deliver_later
  end

  private

  def set_defaults
    self.currency ||= booking.currency if booking.present?
    self.status ||= "pending"
    self.stripe_response ||= {}
    self.metadata ||= {}
  end

  def handle_payment_intent_status(payment_intent)
    case payment_intent.status
    when "succeeded"
      update!(
        status: "succeeded",
        paid_at: Time.current,
        stripe_charge_id: payment_intent.charges.data.first&.id,
        payment_method: payment_intent.payment_method_types.first,
        stripe_response: stripe_response.merge(payment_intent: payment_intent.to_h)
      )
      booking.confirm!
      # TODO: Implement PaymentMailer for receipt notifications
      # send_receipt_email
    when "requires_action", "requires_source_action"
      update!(
        status: "processing",
        stripe_response: stripe_response.merge(payment_intent: payment_intent.to_h)
      )
    when "canceled"
      update!(
        status: "failed",
        failure_reason: "Payment canceled",
        stripe_response: stripe_response.merge(payment_intent: payment_intent.to_h)
      )
    else
      update!(
        stripe_response: stripe_response.merge(payment_intent: payment_intent.to_h)
      )
    end
  end

  def handle_stripe_error(error)
    Rails.logger.error "Stripe error: #{error.message}"
    update!(
      status: "failed",
      failure_reason: error.message,
      stripe_response: stripe_response.merge(error: { message: error.message, type: error.class.name })
    )
    # TODO: Implement PaymentMailer for failure notifications
    # send_failure_email
  end

  def handle_status_change
    # TODO: Implement background jobs for payment status changes
    # if saved_change_to_status?
    #   case status
    #   when "succeeded"
    #     PaymentSucceededJob.perform_later(self)
    #   when "failed"
    #     PaymentFailedJob.perform_later(self)
    #   when "refunded", "partially_refunded"
    #     PaymentRefundedJob.perform_later(self)
    #   end
    # end
  end
end