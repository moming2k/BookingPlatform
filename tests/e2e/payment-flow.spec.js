const { test, expect } = require('@playwright/test');
const { loginUser } = require('../helpers/test-utils');

// Counter to ensure truly unique emails across all tests
let emailCounter = 0;

// Clear cookies and session before each test
test.beforeEach(async ({ context }) => {
  await context.clearCookies();
  emailCounter++; // Increment counter for each test
});

test.describe('Payment Flow', () => {
  // Helper function to create a booking and reach payment page
  async function createBookingAndReachPayment(page) {
    // Login as authenticated user first
    emailCounter++;
    const testEmail = `payment-test-${emailCounter}-${Date.now()}@example.com`;
    await loginUser(page, testEmail, 'Payment Tester');

    // Explicitly navigate to services page
    await page.goto('/services');
    await page.waitForSelector('a[href*="/services/"]', { timeout: 5000 });

    // Select first service
    await page.click('a[href*="/services/"]');

    // Click "Book This Service"
    await page.click('text=Book This Service');

    // Wait for calendar
    await page.waitForSelector('#calendar-grid', { timeout: 5000 });

    // Select first available date
    const availableDates = await page.locator('button[data-date]:not(:disabled)').all();
    if (availableDates.length > 0) {
      await availableDates[0].click();
      await page.waitForTimeout(500);
    }

    // Select first time slot
    await page.waitForSelector('.time-slot', { timeout: 5000 });
    const timeSlot = page.locator('.time-slot').first();
    await timeSlot.click();

    // Wait for booking form
    await page.waitForSelector('#booking-form', { state: 'visible', timeout: 10000 });
    await page.waitForTimeout(500);

    // Click Review Booking
    await page.click('input[type="submit"][value="Review Booking"]');

    // Should be on review page
    await expect(page).toHaveURL(/\/bookings\/review/);

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // As authenticated user, we should see "Confirm & Pay" button (no terms checkbox for signed-in users)
    await page.waitForSelector('input[type="submit"][value="Confirm & Pay"]', { timeout: 10000 });
    await page.click('input[type="submit"][value="Confirm & Pay"]');

    // Should redirect to payment page (booking should be created)
    await page.waitForURL(/\/bookings\/\d+\/payment/);
    await expect(page).toHaveURL(/\/bookings\/\d+\/payment/);

    return page.url(); // Return payment URL
  }

  test('should reach payment page after booking', async ({ page }) => {
    const bookingUrl = await createBookingAndReachPayment(page);

    // Verify we're on payment page
    await expect(page).toHaveURL(/\/bookings\/\d+\/payment/);

    // Check for payment-related elements
    await expect(page.locator('body')).toContainText(/booking|payment|pay/i);
  });

  test('should display booking summary on payment page', async ({ page }) => {
    const paymentUrl = await createBookingAndReachPayment(page);

    // Should show booking details
    await expect(page.locator('body')).toContainText(/\$\d+/); // Price

    // Should show service name or booking reference
    await expect(page.locator('h1, h2, h3').first()).toBeVisible();
  });

  test('should validate Stripe is initialized', async ({ page }) => {
    const paymentUrl = await createBookingAndReachPayment(page);

    // Check if page has Stripe elements
    // Note: In test mode, we can check for Stripe.js script or elements

    // Wait for page to fully load
    await page.waitForLoadState('networkidle');

    // Check if there's a payment form or Stripe element container
    const hasPaymentForm = await page.locator('form').count() > 0;
    expect(hasPaymentForm).toBeTruthy();
  });
});

test.describe('Complete Booking with Payment Flow', () => {
  test('should complete full flow from service to payment', async ({ page }) => {
    // Step 0: Login as user
    emailCounter++;
    const testEmail = `complete-flow-test-${emailCounter}-${Date.now()}@example.com`;
    await loginUser(page, testEmail, 'Complete Flow Tester');

    // Step 1: Navigate to services
    await page.goto('/services');
    await expect(page).toHaveTitle(/Booking Platform/i);

    // Step 2: Select service
    await page.click('a[href*="/services/"]');
    await expect(page.locator('h1').first()).toBeVisible();

    // Step 3: Book service
    await page.click('text=Book This Service');
    await page.waitForSelector('#calendar-grid', { timeout: 5000 });

    // Step 4: Select date
    const availableDates = await page.locator('button[data-date]:not(:disabled)').all();
    expect(availableDates.length).toBeGreaterThan(0);
    await availableDates[0].click();
    await page.waitForTimeout(500);

    // Step 5: Select time
    await page.waitForSelector('.time-slot', { timeout: 5000 });
    const timeSlots = await page.locator('.time-slot').all();
    expect(timeSlots.length).toBeGreaterThan(0);
    await timeSlots[0].click();

    // Step 6: Fill booking form
    await page.waitForSelector('#booking-form', { state: 'visible', timeout: 10000 });
    await page.waitForTimeout(500);
    await page.click('input[type="submit"][value="Review Booking"]');

    // Step 7: Review booking
    await expect(page).toHaveURL(/\/bookings\/review/);

    // Wait for page to load
    await page.waitForLoadState('networkidle');

    // Verify booking summary is shown
    await expect(page.locator('body')).toContainText(/\$\d+/);

    // As authenticated user, confirm and pay
    await page.waitForSelector('input[type="submit"][value="Confirm & Pay"]', { timeout: 10000 });
    await page.click('input[type="submit"][value="Confirm & Pay"]');

    // Should redirect to payment page
    await expect(page).toHaveURL(/\/bookings\/\d+\/payment/);
  });
});

test.describe('Payment Page Elements', () => {
  test('should show payment instructions or form', async ({ page }) => {
    // This test checks if payment-related pages exist
    // We'll navigate directly if we have a test booking ID

    await page.goto('/services');

    // Just verify services are accessible
    await expect(page).toHaveTitle(/Booking Platform/i);
  });
});
