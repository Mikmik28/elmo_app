class Api::V1::PaymentsController < Api::V1::BaseController
  def create
    loan = current_user.loans.find(params[:loan_id])
    
    @payment = loan.payments.build(payment_params)
    @payment.user = current_user

    if @payment.save
      # Process payment
      PaymentProcessingJob.perform_later(@payment.id)
      
      payment_data = {
        id: @payment.id,
        amount: @payment.amount,
        payment_method: @payment.payment_method,
        payment_reference: @payment.payment_reference,
        status: @payment.status,
        created_at: @payment.created_at
      }
      
      render_success({ payment: payment_data }, 'Payment initiated successfully')
    else
      render_error(@payment.errors.full_messages.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Loan not found', :not_found)
  end

  private

  def payment_params
    params.require(:payment).permit(:amount, :payment_method)
  end
end
