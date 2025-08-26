class Api::V1::LoansController < Api::V1::BaseController
  before_action :set_loan, only: [ :show ]

  def index
    @loans = current_user.loans.order(created_at: :desc)

    loans_data = @loans.map do |loan|
      {
        id: loan.id,
        amount: loan.amount,
        total_amount_due: loan.total_amount_due,
        interest_rate: loan.interest_rate,
        status: loan.status,
        due_date: loan.due_date,
        term_days: loan.term_days,
        loan_type: loan.loan_type,
        remaining_balance: loan.remaining_balance,
        created_at: loan.created_at,
        approved_at: loan.approved_at,
        disbursed_at: loan.disbursed_at
      }
    end

    render_success({ loans: loans_data })
  end

  def show
    loan_data = {
      id: @loan.id,
      amount: @loan.amount,
      total_amount_due: @loan.total_amount_due,
      total_amount_with_penalty: @loan.total_amount_with_penalty,
      interest_rate: @loan.interest_rate,
      daily_penalty_rate: @loan.daily_penalty_rate,
      status: @loan.status,
      due_date: @loan.due_date,
      term_days: @loan.term_days,
      loan_type: @loan.loan_type,
      purpose: @loan.purpose,
      remaining_balance: @loan.remaining_balance,
      days_overdue: @loan.days_overdue,
      penalty_amount: @loan.penalty_amount,
      payment_progress_percentage: @loan.payment_progress_percentage,
      created_at: @loan.created_at,
      approved_at: @loan.approved_at,
      disbursed_at: @loan.disbursed_at,
      paid_at: @loan.paid_at,
      payments: @loan.payments.map do |payment|
        {
          id: payment.id,
          amount: payment.amount,
          status: payment.status,
          payment_method: payment.payment_method,
          payment_reference: payment.payment_reference,
          paid_at: payment.paid_at,
          created_at: payment.created_at
        }
      end
    }

    render_success({ loan: loan_data })
  end

  def create
    unless current_user.can_apply_for_loan?
      render_error("You are not eligible to apply for a new loan at this time.")
      return
    end

    @loan = current_user.loans.build(loan_params)

    if @loan.save
      # Queue loan for approval processing
      LoanApprovalJob.perform_later(@loan.id)

      loan_data = {
        id: @loan.id,
        amount: @loan.amount,
        status: @loan.status,
        term_days: @loan.term_days,
        loan_type: @loan.loan_type,
        created_at: @loan.created_at
      }

      render_success({ loan: loan_data }, "Loan application submitted successfully")
    else
      render_error(@loan.errors.full_messages.join(", "))
    end
  end

  def calculate
    # Calculate loan details without creating the loan
    amount = params[:amount].to_f
    term_days = params[:term_days].to_i
    loan_type = params[:loan_type] || "personal"

    if amount <= 0 || term_days <= 0
      render_error("Invalid amount or term days")
      return
    end

    scoring_service = CreditScoringService.new(current_user)
    decision = scoring_service.loan_approval_decision(amount)

    # Calculate loan details
    interest_rate = decision[:interest_rate]
    interest_amount = amount * (interest_rate / 100.0) * (term_days / 365.0)
    total_amount_due = amount + interest_amount
    due_date = Date.current + term_days.days

    calculation_data = {
      amount: amount,
      term_days: term_days,
      loan_type: loan_type,
      interest_rate: interest_rate,
      interest_amount: interest_amount.round(2),
      total_amount_due: total_amount_due.round(2),
      due_date: due_date,
      daily_payment: (total_amount_due / term_days).round(2),
      approval_likelihood: decision[:approved] ? "high" : "low",
      recommended_amount: decision[:recommended_amount],
      risk_level: decision[:risk_level]
    }

    render_success({ calculation: calculation_data })
  end

  private

  def set_loan
    @loan = current_user.loans.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Loan not found", :not_found)
  end

  def loan_params
    params.require(:loan).permit(:amount, :term_days, :purpose, :loan_type)
  end
end
