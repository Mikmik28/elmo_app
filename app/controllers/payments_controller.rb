class PaymentsController < ApplicationController
  before_action :set_loan
  before_action :set_payment, only: [:show, :update, :cancel]

  def index
    @payments = @loan.payments.order(created_at: :desc)
  end

  def show
  end

  def new
    @payment = @loan.payments.build
    @remaining_balance = @loan.remaining_balance
    @minimum_payment = calculate_minimum_payment
  end

  def create
    @payment = @loan.payments.build(payment_params)
    @payment.user = current_user

    if @payment.save
      # Process payment
      PaymentProcessingJob.perform_later(@payment.id)
      
      redirect_to [@loan, @payment], notice: 'Payment initiated successfully. You will be notified once processed.'
    else
      @remaining_balance = @loan.remaining_balance
      @minimum_payment = calculate_minimum_payment
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # For updating payment status (admin only or webhook)
    if params[:status].present? && valid_status_update?
      case params[:status]
      when 'completed'
        @payment.complete_payment!
        flash[:notice] = 'Payment marked as completed.'
      when 'failed'
        @payment.fail_payment!(params[:failure_reason])
        flash[:alert] = 'Payment marked as failed.'
      end
    end

    redirect_to [@loan, @payment]
  end

  def cancel
    if @payment.pending?
      @payment.update!(status: 'cancelled')
      redirect_to [@loan, @payment], notice: 'Payment cancelled successfully.'
    else
      redirect_to [@loan, @payment], alert: 'Cannot cancel payment in current status.'
    end
  end

  # Webhook endpoint for payment gateways
  def webhook
    # This would handle webhooks from payment gateways
    payment_reference = params[:payment_reference]
    payment = Payment.find_by(payment_reference: payment_reference)
    
    if payment
      service = PaymentProcessingService.new(payment)
      result = service.process_webhook(params.to_unsafe_h)
      
      if result[:success]
        render json: { status: 'success' }, status: 200
      else
        render json: { status: 'error', message: result[:message] }, status: 400
      end
    else
      render json: { status: 'error', message: 'Payment not found' }, status: 404
    end
  end

  private

  def set_loan
    @loan = current_user.loans.find(params[:loan_id])
  end

  def set_payment
    @payment = @loan.payments.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:amount, :payment_method)
  end

  def calculate_minimum_payment
    # Minimum payment is 10% of remaining balance or 500, whichever is higher
    [@loan.remaining_balance * 0.10, 500].max
  end

  def valid_status_update?
    # Only allow admin users or system to update payment status
    current_user.admin? || request.headers['X-System-Update'] == 'true'
  end
end
