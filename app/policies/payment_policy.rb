class PaymentPolicy < ApplicationPolicy
  def show?
    user_owns_payment?
  end

  def create?
    user_owns_payment?
  end

  def update?
    user_owns_payment?
  end

  def process?
    user_owns_payment? && record.pending?
  end

  def refund?
    user_owns_payment? && record.succeeded?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def user_owns_payment?
    record.user_id == user.id
  end
end
