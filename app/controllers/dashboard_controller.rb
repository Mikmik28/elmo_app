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
      next_payment_amount: next_payment_amount,
      credit_score_change: calculate_credit_score_change
    }

    # Get the most urgent loan for payment actions
    @priority_loan = most_urgent_loan
  end

  private

  def calculate_on_time_payments
    total_payments = @user.payments.completed.count
    return 100 if total_payments.zero? # Neutral score for new users with no payment history

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

    # Calculate payment amount based on loan term and type
    # Convert term_days to appropriate payment periods
    if next_loan.term_days && next_loan.term_days > 0
      # For loans <= 60 days, use the full balance (micro loans)
      if next_loan.term_days <= 60
        next_loan.remaining_balance.round
      else
        # For longer terms, calculate monthly payments
        term_months = (next_loan.term_days / 30.0).ceil
        (next_loan.remaining_balance / term_months).round
      end
    else
      # Fallback if term_days is not available
      next_loan.remaining_balance.round
    end
  end

  def most_urgent_loan
    # Prioritize loans by: overdue -> due soon -> highest interest rate
    overdue_loan = @active_loans.where("due_date < ?", Date.today)
                               .order(interest_rate: :desc, due_date: :asc)
                               .first
    return overdue_loan if overdue_loan

    due_soon_loan = @active_loans.where("due_date >= ? AND due_date <= ?", Date.today, Date.today + 7.days)
                                 .order(interest_rate: :desc, due_date: :asc)
                                 .first
    return due_soon_loan if due_soon_loan

    @active_loans.order(interest_rate: :desc, due_date: :asc).first
  end

  def calculate_credit_score_change
    # In a real app, this would track historical credit scores
    # For now, return a simple calculation based on recent payment behavior
    recent_payments = @user.payments.completed.where("paid_at >= ?", 30.days.ago).count
    return 0 if recent_payments.zero?
    
    # Simple heuristic: +2 points per on-time payment in last 30 days
    on_time_recent = @user.payments.completed
                          .joins(:loan)
                          .where("payments.paid_at >= ? AND payments.paid_at <= loans.due_date", 30.days.ago)
                          .count
    
    on_time_recent * 2
  end
end
