class User < ApplicationRecord
  # Soft deletes
  acts_as_paranoid

  # Associations
  has_many :bookings, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 100 }
  validates :phone, format: { with: /\A[\d\s\-\+\(\)]+\z/, allow_blank: true }

  # Scopes
  scope :admins, -> { where(admin: true) }
  scope :customers, -> { where(admin: false) }
  scope :with_bookings, -> { joins(:bookings).distinct }

  # Callbacks
  before_validation :normalize_email
  before_create :ensure_stripe_customer

  # Magic Link Authentication
  def generate_magic_link!
    self.magic_link_token = SecureRandom.urlsafe_base64(32)
    self.magic_link_sent_at = Time.current
    save!
  end

  def magic_link_valid?
    return false unless magic_link_token.present? && magic_link_sent_at.present?
    magic_link_sent_at > 15.minutes.ago
  end

  def confirm_magic_link!
    return false unless magic_link_valid?

    self.magic_link_confirmed_at = Time.current
    self.last_login_at = Time.current
    self.magic_link_token = nil
    save!
  end

  def clear_magic_link!
    self.magic_link_token = nil
    self.magic_link_sent_at = nil
    self.magic_link_confirmed_at = nil
    save!
  end

  # Stripe Integration
  def stripe_customer
    return nil unless stripe_customer_id.present?
    @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to retrieve Stripe customer: #{e.message}"
    nil
  end

  def create_or_update_stripe_customer!
    if stripe_customer_id.present?
      Stripe::Customer.update(
        stripe_customer_id,
        email: email,
        name: name,
        phone: phone,
        metadata: { user_id: id }
      )
    else
      customer = Stripe::Customer.create(
        email: email,
        name: name,
        phone: phone,
        metadata: { user_id: id }
      )
      update!(stripe_customer_id: customer.id)
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to create/update Stripe customer: #{e.message}"
    raise
  end

  # Booking helpers
  def upcoming_bookings
    bookings.where("start_time > ?", Time.current)
            .where(status: ["confirmed", "pending"])
            .order(start_time: :asc)
  end

  def past_bookings
    bookings.where("end_time < ?", Time.current)
            .order(start_time: :desc)
  end

  def total_spent
    payments.where(status: "succeeded").sum(:amount)
  end

  # Admin helpers
  def make_admin!
    update!(admin: true)
  end

  def revoke_admin!
    update!(admin: false)
  end

  # Display helpers
  def display_name
    name.presence || email.split("@").first
  end

  def initials
    if name.present?
      name.split.map(&:first).join.upcase
    else
      email[0..1].upcase
    end
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def ensure_stripe_customer
    # Skip Stripe customer creation in test environment or for test users
    return if Rails.env.test?
    return if email.present? && email.match?(/@example\.(com|org)$/)

    create_or_update_stripe_customer! unless stripe_customer_id.present?
  rescue => e
    Rails.logger.error "Failed to ensure Stripe customer: #{e.message}"
  end
end