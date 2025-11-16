# AWS SES Configuration
require 'aws-sdk-ses'

if Rails.application.credentials.aws.present?
  Aws.config.update({
    region: Rails.application.credentials.aws[:region] || 'us-east-1',
    credentials: Aws::Credentials.new(
      Rails.application.credentials.aws[:access_key_id],
      Rails.application.credentials.aws[:secret_access_key]
    )
  })

  # Configure Action Mailer to use AWS SES
  Rails.application.config.action_mailer.delivery_method = :ses
  Rails.application.config.action_mailer.ses_settings = {
    region: Rails.application.credentials.aws[:region] || 'us-east-1',
    access_key_id: Rails.application.credentials.aws[:access_key_id],
    secret_access_key: Rails.application.credentials.aws[:secret_access_key]
  }
end

# Development environment uses letter_opener
if Rails.env.development?
  Rails.application.config.action_mailer.delivery_method = :letter_opener
  Rails.application.config.action_mailer.perform_deliveries = true
end

# Test environment
if Rails.env.test?
  Rails.application.config.action_mailer.delivery_method = :test
end