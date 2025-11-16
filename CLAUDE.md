# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Database
```bash
# Create and setup database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# Reset database (development only)
bin/rails db:reset

# Run specific migration
bin/rails db:migrate:up VERSION=20231201000000

# Database console
PGPASSWORD=booking_platform_pass psql -h localhost -U booking_platform_user -d booking_platform_dev
```

### Server
```bash
# Start Rails server
bin/rails server

# Build Tailwind CSS (required before first run)
bin/rails tailwindcss:build

# Watch Tailwind for changes (run in separate terminal during development)
bin/rails tailwindcss:watch
```

### Testing
```bash
# Run all E2E tests
npm test

# Run with visible browser
npm run test:headed

# Interactive test UI
npm run test:ui

# Debug mode (step through tests)
npm run test:debug

# View last test report
npm run test:report
```

### Rails Console
```bash
# Open Rails console
bin/rails console

# Common console tasks
User.find_by(email: "user@example.com")
User.create!(email: "admin@example.com", name: "Admin", admin: true)
Booking.where(status: 'pending').count
```

### Code Generation
```bash
# Generate migration
bin/rails generate migration AddFieldToModel field:type

# Generate model
bin/rails generate model ModelName field:type

# Generate controller
bin/rails generate controller ControllerName action1 action2
```

## Architecture Overview

### Authentication System
The app uses **passwordless authentication** via magic links:

1. User enters email at login
2. `SessionsController#create` generates a time-limited magic link token
3. `MagicLinkMailer` sends email with token
4. User clicks link → `SessionsController#magic_link` validates token
5. Session established via `session[:user_id]`

**Email Handling:**
- Development: Uses `letter_opener` gem - emails open in browser automatically
- Production: AWS SES via `aws-sdk-ses` gem
- Magic links expire after 15 minutes

**Test Authentication Bypass:**
- `TestSessionsController` provides `/test_login` endpoint (dev/test only)
- Playwright tests use this to bypass magic link email flow
- See `tests/helpers/test-utils.js` → `loginUser()` function

### Booking Flow

The booking process involves multiple steps across several controllers:

1. **Service Selection** (`ServicesController`)
   - User browses `/services`
   - Views service details at `/services/:id`
   - Clicks "Book This Service"

2. **Time Selection** (`BookingsController#new`)
   - Calendar widget shows available dates
   - AJAX call to `/services/:id/availability` fetches time slots
   - User selects date + time → `POST /bookings/select_time`
   - Stores selection in `session[:pending_booking]`

3. **Review** (`BookingsController#review`)
   - Shows booking summary from session
   - **If guest**: Shows email/name/phone form
   - **If authenticated**: Shows user info from session

4. **Guest Booking Path** (`BookingsController#create_guest_booking`)
   - Creates/finds User by email
   - Generates magic link token
   - Sends magic link email
   - Stores booking details in session
   - Redirects to login page
   - After magic link authentication → continues to payment

5. **Authenticated User Path** (`BookingsController#create`)
   - Creates booking record immediately
   - Redirects to payment page

6. **Payment** (`PaymentsController`)
   - Shows Stripe payment form at `/bookings/:id/payment`
   - Uses Stripe.js for secure card input
   - Webhook at `/webhooks/stripe` handles payment confirmation

### Key Models & Relationships

```
User
├── has_many :bookings
├── has_many :audit_logs
└── Attributes: email (unique), name, phone, admin (boolean), magic_link_token, magic_link_expires_at

Service
├── has_many :bookings
├── has_many :availability_schedules
├── has_many :blocked_dates
└── Attributes: name, description, duration_minutes, price, color, active, min_advance_hours

Booking
├── belongs_to :user
├── belongs_to :service
├── has_many :payments
└── Attributes: start_time, end_time, status (pending/confirmed/cancelled/completed), notes

Payment
├── belongs_to :booking
└── Attributes: amount, stripe_payment_intent_id, status (pending/succeeded/failed)

AvailabilitySchedule
├── belongs_to :service
└── Defines weekly recurring availability (e.g., "Mondays 9am-5pm")

BlockedDate
├── belongs_to :service
└── Defines specific unavailable dates (holidays, time off)
```

### Session Management

Sessions are critical for the booking flow:

```ruby
# Pending booking stored across multiple requests
session[:pending_booking] = {
  'service_id' => service.id,
  'start_time' => selected_time,
  'end_time' => end_time,
  'notes' => notes,
  'guest_email' => email,    # For guest bookings
  'guest_name' => name,       # For guest bookings
  'guest_phone' => phone      # For guest bookings
}

# User authentication
session[:user_id] = user.id

# Return path after magic link
session[:return_to] = confirm_booking_path
```

