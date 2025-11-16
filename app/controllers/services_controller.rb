class ServicesController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @services = Service.active.ordered
  end

  def show
    @service = Service.friendly.find(params[:id])
  end

  def availability
    @service = Service.find(params[:id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @available_slots = @service.available_slots(date)

    respond_to do |format|
      format.json { render json: @available_slots }
      format.html
    end
  rescue ArgumentError
    respond_to do |format|
      format.json { render json: { error: "Invalid date format" }, status: :unprocessable_entity }
      format.html { redirect_to @service, alert: "Invalid date format" }
    end
  end

  def calendar
    @service = Service.find(params[:id])
    @month = params[:month].present? ? Date.parse(params[:month]) : Date.current
    @available_days = calculate_available_days(@service, @month)

    respond_to do |format|
      format.html
      format.json { render json: @available_days }
    end
  end

  private

  def calculate_available_days(service, month)
    start_date = month.beginning_of_month
    end_date = month.end_of_month
    available_days = []

    (start_date..end_date).each do |date|
      if service.available_on?(date) && service.available_slots(date).any?
        available_days << date.day
      end
    end

    available_days
  end
end