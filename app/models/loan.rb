class Loan < ApplicationRecord
  belongs_to :user
  has_many :payments, dependent: :destroy

  # Validations
  validates :amount, :interest_rate, :total_amount_due, :term_days, presence: true
  validates :amount, :total_amount_due, numericality: { greater_than: 0 }
  validates :interest_rate, :daily_penalty_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :term_days, numericality: { greater_than: 0, less_than_or_equal_to: 365 }
  validates :status, inclusion: { in: %w[pending approved disbursed paid overdue defaulted rejected] }
  validates :loan_type, inclusion: { in: %w[personal emergency education business] }

  # Callbacks
  before_validation :calculate_total_amount_due, :set_due_date
  after_update :update_user_credit_score, if: :saved_change_to_status?

  # Enums
  enum :status, {
    pending: 'pending',
    approved: 'approved', 
    disbursed: 'disbursed',
    paid: 'paid',
    overdue: 'overdue',
    defaulted: 'defaulted',
    rejected: 'rejected'
  }

  enum :loan_type, {
    personal: 'personal',
    emergency: 'emergency', 
    education: 'education',
    business: 'business'
  }

  # Scopes
  scope :active, -> { where(status: ['approved', 'disbursed']) }
  scope :overdue, -> { where('due_date < ? AND status IN (?)', Date.current, ['disbursed']) }
  scope :due_today, -> { where(due_date: Date.current, status: 'disbursed') }
  scope :due_soon, -> { where(due_date: Date.current..3.days.from_now, status: 'disbursed') }

  # Instance methods
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end

  def penalty_amount
    return 0 unless overdue?
    days_overdue * (total_amount_due * daily_penalty_rate)
  end

  def total_amount_with_penalty
    total_amount_due + penalty_amount
  end

  def remaining_balance
    total_amount_with_penalty - payments.completed.sum(:amount)
  end

  def payment_progress_percentage
    return 0 if total_amount_with_penalty.zero?
    ((payments.completed.sum(:amount) / total_amount_with_penalty) * 100).round(2)
  end

  def can_be_approved?
    pending? && user.can_apply_for_loan? && amount <= user.eligible_loan_amount
  end

  def approve!
    return false unless can_be_approved?
    
    update!(
      status: 'approved',
      approved_at: Time.current,
      approval_metadata: {
        approved_by: 'system',
        user_credit_score: user.credit_score,
        user_credit_limit: user.credit_limit,
        approval_algorithm_version: '1.0'
      }
    )
  end

  def disburse!(disbursement_method, disbursement_account)
    return false unless approved?
    
    update!(
      status: 'disbursed',
      disbursed_at: Time.current,
      disbursement_method: disbursement_method,
      disbursement_account: disbursement_account
    )
    
    # Create initial payment record for tracking
    payments.create!(
      user: user,
      amount: 0,
      payment_method: 'initial',
      status: 'pending'
    )
  end

  def mark_as_paid!
    return false unless disbursed?
    
    update!(
      status: 'paid',
      paid_at: Time.current
    )
    
    # Update user's credit limit based on successful payment
    user.increment!(:credit_limit, amount * 0.1) # 10% increase
  end

  def mark_as_overdue!
    return false unless disbursed? && Date.current > due_date
    
    update!(status: 'overdue')
    
    # Decrease user's credit score
    new_score = [user.credit_score - 50, 300].max
    user.update!(credit_score: new_score)
  end

  def mark_as_defaulted!
    return false unless overdue? && days_overdue > 90
    
    update!(status: 'defaulted')
    
    # Severely impact credit score and suspend user
    user.update!(
      credit_score: 300,
      status: 'suspended'
    )
  end

  def interest_amount
    total_amount_due - amount
  end

  def daily_interest_rate
    interest_rate / 365.0
  end

  private

  def calculate_total_amount_due
    return unless amount.present? && interest_rate.present? && term_days.present?
    
    # Simple interest calculation
    interest_amount = amount * (interest_rate / 100.0) * (term_days / 365.0)
    self.total_amount_due = amount + interest_amount
  end

  def set_due_date
    return unless term_days.present?
    
    self.due_date = (created_at || Time.current) + term_days.days
  end

  def update_user_credit_score
    user.calculate_credit_score if %w[paid overdue defaulted].include?(status)
  end
end
