class PromoCode < ApplicationRecord
  # Validations
  validates :code, presence: true, uniqueness: true, length: { minimum: 4, maximum: 20 }
  validates :promo_type, inclusion: { in: %w[discount credit_bonus interest_reduction fee_waiver] }
  validates :discount_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :discount_amount, :bonus_credit, numericality: { greater_than: 0 }, allow_nil: true
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :normalize_code
  validate :valid_date_range
  validate :valid_promo_configuration

  # Enums
  enum :promo_type, {
    discount: 'discount',
    credit_bonus: 'credit_bonus',
    interest_reduction: 'interest_reduction',
    fee_waiver: 'fee_waiver'
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :available, -> { active.where('valid_from <= ? AND valid_until >= ?', Date.current, Date.current) }
  scope :unlimited, -> { where(usage_limit: nil) }
  scope :limited, -> { where.not(usage_limit: nil) }

  # Instance methods
  def promo_valid?
    super && currently_valid? && usage_available?
  end

  def currently_valid?
    active? && 
    Date.current >= valid_from && 
    Date.current <= valid_until
  end

  def usage_available?
    usage_limit.nil? || used_count < usage_limit
  end

  def can_be_used_by?(user)
    return false unless currently_valid? && usage_available?
    
    # Check conditions if any
    return true if conditions.blank?
    
    conditions.all? do |condition, value|
      case condition
      when 'min_credit_score'
        user.credit_score >= value
      when 'max_previous_loans'
        user.loans.count <= value
      when 'employment_status'
        user.employment_status == value
      when 'kyc_verified'
        user.kyc_verified == value
      when 'user_status'
        user.status == value
      else
        true
      end
    end
  end

  def apply_to_loan(loan)
    return { success: false, message: 'Promo code not valid' } unless can_be_used_by?(loan.user)
    
    case promo_type
    when 'discount'
      apply_discount(loan)
    when 'credit_bonus'
      apply_credit_bonus(loan.user)
    when 'interest_reduction'
      apply_interest_reduction(loan)
    when 'fee_waiver'
      apply_fee_waiver(loan)
    end
  end

  def apply_to_user(user)
    return { success: false, message: 'Promo code not valid' } unless can_be_used_by?(user)
    
    case promo_type
    when 'credit_bonus'
      apply_credit_bonus(user)
    else
      { success: false, message: 'This promo code cannot be applied to user account' }
    end
  end

  def use!
    increment!(:used_count)
    
    # Deactivate if usage limit reached
    update!(active: false) if usage_limit.present? && used_count >= usage_limit
  end

  def remaining_uses
    return Float::INFINITY if usage_limit.nil?
    [usage_limit - used_count, 0].max
  end

  def usage_percentage
    return 0 if usage_limit.nil?
    ((used_count.to_f / usage_limit) * 100).round(2)
  end

  private

  def normalize_code
    self.code = code.to_s.upcase.strip if code.present?
  end

  def valid_date_range
    return unless valid_from.present? && valid_until.present?
    
    errors.add(:valid_until, 'must be after valid from date') if valid_until < valid_from
  end

  def valid_promo_configuration
    case promo_type
    when 'discount'
      if discount_percentage.blank? && discount_amount.blank?
        errors.add(:base, 'Discount promo must have either percentage or amount')
      end
    when 'credit_bonus'
      if bonus_credit.blank?
        errors.add(:bonus_credit, 'Credit bonus promo must have bonus credit amount')
      end
    when 'interest_reduction'
      if discount_percentage.blank?
        errors.add(:discount_percentage, 'Interest reduction promo must have discount percentage')
      end
    end
  end

  def apply_discount(loan)
    if discount_percentage.present?
      discount = loan.amount * (discount_percentage / 100.0)
    else
      discount = [discount_amount, loan.amount].min
    end
    
    new_amount = loan.amount - discount
    loan.update!(
      amount: new_amount,
      approval_metadata: (loan.approval_metadata || {}).merge({
        promo_code: code,
        original_amount: loan.amount + discount,
        discount_applied: discount
      })
    )
    
    use!
    { success: true, message: "Discount of ₱#{discount.round(2)} applied", discount: discount }
  end

  def apply_credit_bonus(user)
    user.increment!(:credit_limit, bonus_credit)
    
    use!
    { success: true, message: "Credit bonus of ₱#{bonus_credit} added to your account", bonus: bonus_credit }
  end

  def apply_interest_reduction(loan)
    reduction = loan.interest_rate * (discount_percentage / 100.0)
    new_rate = loan.interest_rate - reduction
    
    loan.update!(
      interest_rate: new_rate,
      approval_metadata: (loan.approval_metadata || {}).merge({
        promo_code: code,
        original_interest_rate: loan.interest_rate + reduction,
        interest_reduction: reduction
      })
    )
    
    use!
    { success: true, message: "Interest rate reduced by #{discount_percentage}%", reduction: reduction }
  end

  def apply_fee_waiver(loan)
    # This would be implemented based on specific fee structure
    loan.update!(
      approval_metadata: (loan.approval_metadata || {}).merge({
        promo_code: code,
        fees_waived: true
      })
    )
    
    use!
    { success: true, message: "Processing fees waived" }
  end
end