### Payment Integration (Stripe v17.2.0)

**Configuration:**
- Initialized in `config/initializers/stripe.rb`
- API keys loaded from ENV variables: `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`

**Payment Flow:**
1. Booking created with `payment_status: 'pending'`
2. Payment page loads Stripe.js
3. User enters card details (handled entirely by Stripe - PCI compliant)
4. Frontend calls Stripe API to create PaymentIntent
5. Stripe redirects/confirms
6. Webhook receives event → updates booking status

**Webhook Handling:**
- Endpoint: `POST /webhooks/stripe`
- Verifies signature using `STRIPE_WEBHOOK_SECRET`
- Updates Payment and Booking records based on event type

### Admin System

Admin routes namespaced under `/admin`:
- Dashboard: Overview of bookings, revenue
- Authentication: `Admin::BaseController` checks `current_user.admin?`
- Authorization: Uses before_action filter

### CSS/Styling

- **Tailwind CSS 2.0**: Utility-first CSS framework
- **Build process**: Rails asset pipeline with `tailwindcss-rails` gem
- **Development**: Run `bin/rails tailwindcss:watch` for auto-rebuild
- **Custom components**: Defined in `app/assets/stylesheets/`

### Background Jobs (Sidekiq)

Jobs are used for:
- Sending emails asynchronously
- Processing recurring tasks
- Cleanup tasks

```ruby
# Example job
class SendBookingConfirmationJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find(booking_id)
    BookingMailer.confirmation(booking).deliver_now
  end
end
```

## Testing Strategy

### Playwright E2E Tests
Located in `tests/e2e/`:
- Tests run against real Rails server (auto-started by Playwright config)
- Chromium browser used for consistency
- **Session isolation**: Each test calls `context.clearCookies()` in `beforeEach`
- **Test data cleanup**: `tests/global-setup.js` removes test users before run

**Test Helpers** (`tests/helpers/test-utils.js`):
- `loginUser(page, email, name)`: Authenticates user via test endpoint
- `completeBookingToPayment(page)`: Full booking flow up to payment page
- `STRIPE_TEST_CARDS`: Object with test card numbers

**Important**: Tests use `/test_login` endpoint which bypasses magic link email flow. This endpoint only exists in development/test environments.

### Database in Tests
- Tests use development database (not a separate test database)
- Global setup script cleans test user data before each run
- Use unique email addresses: `payment-test-${counter}-${timestamp}@example.com`

## Environment Variables (.env)

Required for full functionality:
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost/booking_platform_dev

# Stripe (use test keys for development)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# AWS SES (for production emails)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# Redis (for Sidekiq)
REDIS_URL=redis://localhost:6379/0

# Rails
RAILS_MASTER_KEY=... (from config/master.key)
```

## Common Gotchas

1. **Tailwind not updating**: Run `bin/rails tailwindcss:build` or ensure `tailwindcss:watch` is running

2. **Magic link emails not received**: Check letter_opener in development - emails open in browser automatically. Look for browser window opening when email is sent.

3. **Session data lost**: Sessions are cookie-based. In tests, ensure cookies aren't cleared between steps that depend on session data.

4. **Booking flow stuck**: Check `session[:pending_booking]` in Rails console or logs. The booking flow stores state across multiple requests.

5. **Stripe webhook failures**: Ensure webhook secret is correct and endpoint is publicly accessible (use ngrok for local testing).

6. **Test failures with duplicate emails**: Tests use timestamp-based unique emails. If tests are interrupted, run global setup to clean test data: `node tests/global-setup.js`

7. **Routes helper returning `/` instead of expected path**: Use string paths (e.g., `'/services'`) instead of path helpers in redirects within test-only controllers.

## Development Workflow

1. Start services:
   ```bash
   # Terminal 1: Rails server
   bin/rails server

   # Terminal 2: Tailwind watcher (optional, for CSS changes)
   bin/rails tailwindcss:watch
   ```

2. Make code changes

3. Test changes:
   ```bash
   # Run relevant E2E tests
   npm test

   # Or test in browser
   open http://localhost:3000
   ```

4. Database changes:
   ```bash
   bin/rails generate migration DescriptiveNameOfChange
   # Edit migration file
   bin/rails db:migrate
   ```

## Deployment Notes

- Database: PostgreSQL 14+
- Required addons: Redis (for Sidekiq)
- Set all environment variables before deployment
- Run `bin/rails db:migrate` after deploy
- Ensure Stripe webhook endpoint is configured in Stripe dashboard
