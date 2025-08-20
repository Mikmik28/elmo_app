class LoansController < ApplicationController
  before_action :ensure_account_verified, except: [:index, :show]
  before_action :ensure_kyc_verified, only: [:new, :create]
  before_action :set_loan, only: [:show, :edit, :update, :destroy, :approve, :disburse]

  def index
    @loans = current_user.loans.order(created_at: :desc)
                        .page(params[:page])
                        .per(10)
    
    @loans = @loans.where(status: params[:status]) if params[:status].present?
  end

  def show
    @payments = @loan.payments.order(created_at: :desc)
  end

  def new
    unless current_user.can_apply_for_loan?
      redirect_to loans_path, alert: 'You are not eligible to apply for a new loan at this time.'
      return
    end

    @loan = current_user.loans.build
    @available_amount = current_user.eligible_loan_amount
    @scoring_service = CreditScoringService.new(current_user)
  end

  def create
    @loan = current_user.loans.build(loan_params)
    @scoring_service = CreditScoringService.new(current_user)

    # Apply promo code if provided
    if params[:promo_code].present?
      promo_result = apply_promo_code(params[:promo_code])
      flash[:notice] = promo_result[:message] if promo_result[:success]
      flash[:alert] = promo_result[:message] unless promo_result[:success]
    end

    if @loan.save
      # Queue loan for approval processing
      LoanApprovalJob.perform_later(@loan.id)
      
      redirect_to @loan, notice: 'Loan application submitted successfully. You will be notified of the decision shortly.'
    else
      @available_amount = current_user.eligible_loan_amount
      render :new, status: :unprocessable_entity
    end
  end

  def approve
    # Admin only action
    return unless current_user.admin?

    if @loan.can_be_approved?
      @loan.approve!
      redirect_to @loan, notice: 'Loan approved successfully.'
    else
      redirect_to @loan, alert: 'Loan cannot be approved at this time.'
    end
  end

  def disburse
    # Admin only action
    return unless current_user.admin?

    if @loan.approved? && disburse_params_valid?
      LoanDisbursementJob.perform_later(
        @loan.id, 
        params[:disbursement_method], 
        params[:disbursement_account]
      )
      
      redirect_to @loan, notice: 'Loan disbursement initiated.'
    else
      redirect_to @loan, alert: 'Cannot disburse loan. Check loan status and disbursement details.'
    end
  end

  private

  def set_loan
    @loan = current_user.loans.find(params[:id])
  end

  def loan_params
    params.require(:loan).permit(:amount, :term_days, :purpose, :loan_type)
  end

  def apply_promo_code(code)
    promo = PromoCode.find_by(code: code.upcase)
    return { success: false, message: 'Invalid promo code' } unless promo

    promo.apply_to_loan(@loan)
  end

  def disburse_params_valid?
    params[:disbursement_method].present? && params[:disbursement_account].present?
  end
end
