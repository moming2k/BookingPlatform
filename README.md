# Booking Platform

A comprehensive booking system with payment integration built with Ruby on Rails.

## Features

- **User Authentication**: Passwordless login via magic links sent through email
- **Booking Management**: Calendar view with available time slots
- **Payment Processing**: Integrated Stripe payment system
- **Admin Dashboard**: Complete admin interface for managing bookings, users, and services
- **Email Notifications**: AWS SES integration for transactional emails
- **Responsive Design**: Tailwind CSS for modern, mobile-friendly interface

## Tech Stack

- **Backend**: Ruby on Rails 7.1
- **Database**: PostgreSQL
- **Payments**: Stripe
- **Email**: AWS SES
- **Styling**: Tailwind CSS
- **Background Jobs**: Sidekiq
- **Caching**: Redis

## System Requirements

- Ruby 3.2.0
- PostgreSQL 14+
- Redis 5+
- Node.js 18+
- Yarn or npm

## Setup Instructions

### 1. Clone the repository

```bash
cd booking-platform
```

### 2. Install dependencies

```bash
bundle install
yarn install
```

### 3. Setup environment variables

```bash
cp .env.example .env
```

Edit `.env` file with your configuration:
- Database credentials
- AWS SES credentials
- Stripe API keys
- Redis URL

### 4. Setup database

```bash
rails db:create
rails db:migrate
rails db:seed
```

### 5. Setup Tailwind CSS

```bash
rails tailwindcss:build
```

### 6. Run the application

Start all services:

```bash
# Start Redis
redis-server

# Start Sidekiq (in another terminal)
bundle exec sidekiq

# Start Rails server
rails server

# Watch for Tailwind changes (in another terminal)
rails tailwindcss:watch
```

Visit http://localhost:3000

## Configuration

### AWS SES Setup

1. Verify your domain in AWS SES
2. Create IAM user with SES send permissions
3. Add credentials to `.env` file

### Stripe Setup

1. Create a Stripe account
2. Get your test API keys from Stripe dashboard
3. Add keys to `.env` file
4. Setup webhook endpoint in Stripe dashboard pointing to `/webhooks/stripe`

### Admin Access

To create an admin user:

```ruby
rails console
user = User.find_by(email: "admin@example.com")
user.update(admin: true)
```

## Development

### Running tests

```bash
bundle exec rspec
```

### Code quality

```bash
bundle exec rubocop
bundle exec brakeman
```

### Database migrations

```bash
rails generate migration AddFieldToModel field:type
rails db:migrate
```

## Project Structure

```
booking-platform/
├── app/
│   ├── controllers/       # Request handling
│   ├── models/            # Business logic and data
│   ├── views/             # HTML templates
│   ├── mailers/           # Email templates
│   ├── jobs/              # Background jobs
│   └── assets/            # CSS and images
├── config/
│   ├── routes.rb          # URL routing
│   ├── database.yml       # Database configuration
│   └── initializers/      # App initialization
├── db/
│   ├── migrate/           # Database migrations
│   └── seeds.rb           # Seed data
├── spec/                  # Test files
└── Gemfile               # Ruby dependencies
```

## Key Models

- **User**: Authentication and profile
- **Service**: Bookable services with pricing
- **Booking**: Reservation records
- **Payment**: Payment transactions
- **AvailabilitySchedule**: Service availability rules
- **BlockedDate**: Holidays and unavailable dates

## API Endpoints

### Public Endpoints
- `GET /services` - List all services
- `GET /services/:id/availability` - Get available slots
- `POST /login` - Request magic link

### Authenticated Endpoints
- `GET /bookings` - User's bookings
- `POST /bookings` - Create booking
- `POST /bookings/:id/cancel` - Cancel booking

### Admin Endpoints
- `GET /admin/dashboard` - Admin dashboard
- `GET /admin/bookings` - All bookings
- `POST /admin/bookings/:id/confirm` - Confirm booking

## Deployment

### Heroku Deployment

```bash
# Create Heroku app
heroku create your-app-name

# Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# Add Redis
heroku addons:create heroku-redis:premium-0

# Set environment variables
heroku config:set RAILS_MASTER_KEY=your_master_key
heroku config:set AWS_ACCESS_KEY_ID=your_key
# ... set other variables

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Scale workers
heroku ps:scale web=1 worker=1
```

## Security Considerations

- All user input is sanitized
- CSRF protection enabled
- Secure headers configured
- Payment data never stored locally
- Magic links expire after 15 minutes
- Admin area requires authentication

## License

Copyright 2024 - All Rights Reserved

## Support

For issues or questions, please contact support@bookingplatform.com