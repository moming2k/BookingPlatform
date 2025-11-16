source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

# Core Rails gems
gem "rails", "~> 7.1.0"
gem "sprockets-rails"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "redis", "~> 5.0"
gem "bootsnap", ">= 1.4.4", require: false

# CSS & Frontend
gem "tailwindcss-rails", "~> 2.0"
gem "sassc-rails"

# Authentication & Security
gem "bcrypt", "~> 3.1.7"
gem "devise", "~> 4.9"
gem "devise-jwt"
gem "omniauth"
gem "pundit" # Authorization

# Payment Processing
gem "stripe", "~> 17.2"
gem "money-rails", "~> 1.15"

# AWS Integration
gem "aws-sdk-ses", "~> 1.50"
gem "aws-sdk-s3", "~> 1.130" # For file uploads if needed

# Background Jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron"

# Calendar & Scheduling
gem "simple_calendar", "~> 3.0"
gem "ice_cube" # Recurring events
gem "holidays" # Holiday detection

# API & Serialization
gem "jsonapi-serializer"
gem "rack-cors"

# Admin Interface
gem "administrate", "~> 0.19"
gem "chartkick" # For admin analytics
gem "groupdate" # For data grouping

# Utilities
gem "friendly_id", "~> 5.5" # SEO-friendly URLs
gem "kaminari" # Pagination
gem "image_processing", "~> 1.12" # Image uploads
gem "acts_as_paranoid" # Soft deletes
gem "paper_trail" # Audit trail
gem "dotenv-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "rubocop-rails", require: false
  gem "brakeman", require: false
end

group :development do
  gem "web-console"
  gem "listen", "~> 3.8"
  gem "spring"
  gem "letter_opener" # Preview emails in browser
  gem "annotate" # Add schema info to models
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  gem "vcr"
  gem "webmock"
  gem "simplecov", require: false
end