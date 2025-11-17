class BookingPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user_owns_booking?
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    user_owns_booking?
  end

  def edit?
    update?
  end

  def destroy?
    user_owns_booking?
  end

  def cancel?
    user_owns_booking? && record.can_be_cancelled?
  end

  def confirm?
    user_owns_booking?
  end

  def check_payment_status?
    user_owns_booking?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def user_owns_booking?
    record.user_id == user.id
  end
end
