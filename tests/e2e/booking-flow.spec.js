const { test, expect } = require('@playwright/test');
const { loginUser } = require('../helpers/test-utils');

// Counter for unique emails
let emailCounter = 0;

// Clear cookies and session before each test
test.beforeEach(async ({ context }) => {
  await context.clearCookies();
  emailCounter++;
});

test.describe('Booking Flow', () => {
  test('should complete full booking flow as signed-in user', async ({ page }) => {
    // Login first
    const testEmail = `booking-test-${emailCounter}-${Date.now()}@example.com`;
    await loginUser(page, testEmail, 'Booking Tester');

    // Verify we're logged in (check for Sign Out link or similar)
    await page.goto('/services');
    await expect(page).toHaveTitle(/Booking Platform/i);

    // Debug: Take a screenshot to see the state
    console.log('Current URL after login:', page.url());

    // Click on first service
    await page.click('a[href*="/services/"]');

    // Click "Book This Service" button
    await page.click('text=Book This Service');

    // Wait for calendar grid to load
    await page.waitForSelector('#calendar-grid', { timeout: 5000 });

    // Select a date (click on first available date button)
    const availableDates = await page.locator('button[data-date]:not(:disabled)').all();
    if (availableDates.length > 0) {
      await availableDates[0].click();

      // Wait a moment for time slots to load
      await page.waitForTimeout(500);
    }

    // Wait for time slots to appear
    await page.waitForSelector('.time-slot', { timeout: 5000 });

    // Select first available time slot and wait for form
    const timeSlot = page.locator('.time-slot').first();
    await timeSlot.click();

    // Wait for the form to become visible (the hidden class should be removed)
    await page.waitForSelector('#booking-form', { state: 'visible', timeout: 10000 });

    // Wait a bit for any animations
    await page.waitForTimeout(500);

    // Click "Review Booking" button - use input type submit selector
    await page.click('input[type="submit"][value="Review Booking"]');


    // Should redirect to review page
    await expect(page).toHaveURL(/\/bookings\/review/);

    // Wait for the page to fully load
    await page.waitForLoadState('networkidle');

    // As signed-in user, wait for and click confirm button
    await page.waitForSelector('input[type="submit"][value="Confirm & Pay"]', { timeout: 10000 });
    await page.click('input[type="submit"][value="Confirm & Pay"]');

    // Should redirect to payment page
    await expect(page).toHaveURL(/\/bookings\/\d+\/payment/);
  });

  test('should display service details correctly', async ({ page }) => {
    await page.goto('/services');

    // Click first service
    await page.click('a[href*="/services/"]');

    // Check service details are displayed (use first() to get single element)
    await expect(page.locator('h1').first()).toContainText(/.+/);
    await expect(page.locator('text=About this service')).toBeVisible();
  });

  test('should show available time slots', async ({ page }) => {
    await page.goto('/services');
    await page.click('a[href*="/services/"]');

    // Click "Book This Service" button
    await page.click('text=Book This Service');

    // Wait for calendar grid
    await page.waitForSelector('#calendar-grid', { timeout: 5000 });

    // Check that there are available dates
    const availableDates = await page.locator('button[data-date]:not(:disabled)').count();
    expect(availableDates).toBeGreaterThan(0);
  });
});

test.describe('Authenticated Booking Flow', () => {
  test('should allow authenticated user to complete booking', async ({ page }) => {
    // Login first
    const testEmail = `auth-booking-test-${emailCounter}-${Date.now()}@example.com`;
    await loginUser(page, testEmail, 'Auth Booking Tester');

    await page.goto('/services');

    // Select service
    await page.click('a[href*="/services/"]');

    // Click "Book This Service" button
    await page.click('text=Book This Service');

    // Wait for calendar grid
    await page.waitForSelector('#calendar-grid', { timeout: 5000 });

    // Select date
    const availableDates = await page.locator('button[data-date]:not(:disabled)').all();
    if (availableDates.length > 0) {
      await availableDates[0].click();
      await page.waitForTimeout(500);
    }

    // Select time slot
    await page.waitForSelector('.time-slot', { timeout: 5000 });

    const timeSlot = page.locator('.time-slot').first();
    await timeSlot.click();

    // Wait for the form to become visible
    await page.waitForSelector('#booking-form', { state: 'visible', timeout: 10000 });

    // Wait a bit for any animations
    await page.waitForTimeout(500);

    // Click "Review Booking" submit button
    await page.click('input[type="submit"][value="Review Booking"]');

    // Should be on review page
    await expect(page).toHaveURL(/\/bookings\/review/);

    // Wait for the page to fully load
    await page.waitForLoadState('networkidle');

    // As authenticated user, wait for and click Confirm & Pay
    await page.waitForSelector('input[type="submit"][value="Confirm & Pay"]', { timeout: 10000 });
    await page.click('input[type="submit"][value="Confirm & Pay"]');

    // Should redirect to payment page
    await expect(page).toHaveURL(/\/bookings\/\d+\/payment/);
  });
});

test.describe('Navigation', () => {
  test('should navigate through main pages', async ({ page }) => {
    // Home page
    await page.goto('/');

    // Services page
    await page.goto('/services');
    await expect(page.locator('h1, h2')).toContainText(/services/i);
  });
});
