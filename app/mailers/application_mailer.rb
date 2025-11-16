class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("EMAIL_FROM_ADDRESS", "noreply@bookingplatform.com")
  layout "mailer"
end