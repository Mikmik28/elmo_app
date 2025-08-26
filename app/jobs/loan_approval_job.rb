class LoanApprovalJob < ApplicationJob
  queue_as :default

  def perform(loan_id)
    loan = Loan.find(loan_id)
    return unless loan.pending?

    # Calculate credit score and approval decision
    scoring_service = CreditScoringService.new(loan.user)
    decision = scoring_service.loan_approval_decision(loan.amount)

    if decision[:approved]
      approve_loan(loan, decision)
    else
      reject_loan(loan, decision)
    end

    # Send notification to user
    LoanDecisionNotificationJob.perform_later(loan.id)
  end

  private

  def approve_loan(loan, decision)
    loan.update!(
      status: "approved",
      approved_at: Time.current,
      interest_rate: decision[:interest_rate],
      approval_metadata: {
        approved_by: "automated_system",
        credit_score_at_approval: decision[:credit_score],
        risk_level: decision[:risk_level],
        recommended_amount: decision[:recommended_amount],
        approval_timestamp: Time.current.iso8601
      }
    )

    # Update user's credit score
    loan.user.update!(credit_score: decision[:credit_score])

    Rails.logger.info "Loan #{loan.id} approved automatically for user #{loan.user.id}"
  end

  def reject_loan(loan, decision)
    loan.update!(
      status: "rejected",
      approval_metadata: {
        rejected_by: "automated_system",
        rejection_reasons: decision[:reasons],
        credit_score_at_rejection: decision[:credit_score],
        risk_level: decision[:risk_level],
        rejection_timestamp: Time.current.iso8601
      }
    )

    Rails.logger.info "Loan #{loan.id} rejected automatically for user #{loan.user.id}: #{decision[:reasons].join(', ')}"
  end
end
