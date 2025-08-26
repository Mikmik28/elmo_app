class CompleteAutomaticPaymentJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment = Payment.find(payment_id)
    return unless payment.processing?

    # Simulate automatic payment completion (90% success rate)
    if rand < 0.9
      payment.complete_payment!
      Rails.logger.info "Automatic payment #{payment.id} completed successfully"
    else
      payment.fail_payment!("Automatic payment failed - insufficient funds")
      Rails.logger.info "Automatic payment #{payment.id} failed"
    end
  end
end
