const { expect } = require('@playwright/test');

/**
 * Helper function to log in a test user by creating a session directly
 * This bypasses the magic link email flow for automated testing
 */
async function loginUser(page, email = 'test@example.com', name = 'Test User') {
  // Navigate to the test login endpoint with user params
  // This will create the user, set the session, and redirect
  await page.goto(`/test_login?email=${encodeURIComponent(email)}&name=${encodeURIComponent(name)}`);

  // Wait for navigation to complete (could be /services or other return_to path)
  await page.waitForLoadState('domcontentloaded');
  await page.waitForLoadState('networkidle');

  // Give it a moment for the session to be fully established
  await page.waitForTimeout(1000);

  // Capture screenshot to see what's on screen
  const currentUrl = page.url();
  console.log(`After login, current URL: ${currentUrl}`);

  // Take a screenshot for debugging
  await page.screenshot({ path: `test-results/login-debug-${Date.now()}.png`, fullPage: true });

  // Check for error messages on the page
  const bodyText = await page.locator('body').textContent();
  if (bodyText.includes('not found') || bodyText.includes('404')) {
    console.error(`ERROR: Page shows "not found" message`);
    console.error(`Page content: ${bodyText.substring(0, 500)}`);
    throw new Error(`Login redirected to error page. Current URL: ${currentUrl}`);
  }

  // Verify we're logged in by checking for the "My Bookings" link
  // This link only shows when a user is authenticated
  try {
    await page.waitForSelector('text=My Bookings', { timeout: 5000 });
    console.log(`✓ User logged in successfully: ${email}`);
  } catch (error) {
    console.error(`✗ Login verification failed for ${email}. Current URL: ${currentUrl}`);
    // Check if we see "Sign In" button instead (means not logged in)
    const hasSignIn = await page.locator('text=Sign In').isVisible().catch(() => false);
    if (hasSignIn) {
      throw new Error(`Login failed - Still seeing "Sign In" button. User is not authenticated.`);
    }
    throw new Error(`Login failed - "My Bookings" link not found. User may not be authenticated or on wrong page.`);
  }
}

/**
 * Helper to select a service and time slot
 */
async function selectServiceAndTime(page, serviceIndex = 0, dateIndex = 0, timeIndex = 0) {
  // Go to services
  await page.goto('/services');

  // Click on service
  const serviceLinks = await page.locator('a[href*="/services/"]').all();
  if (serviceLinks.length > serviceIndex) {
    await serviceLinks[serviceIndex].click();
  }

  // Wait for calendar
  await page.waitForSelector('.calendar, [data-calendar]', { timeout: 5000 });

  // Select date
  const availableDates = await page.locator('.available-date, [data-available="true"]').all();
  if (availableDates.length > dateIndex) {
    await availableDates[dateIndex].click();
  }

  // Wait for time slots
  await page.waitForSelector('.time-slot, [data-time-slot]', { timeout: 5000 });

  // Select time
  const timeSlots = await page.locator('.time-slot, [data-time-slot]').all();
  if (timeSlots.length > timeIndex) {
    await timeSlots[timeIndex].click();
  }
}

/**
 * Helper to fill guest booking form
 */
async function fillGuestForm(page, email = 'guest@example.com', name = 'Test Guest', phone = '1234567890') {
  if (await page.locator('input[type="email"]').isVisible()) {
    await page.fill('input[type="email"]', email);

    if (await page.locator('input[name="name"]').isVisible()) {
      await page.fill('input[name="name"]', name);
    }

    if (await page.locator('input[name="phone"], input[type="tel"]').isVisible()) {
      await page.fill('input[name="phone"], input[type="tel"]', phone);
    }
  }
}

/**
 * Helper to wait for navigation
 */
async function waitForURL(page, pattern, timeout = 5000) {
  await page.waitForURL(pattern, { timeout });
}

/**
 * Helper to take screenshot with timestamp
 */
async function takeScreenshot(page, name) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  await page.screenshot({
    path: `test-results/screenshots/${name}-${timestamp}.png`,
    fullPage: true
  });
}

/**
 * Helper to complete booking flow up to payment page
 */
async function completeBookingToPayment(page, userEmail = 'test@example.com', userName = 'Test User') {
  // Navigate to services
  await page.goto('/services');

  // Click first service
  const serviceLinks = await page.locator('a[href*="/services/"]').all();
  if (serviceLinks.length > 0) {
    await serviceLinks[0].click();
  }

  // Click Book This Service
  await page.click('text=Book This Service');

  // Wait for calendar
  await page.waitForSelector('#calendar-grid', { timeout: 5000 });

  // Select date
  const availableDates = await page.locator('button[data-date]:not(:disabled)').all();
  if (availableDates.length > 0) {
    await availableDates[0].click();
    await page.waitForTimeout(500);
  }

  // Select time
  await page.waitForSelector('.time-slot', { timeout: 5000 });
  const timeSlot = page.locator('.time-slot').first();
  await timeSlot.click();

  // Wait for form
  await page.waitForSelector('#booking-form', { state: 'visible', timeout: 10000 });
  await page.waitForTimeout(500);

  // Click Review Booking
  await page.click('input[type="submit"][value="Review Booking"]');

  // Fill guest form if visible
  if (await page.locator('input[type="email"]').isVisible()) {
    await page.fill('input[type="email"]', userEmail);
    await page.fill('input[name="name"]', userName);
    await page.check('input[type="checkbox"][name="accept_terms"]');
    await page.click('input[type="submit"][value="Continue to Payment"]');
    return 'magic_link'; // Returns magic link flow
  } else {
    // For signed-in users, no terms checkbox - just click Confirm & Pay
    await page.click('input[type="submit"][value="Confirm & Pay"]');
    return 'payment_page'; // Returns payment page flow
  }
}

/**
 * Stripe test card numbers
 */
const STRIPE_TEST_CARDS = {
  success: '4242424242424242',
  declined: '4000000000000002',
  requiresAuthentication: '4000002500003155',
  insufficientFunds: '4000000000009995',
};

module.exports = {
  loginUser,
  selectServiceAndTime,
  fillGuestForm,
  waitForURL,
  takeScreenshot,
  completeBookingToPayment,
  STRIPE_TEST_CARDS,
};
