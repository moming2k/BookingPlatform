class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(user_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def bookings
    @user = current_user
    @bookings = @user.bookings
                     .includes(:service, :payment)
                     .order(start_time: :desc)
                     .page(params[:page])
                     .per(20)
  end

  def payments
    @user = current_user
    @payments = Payment.where(user: @user)
                       .includes(:booking)
                       .order(created_at: :desc)
                       .page(params[:page])
                       .per(20)
  end

  def update_preferences
    @user = current_user

    if @user.update(preferences: preferences_params)
      redirect_to profile_path, notice: "Preferences updated successfully."
    else
      redirect_to profile_path, alert: "Failed to update preferences."
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :phone)
  end

  def preferences_params
    params.require(:preferences).permit(
      :send_booking_reminders,
      :send_completion_emails,
      :send_marketing_emails,
      :timezone
    )
  end
end
