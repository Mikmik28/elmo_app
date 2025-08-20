class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :loans, dependent: :destroy
  has_many :payments, dependent: :destroy

  # Validations
  validates :phone_number, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
  validates :referral_code, uniqueness: true, allow_blank: true
  validates :status, inclusion: { in: %w[pending verified suspended blocked] }
  validates :credit_limit, :monthly_income, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :credit_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 }

  # Callbacks
  before_create :generate_referral_code
  after_create :apply_referral_bonus

  # Enums
  enum :status, { pending: 'pending', verified: 'verified', suspended: 'suspended', blocked: 'blocked' }
  enum :employment_status, { 
    unemployed: 'unemployed', 
    employed: 'employed', 
    self_employed: 'self_employed', 
    student: 'student', 
    retired: 'retired' 
  }

  # Scopes
  scope :verified, -> { where(status: 'verified') }
  scope :eligible_for_loan, -> { verified.where(kyc_verified: true) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def active_loans
    loans.where(status: ['approved', 'disbursed'])
  end

  def overdue_loans
    loans.where(status: 'overdue')
  end

  def total_borrowed
    loans.where(status: ['disbursed', 'paid']).sum(:amount)
  end

  def total_outstanding
    active_loans.sum(:total_amount_due)
  end

  def payment_history_score
    return 0 if loans.count.zero?
    
    paid_on_time = loans.joins(:payments)
                       .where(payments: { status: 'completed' })
                       .where('payments.paid_at <= loans.due_date')
                       .count
    
    total_completed_loans = loans.where(status: 'paid').count
    return 0 if total_completed_loans.zero?
    
    (paid_on_time.to_f / total_completed_loans * 100).round
  end

  def calculate_credit_score
    base_score = 300
    
    # Payment history (35% weight)
    payment_score = payment_history_score * 0.35
    
    # Credit utilization (30% weight) - lower is better
    utilization_ratio = total_outstanding / credit_limit.to_f
    utilization_score = [100 - (utilization_ratio * 100), 0].max * 0.30
    
    # Length of credit history (15% weight)
    months_active = ((Time.current - created_at) / 1.month).round
    history_score = [months_active * 2, 100].min * 0.15
    
    # Credit mix and new credit (20% weight)
    diversity_score = loans.distinct.count(:loan_type) * 10 * 0.20
    
    new_score = (base_score + payment_score + utilization_score + history_score + diversity_score).round
    
    # Update the credit score
    update_column(:credit_score, [new_score, 850].min)
    credit_score
  end

  def eligible_loan_amount
    return 0 unless kyc_verified? && verified?
    
    base_amount = case credit_score
                 when 0..399 then 1000
                 when 400..499 then 2000
                 when 500..599 then 5000
                 when 600..699 then 10000
                 when 700..799 then 20000
                 else 50000
                 end

    # Adjust based on monthly income
    income_based_limit = (monthly_income || 0) * 3
    
    # Return the minimum of credit limit, calculated limit, and income-based limit
    [credit_limit, base_amount, income_based_limit].compact.min
  end

  def can_apply_for_loan?
    verified? && kyc_verified? && active_loans.count < 3
  end

  private

  def generate_referral_code
    loop do
      self.referral_code = "ELMO#{SecureRandom.alphanumeric(6).upcase}"
      break unless User.exists?(referral_code: referral_code)
    end
  end

  def apply_referral_bonus
    return unless referred_by_code.present?
    
    referrer = User.find_by(referral_code: referred_by_code)
    return unless referrer
    
    # Give bonus to referrer
    referrer.increment!(:credit_limit, 500)
    
    # Give bonus to new user
    self.increment!(:credit_limit, 250)
  end
end
