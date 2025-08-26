class PaymentProcessingJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment = Payment.find(payment_id)
    return unless payment.pending?

    processing_service = PaymentProcessingService.new(payment)
    result = processing_service.process_payment

    if result[:success]
      Rails.logger.info "Payment #{payment.id} processing initiated: #{result[:message]}"

      # For automatic payments, try to complete immediately
      if payment.payment_metadata&.dig("automatic_payment")
        # Simulate processing delay for automatic payments
        CompleteAutomaticPaymentJob.set(wait: 30.seconds).perform_later(payment.id)
      end
    else
      Rails.logger.error "Payment #{payment.id} processing failed: #{result[:message]}"
    end
  end
end
