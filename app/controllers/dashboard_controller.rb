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
      next_due_date: next_payment_due_date,
      next_payment_amount: next_payment_amount
    }

    # Get the most urgent loan for payment actions
    @priority_loan = most_urgent_loan
  end

  private

  def calculate_on_time_payments
    total_payments = @user.payments.completed.count
    return 0 if total_payments.zero? # Neutral score for new users with no payment history

    on_time = @user.payments.completed
                   .joins(:loan)
                   .where("payments.paid_at <= loans.due_date")
                   .count

    ((on_time.to_f / total_payments) * 100).round
  end

  def next_payment_due_date
    @active_loans.minimum(:due_date)
  end

  def next_payment_amount
    next_loan = @active_loans.where("due_date IS NOT NULL").order(:due_date).first
    return 0 unless next_loan

    # Calculate monthly payment amount (simplified calculation)
    # In a real app, this would be based on loan amortization schedule
    (next_loan.remaining_balance / next_loan.term_months).round
  end

  def most_urgent_loan
    # Prioritize loans by: overdue -> due soon -> highest interest rate
    @active_loans.order(
      Arel.sql("CASE
        WHEN due_date < CURRENT_DATE THEN 1
        WHEN due_date <= CURRENT_DATE + INTERVAL '7 days' THEN 2
        ELSE 3
      END"),
      "interest_rate DESC",
      :due_date
    ).first
  end
end
