# Test-only controller for automated testing
# This bypasses the magic link authentication for E2E tests
class TestSessionsController < ApplicationController
  # Only allow in development environment
  before_action :ensure_development_environment
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def create
    email = params[:email]
    name = params[:name] || 'Test User'

    # Find or create the test user
    user = User.find_or_create_by!(email: email) do |u|
      u.name = name
    end

    # Update name if user already exists
    user.update!(name: name) if user.name != name

    # Sign in the user by setting the session
    session[:user_id] = user.id

    # Also set it in cookies as a backup (encrypted)
    cookies.encrypted[:user_id] = {
      value: user.id,
      expires: 1.day.from_now
    }

    # Log for debugging
    Rails.logger.info "Test login: User #{user.id} (#{user.email}) logged in"

    # Check for return_to path, otherwise redirect to services page
    return_path = session.delete(:return_to) || '/services'
    Rails.logger.info "Test login: Redirecting to #{return_path}"
    redirect_to return_path, notice: "Test login successful"
  end

  private

  def ensure_development_environment
    unless Rails.env.development? || Rails.env.test?
      raise ActionController::RoutingError, 'Not Found'
    end
  end
end
