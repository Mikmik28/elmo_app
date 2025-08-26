class CreditScoringService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def calculate_score
    base_score = 300

    payment_history_score +
    credit_utilization_score +
    credit_history_length_score +
    credit_mix_score +
    new_credit_score +
    base_score
  end

  def loan_approval_decision(requested_amount)
    score = calculate_score

    {
      approved: approval_decision(score, requested_amount),
      credit_score: score,
      recommended_amount: recommended_loan_amount(score),
      interest_rate: calculate_interest_rate(score),
      reasons: approval_reasons(score, requested_amount),
      risk_level: risk_level(score)
    }
  end

  def recommended_loan_amount(score = nil)
    score ||= calculate_score

    base_amount = case score
    when 300..399 then 1000
    when 400..499 then 2500
    when 500..599 then 5000
    when 600..699 then 10000
    when 700..749 then 25000
    when 750..799 then 50000
    else 100000
    end

    # Adjust based on income
    income_multiplier = case user.monthly_income.to_f
    when 0..15000 then 1.0
    when 15001..30000 then 1.5
    when 30001..50000 then 2.0
    when 50001..100000 then 3.0
    else 4.0
    end

    adjusted_amount = base_amount * income_multiplier

    # Don't exceed credit limit
    [ adjusted_amount, user.credit_limit ].min
  end

  def calculate_interest_rate(score = nil)
    score ||= calculate_score

    base_rate = case score
    when 300..399 then 25.0  # High risk
    when 400..499 then 20.0  # Medium-high risk
    when 500..599 then 15.0  # Medium risk
    when 600..699 then 12.0  # Medium-low risk
    when 700..749 then 8.0   # Low risk
    when 750..799 then 6.0   # Very low risk
    else 4.0                 # Excellent
    end

    # Adjust based on loan history
    if user.loans.paid.count >= 3
      base_rate -= 2.0  # Loyalty discount
    elsif user.loans.overdue.count > 0
      base_rate += 3.0  # Penalty for overdue history
    end

    # Ensure minimum rate
    [ base_rate, 4.0 ].max
  end

  private

  def payment_history_score
    return 0 if user.loans.count.zero?

    total_loans = user.loans.where(status: [ "paid", "overdue", "defaulted" ]).count
    return 0 if total_loans.zero?

    on_time_payments = user.loans.joins(:payments)
                          .where(payments: { status: "completed" })
                          .where("payments.paid_at <= loans.due_date")
                          .count

    late_payments = user.loans.where(status: "overdue").count
    defaults = user.loans.where(status: "defaulted").count

    # Calculate score (35% of total)
    base_score = (on_time_payments.to_f / total_loans * 100) * 0.35

    # Penalties
    base_score -= (late_payments * 10)
    base_score -= (defaults * 50)

    [ base_score, 0 ].max
  end

  def credit_utilization_score
    return 30 if user.credit_limit.zero? # 30% weight if no credit limit set

    utilization_ratio = user.total_outstanding / user.credit_limit.to_f

    score = case utilization_ratio
    when 0..0.1 then 30      # Excellent (0-10%)
    when 0.1..0.3 then 25    # Good (10-30%)
    when 0.3..0.5 then 20    # Fair (30-50%)
    when 0.5..0.7 then 15    # Poor (50-70%)
    when 0.7..0.9 then 10    # Bad (70-90%)
    else 0                   # Very bad (90%+)
    end

    score
  end

  def credit_history_length_score
    months_since_signup = ((Time.current - user.created_at) / 1.month).round

    score = case months_since_signup
    when 0..3 then 5
    when 4..12 then 10
    when 13..24 then 15
    else 15
    end

    score
  end

  def credit_mix_score
    # 10% weight for having different types of loans
    unique_loan_types = user.loans.distinct.count(:loan_type)

    case unique_loan_types
    when 0 then 0
    when 1 then 5
    when 2 then 8
    else 10
    end
  end

  def new_credit_score
    # 10% weight - penalize for too many recent applications
    recent_loans = user.loans.where("created_at > ?", 3.months.ago).count

    case recent_loans
    when 0..1 then 10
    when 2 then 8
    when 3 then 5
    when 4 then 3
    else 0
    end
  end

  def approval_decision(score, requested_amount)
    return false unless user.kyc_verified?
    return false unless user.verified?
    return false if user.loans.where(status: [ "overdue", "defaulted" ]).exists?
    return false if score < 350
    return false if requested_amount > recommended_loan_amount(score)

    true
  end

  def approval_reasons(score, requested_amount)
    reasons = []

    unless user.kyc_verified?
      reasons << "KYC verification required"
    end

    unless user.verified?
      reasons << "Account verification pending"
    end

    if user.loans.where(status: [ "overdue", "defaulted" ]).exists?
      reasons << "Outstanding overdue loans"
    end

    if score < 350
      reasons << "Credit score too low (minimum 350 required)"
    end

    if requested_amount > recommended_loan_amount(score)
      reasons << "Requested amount exceeds recommended limit"
    end

    if score >= 350 && approval_decision(score, requested_amount)
      reasons << "Application meets all criteria"
    end

    reasons
  end

  def risk_level(score)
    case score
    when 750..Float::INFINITY then "very_low"
    when 700..749 then "low"
    when 600..699 then "medium"
    when 500..599 then "medium_high"
    when 400..499 then "high"
    else "very_high"
    end
  end
end
