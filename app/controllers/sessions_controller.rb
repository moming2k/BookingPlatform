class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :magic_link]
  before_action :redirect_if_authenticated, only: [:new, :create], unless: :admin_area?

  def new
    # Show login form
  end

  def create
    email = params[:email]&.downcase&.strip

    if email.present? && valid_email?(email)
      # Handle soft-deleted users (acts_as_paranoid)
      # Use find_or_initialize_by with with_deleted scope to handle all cases
      user = User.with_deleted.where(email: email).first_or_initialize do |u|
        u.name = params[:name] if params[:name].present?
      end

      # If user was soft-deleted, restore them
      if user.persisted? && user.deleted?
        user.restore
        user.update(name: params[:name]) if params[:name].present?
      end

      # Save if new record
      unless user.persisted?
        unless user.save
          flash.now[:alert] = "There was an error: #{user.errors.full_messages.join(', ')}"
          render :new
          return
        end
      end

      # Generate and send magic link
      user.generate_magic_link!
      MagicLinkMailer.send_magic_link(user).deliver_later

      redirect_to login_path, notice: "Check your email for a magic link to sign in."
    else
      flash.now[:alert] = "Please enter a valid email address."
      render :new
    end
  end

  def magic_link
    token = params[:token]
    user = User.find_by(magic_link_token: token)

    if user && user.magic_link_valid?
      user.confirm_magic_link!
      sign_in(user)

      # Check if there's a pending booking or return path
      return_path = session.delete(:return_to)

      if return_path.present?
        redirect_to return_path, notice: "Successfully signed in!"
      elsif user.admin?
        redirect_to admin_dashboard_path, notice: "Welcome back!"
      else
        redirect_to bookings_path, notice: "Successfully signed in!"
      end
    else
      redirect_to login_path, alert: "This magic link is invalid or has expired. Please request a new one."
    end
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Successfully signed out."
  end

  private

  def valid_email?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def redirect_if_authenticated
    if current_user
      if current_user.admin? && admin_area?
        redirect_to admin_dashboard_path
      else
        redirect_to bookings_path
      end
    end
  end

  def admin_area?
    request.path.start_with?("/admin")
  end

  def sign_in(user)
    session[:user_id] = user.id
    cookies.encrypted[:user_id] = { value: user.id, expires: 30.days.from_now }
    @current_user = user
  end

  def sign_out
    session.delete(:user_id)
    cookies.delete(:user_id)
    @current_user = nil
  end
end