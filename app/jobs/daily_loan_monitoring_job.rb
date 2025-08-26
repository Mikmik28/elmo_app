class DailyLoanMonitoringJob < ApplicationJob
  queue_as :low_priority

  def perform(loan_id = nil)
    if loan_id
      # Monitor specific loan
      monitor_single_loan(loan_id)
    else
      # Monitor all active loans
      monitor_all_loans
    end
  end

  private

  def monitor_single_loan(loan_id)
    loan = Loan.find_by(id: loan_id)
    return unless loan&.disbursed?

    process_loan_monitoring(loan)
  end

  def monitor_all_loans
    # Process loans in batches to avoid memory issues
    Loan.disbursed.find_each(batch_size: 100) do |loan|
      process_loan_monitoring(loan)
    end

    # Update user credit limits based on payment history
    update_user_credit_limits

    # Generate daily reports
    generate_daily_reports
  end

  def process_loan_monitoring(loan)
    today = Date.current

    case
    when loan.due_date == today
      handle_due_today(loan)
    when loan.due_date < today
      handle_overdue(loan)
    when loan.due_date.between?(today + 1.day, today + 3.days)
      handle_due_soon(loan)
    end

    # Check for automatic payments
    process_automatic_payments(loan) if loan.user.auto_payment_enabled?
  end

  def handle_due_today(loan)
    # Send due today notification
    LoanReminderNotificationJob.perform_later(loan.id, "due_today")

    # Try to process automatic payment if enabled
    process_automatic_payments(loan) if loan.user.auto_payment_enabled?

    Rails.logger.info "Loan #{loan.id} is due today, notifications sent"
  end

  def handle_overdue(loan)
    days_overdue = (Date.current - loan.due_date).to_i

    case days_overdue
    when 1
      # First day overdue
      loan.mark_as_overdue! unless loan.overdue?
      LoanReminderNotificationJob.perform_later(loan.id, "overdue_1_day")

    when 3
      # 3 days overdue
      LoanReminderNotificationJob.perform_later(loan.id, "overdue_3_days")

    when 7
      # 1 week overdue
      LoanReminderNotificationJob.perform_later(loan.id, "overdue_1_week")
      # Reduce credit limit
      reduce_user_credit_limit(loan.user, 0.1) # 10% reduction

    when 30
      # 1 month overdue
      LoanReminderNotificationJob.perform_later(loan.id, "overdue_1_month")
      # Suspend user temporarily
      loan.user.update!(status: "suspended") unless loan.user.suspended?

    when 90
      # 3 months overdue - mark as default
      loan.mark_as_defaulted!
      LoanReminderNotificationJob.perform_later(loan.id, "defaulted")

      # Block user account
      loan.user.update!(status: "blocked")

      # Initiate collection process
      CollectionProcessJob.perform_later(loan.id)
    end

    Rails.logger.info "Processed overdue loan #{loan.id}, #{days_overdue} days overdue"
  end

  def handle_due_soon(loan)
    days_until_due = (loan.due_date - Date.current).to_i

    # Send reminder notification
    LoanReminderNotificationJob.perform_later(loan.id, "due_in_#{days_until_due}_days")

    Rails.logger.info "Sent reminder for loan #{loan.id}, due in #{days_until_due} days"
  end

  def process_automatic_payments(loan)
    return unless loan.user.auto_payment_method.present?
    return if loan.payments.pending_processing.exists? # Don't create duplicate payments

    # Create automatic payment for full outstanding amount
    payment = loan.payments.create!(
      user: loan.user,
      amount: loan.remaining_balance,
      payment_method: loan.user.auto_payment_method,
      status: "pending",
      payment_metadata: {
        automatic_payment: true,
        created_by: "system",
        auto_payment_attempt: true
      }
    )

    # Process the payment
    PaymentProcessingJob.perform_later(payment.id)

    Rails.logger.info "Created automatic payment #{payment.id} for loan #{loan.id}"
  end

  def update_user_credit_limits
    # Increase credit limits for users with good payment history
    User.eligible_for_loan.find_each(batch_size: 50) do |user|
      next if user.loans.count < 2 # Need at least 2 loans for evaluation

      payment_score = user.payment_history_score

      case payment_score
      when 90..100
        # Excellent payment history - increase by 20%
        increase_user_credit_limit(user, 0.20)
      when 80..89
        # Good payment history - increase by 10%
        increase_user_credit_limit(user, 0.10)
      when 70..79
        # Fair payment history - increase by 5%
        increase_user_credit_limit(user, 0.05)
      end
    end
  end

  def increase_user_credit_limit(user, percentage)
    current_limit = user.credit_limit
    increase_amount = current_limit * percentage
    max_limit = 500_000 # Maximum credit limit

    new_limit = [ current_limit + increase_amount, max_limit ].min

    if new_limit > current_limit
      user.update!(credit_limit: new_limit)
      CreditLimitUpdateNotificationJob.perform_later(user.id, new_limit, current_limit)

      Rails.logger.info "Increased credit limit for user #{user.id} from #{current_limit} to #{new_limit}"
    end
  end

  def reduce_user_credit_limit(user, percentage)
    current_limit = user.credit_limit
    decrease_amount = current_limit * percentage
    min_limit = 1000 # Minimum credit limit

    new_limit = [ current_limit - decrease_amount, min_limit ].max

    if new_limit < current_limit
      user.update!(credit_limit: new_limit)

      Rails.logger.info "Reduced credit limit for user #{user.id} from #{current_limit} to #{new_limit}"
    end
  end

  def generate_daily_reports
    date = Date.current

    # Loan statistics
    total_active_loans = Loan.active.count
    total_overdue_loans = Loan.overdue.count
    total_disbursed_today = Loan.where(disbursed_at: date.beginning_of_day..date.end_of_day).sum(:amount)
    total_payments_today = Payment.completed.where(paid_at: date.beginning_of_day..date.end_of_day).sum(:amount)

    # User statistics
    new_users_today = User.where(created_at: date.beginning_of_day..date.end_of_day).count
    verified_users_today = User.where(updated_at: date.beginning_of_day..date.end_of_day, status: "verified").count

    report_data = {
      date: date,
      loans: {
        total_active: total_active_loans,
        total_overdue: total_overdue_loans,
        disbursed_amount_today: total_disbursed_today,
        overdue_rate: total_active_loans > 0 ? (total_overdue_loans.to_f / total_active_loans * 100).round(2) : 0
      },
      payments: {
        total_amount_today: total_payments_today,
        count_today: Payment.completed.where(paid_at: date.beginning_of_day..date.end_of_day).count
      },
      users: {
        new_today: new_users_today,
        verified_today: verified_users_today,
        total_active: User.verified.count
      }
    }

    # Send report to admin
    DailyReportNotificationJob.perform_later(report_data)

    Rails.logger.info "Generated daily report for #{date}"
  end
end
