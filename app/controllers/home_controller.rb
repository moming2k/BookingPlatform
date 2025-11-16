class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @services = Service.active.ordered.limit(6) if defined?(Service)
  end
end