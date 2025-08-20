class LoanReminderNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(loan_id, reminder_type)
    loan = Loan.find(loan_id)
    user = loan.user

    message = case reminder_type
              when 'due_today'
                "Reminder: Your eLMO loan payment of ₱#{loan.remaining_balance.to_i} is due TODAY. " \
                "Pay now to avoid penalties. Reference: #{loan.id}"
              when 'due_in_3_days'
                "Reminder: Your eLMO loan payment of ₱#{loan.remaining_balance.to_i} is due in 3 days (#{loan.due_date.strftime('%B %d')}). " \
                "Pay early to maintain your good credit score!"
              when 'due_in_2_days'
                "Reminder: Your eLMO loan payment of ₱#{loan.remaining_balance.to_i} is due in 2 days (#{loan.due_date.strftime('%B %d')}). " \
                "Don't forget to pay on time!"
              when 'due_in_1_day'
                "Important: Your eLMO loan payment of ₱#{loan.remaining_balance.to_i} is due TOMORROW (#{loan.due_date.strftime('%B %d')}). " \
                "Pay now to avoid late fees."
              when 'overdue_1_day'
                "OVERDUE: Your eLMO loan payment of ₱#{loan.total_amount_with_penalty.to_i} is 1 day overdue. " \
                "Late fees apply. Pay now to minimize additional charges."
              when 'overdue_3_days'
                "URGENT: Your eLMO loan payment of ₱#{loan.total_amount_with_penalty.to_i} is 3 days overdue. " \
                "Please pay immediately to avoid further penalties and protect your credit score."
              when 'overdue_1_week'
                "FINAL NOTICE: Your eLMO loan payment of ₱#{loan.total_amount_with_penalty.to_i} is 1 week overdue. " \
                "Your credit limit has been reduced. Pay now to restore your account."
              when 'overdue_1_month'
                "ACCOUNT SUSPENDED: Your eLMO loan payment of ₱#{loan.total_amount_with_penalty.to_i} is 1 month overdue. " \
                "Your account is temporarily suspended. Pay now to reactivate."
              when 'defaulted'
                "LOAN DEFAULTED: Your eLMO loan has been marked as defaulted. " \
                "Your account is blocked. Contact our collection team immediately."
              else
                "eLMO loan payment reminder for loan ##{loan.id}"
              end

    send_sms(user.phone_number, message)
    
    Rails.logger.info "Sent #{reminder_type} reminder for loan #{loan.id} to user #{user.id}"
  end

  private

  def send_sms(phone_number, message)
    # Implement actual SMS sending logic here
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
