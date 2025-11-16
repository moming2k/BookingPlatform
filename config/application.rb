require_relative "boot"

require "rails/all"

# Load dotenv before other gems
require 'dotenv'
Dotenv.load

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BookingPlatform
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    config.time_zone = "UTC"
    config.eager_load_paths << Rails.root.join("lib")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Use Sidekiq for Active Job
    config.active_job.queue_adapter = :sidekiq

    # Allow Action Cable requests from these domains
    config.action_cable.allowed_request_origins = [
      'http://localhost:3000',
      'https://localhost:3000'
    ]

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]
  end
end