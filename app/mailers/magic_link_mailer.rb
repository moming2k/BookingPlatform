class MagicLinkMailer < ApplicationMailer
  def send_magic_link(user)
    @user = user
    @magic_link_url = magic_link_url(token: @user.magic_link_token)
    @expiry_time = 15.minutes.from_now

    mail(
      to: @user.email,
      subject: "Your Sign-in Link - Booking Platform",
      from: default_from_email
    )
  end

  private

  def default_from_email
    Rails.application.credentials.dig(:email, :from_address) || "noreply@bookingplatform.com"
  end
end