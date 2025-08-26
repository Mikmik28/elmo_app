class LoanDecisionNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(loan_id)
    loan = Loan.find(loan_id)
    user = loan.user

    case loan.status
    when "approved"
      send_approval_notification(user, loan)
    when "rejected"
      send_rejection_notification(user, loan)
    end
  end

  private

  def send_approval_notification(user, loan)
    # SMS notification
    message = "Great news! Your eLMO loan application for ₱#{loan.amount.to_i} has been APPROVED! " \
              "Interest rate: #{loan.interest_rate}% per year. " \
              "Choose your disbursement method to receive funds."

    send_sms(user.phone_number, message)

    # Email notification (if implemented)
    # LoanMailer.approval_notification(user, loan).deliver_now

    Rails.logger.info "Sent approval notification for loan #{loan.id} to user #{user.id}"
  end

  def send_rejection_notification(user, loan)
    reasons = loan.approval_metadata&.dig("rejection_reasons") || [ "Application does not meet current criteria" ]

    message = "We're sorry, but your eLMO loan application for ₱#{loan.amount.to_i} was not approved. " \
              "Reason: #{reasons.first}. You can reapply after improving your profile."

    send_sms(user.phone_number, message)

    Rails.logger.info "Sent rejection notification for loan #{loan.id} to user #{user.id}"
  end

  def send_sms(phone_number, message)
    # Implement actual SMS sending logic here
    # For now, just log the message
    Rails.logger.info "SMS to #{phone_number}: #{message}"

    # Example Twilio implementation:
    # client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
    # client.messages.create(
    #   from: '+1234567890', # Your Twilio number
    #   to: phone_number,
    #   body: message
    # )
  end
end
