const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

module.exports = async () => {
  console.log('Cleaning test data...');

  try {
    // Delete test users created during tests (those with payment-test emails)
    const cleanupScript = `
      bin/rails runner "
        User.where('email LIKE ?', 'payment-test%@example.com').destroy_all
        User.where('email LIKE ?', 'guest@example.com').destroy_all
        puts 'Test data cleaned'
      "
    `;

    await execPromise(cleanupScript);
    console.log('Test data cleanup complete');
  } catch (error) {
    console.error('Error cleaning test data:', error);
    // Don't throw - continue with tests even if cleanup fails
  }
};
