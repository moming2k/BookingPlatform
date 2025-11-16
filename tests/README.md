# Automated UI Testing with Playwright

This project uses Playwright for automated end-to-end UI testing.

## Setup

Playwright and Chromium browser are already installed. The Rails server will automatically start when running tests.

## Running Tests

### Run all tests (headless)
```bash
npm test
```

### Run tests with browser visible
```bash
npm run test:headed
```

### Run tests with interactive UI mode
```bash
npm run test:ui
```

### Debug tests step-by-step
```bash
npm run test:debug
```

### View last test report
```bash
npm run test:report
```

## Test Structure

- `tests/e2e/` - End-to-end test files
- `tests/helpers/` - Shared test utilities and helpers
- `test-results/` - Test reports and artifacts (screenshots, videos)

## Available Tests

### Booking Flow Tests (`booking-flow.spec.js`)
- **Full booking flow as signed-in user** - Tests the complete booking process from service selection to payment
- **Service details display** - Verifies service information is shown correctly
- **Available time slots** - Checks that time slots are available and selectable

### Guest Booking Tests (`booking-flow.spec.js`)
- **Guest booking with email** - Tests guest users can select time and enter contact details
- **Magic link email flow** - Verifies guest users receive magic link for authentication

### Payment Flow Tests (`payment-flow.spec.js`)
- **Reach payment page** - Verifies booking flow successfully reaches payment page
- **Display booking summary** - Checks payment page shows booking details and pricing
- **Stripe initialization** - Validates Stripe payment system is loaded
- **Complete flow to payment** - Full end-to-end test from service selection to payment page

### Navigation Tests (`booking-flow.spec.js`)
- **Main page navigation** - Tests routing between main pages

## Writing New Tests

Create new test files in `tests/e2e/` with the `.spec.js` extension:

```javascript
const { test, expect } = require('@playwright/test');
const { selectServiceAndTime } = require('../helpers/test-utils');

test('my test', async ({ page }) => {
  await page.goto('/services');
  // Your test code here
});
```

## Test Utilities

Helper functions are available in `tests/helpers/test-utils.js`:

- `selectServiceAndTime(page, serviceIndex, dateIndex, timeIndex)` - Automates service and time selection
- `fillGuestForm(page, email, name, phone)` - Fills in guest booking form
- `completeBookingToPayment(page, email, name)` - Complete full booking flow to payment page
- `waitForURL(page, pattern)` - Waits for URL to match pattern
- `takeScreenshot(page, name)` - Captures screenshot with timestamp
- `STRIPE_TEST_CARDS` - Stripe test card numbers object:
  - `STRIPE_TEST_CARDS.success` - Successful payment (4242 4242 4242 4242)
  - `STRIPE_TEST_CARDS.declined` - Declined card
  - `STRIPE_TEST_CARDS.requiresAuthentication` - Requires 3D Secure
  - `STRIPE_TEST_CARDS.insufficientFunds` - Insufficient funds error

## Continuous Integration

Tests are configured to run with retries in CI environments. Set the `CI=true` environment variable to enable CI mode.

## Troubleshooting

### Server won't start
Make sure no other Rails server is running on port 3000:
```bash
lsof -ti:3000 | xargs kill -9
```

### Tests timeout
Increase timeout in individual tests:
```javascript
test('slow test', async ({ page }) => {
  test.setTimeout(60000); // 60 seconds
  // test code
});
```

### Browser crashes
Clear Playwright cache and reinstall browsers:
```bash
npx playwright install --force
```
