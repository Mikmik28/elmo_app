class DashboardController < ApplicationController
  def index
    @user = current_user
    @active_loans = @user.active_loans.includes(:payments)
    @recent_payments = @user.payments.completed.order(paid_at: :desc).limit(5)
    @credit_score = @user.credit_score
    @available_credit = @user.eligible_loan_amount
    @total_outstanding = @user.total_outstanding

    # Statistics for dashboard
    @stats = {
      total_borrowed: @user.total_borrowed,
      loans_count: @user.loans.count,
      on_time_payments: calculate_on_time_payments,
      next_due_date: next_payment_due_date
    }
  end

  private

  def calculate_on_time_payments
    total_payments = @user.payments.completed.count
    return 95 if total_payments.zero? # Default good score for new users
    
    on_time = @user.payments.completed
                   .joins(:loan)
                   .where('payments.paid_at <= loans.due_date')
                   .count
    
    ((on_time.to_f / total_payments) * 100).round
  end

  def next_payment_due_date
    @active_loans.minimum(:due_date)
  end
end
