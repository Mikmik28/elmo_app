class LoanDisbursementNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(loan_id)
    loan = Loan.find(loan_id)
    user = loan.user

    message = "Great news! Your eLMO loan of ₱#{loan.amount.to_i} has been disbursed to your #{loan.disbursement_method} account. " \
              "Your payment of ₱#{loan.total_amount_due.to_i} is due on #{loan.due_date.strftime('%B %d, %Y')}."

    send_sms(user.phone_number, message)
    
    Rails.logger.info "Sent disbursement notification for loan #{loan.id} to user #{user.id}"
  end

  private

  def send_sms(phone_number, message)
    Rails.logger.info "SMS to #{phone_number}: #{message}"
  end
end
