class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def about
  end

  def contact
  end

  def pricing
    @services = Service.active.ordered if defined?(Service)
  end

  def terms
  end

  def privacy
  end
end