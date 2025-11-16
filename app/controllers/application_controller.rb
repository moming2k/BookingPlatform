class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :set_time_zone
  before_action :track_activity

  helper_method :current_user, :user_signed_in?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound do |exception|
    not_found(exception)
  end

  private

  def current_user
    @current_user ||= begin
      if session[:user_id].present?
        User.find_by(id: session[:user_id])
      elsif cookies.encrypted[:user_id].present?
        User.find_by(id: cookies.encrypted[:user_id])
      end
    end
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      session[:return_to] = request.fullpath if request.get?
      redirect_to login_path, alert: "Please sign in to continue."
    end
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def set_time_zone
    Time.zone = current_user.time_zone if current_user&.time_zone.present?
  end

  def track_activity
    return unless current_user

    # Update last activity timestamp
    current_user.touch(:last_login_at) if current_user.last_login_at.nil? || current_user.last_login_at < 1.hour.ago
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def not_found(exception = nil)
    if Rails.env.development?
      # Detailed error message for development
      details = []
      details << "Path: #{request.method} #{request.fullpath}"
      details << "Exception: #{exception.message}" if exception
      details << "Params: #{params.inspect}" if params.present?

      flash[:alert] = "Resource not found. #{details.join(' | ')}"
      Rails.logger.debug "=== RecordNotFound Exception ==="
      Rails.logger.debug "Path: #{request.method} #{request.fullpath}"
      Rails.logger.debug "Exception: #{exception.inspect}"
      Rails.logger.debug "Params: #{params.inspect}"
      Rails.logger.debug "=== End RecordNotFound ==="
    else
      # Simple message for production
      flash[:alert] = "The requested resource was not found."
    end

    redirect_back(fallback_location: root_path)
  end

  def after_sign_in_path_for(user)
    session.delete(:return_to) || (user.admin? ? admin_dashboard_path : bookings_path)
  end

  # Audit logging helper
  def log_activity(action, auditable = nil, metadata = {})
    AuditLog.create!(
      user: current_user,
      action: action,
      auditable: auditable,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: metadata
    )
  end

  # Pagination helper
  def page_params
    params.permit(:page, :per_page)
  end

  def per_page
    [(params[:per_page] || 25).to_i, 100].min
  end

  # JSON response helpers
  def render_json_success(data = {}, message = nil, status = :ok)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data
    render json: response, status: status
  end

  def render_json_error(message, errors = nil, status = :unprocessable_entity)
    response = { success: false, message: message }
    response[:errors] = errors if errors
    render json: response, status: status
  end
end