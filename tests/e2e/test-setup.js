const { test } = require('@playwright/test');

// Clear browser context before each test to ensure session isolation
test.beforeEach(async ({ context }) => {
  // Clear all cookies and storage
  await context.clearCookies();
  await context.clearPermissions();
});

// Export configured test
module.exports = { test };
