class Payment < ApplicationRecord
  belongs_to :loan
  belongs_to :user

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending processing completed failed refunded] }
  validates :payment_method, inclusion: { in: %w[gcash paymaya bank_transfer cash online_banking] }
  validates :payment_reference, uniqueness: true, allow_blank: true

  # Callbacks
  before_create :generate_payment_reference
  after_update :update_loan_status, if: :saved_change_to_status?

  # Enums
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    refunded: "refunded"
  }

  enum :payment_method, {
    gcash: "gcash",
    paymaya: "paymaya",
    bank_transfer: "bank_transfer",
    cash: "cash",
    online_banking: "online_banking"
  }

  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :pending_processing, -> { where(status: [ "pending", "processing" ]) }
  scope :successful, -> { where(status: "completed") }
  scope :failed, -> { where(status: [ "failed", "refunded" ]) }

  # Instance methods
  def process_payment!
    return false unless pending?

    update!(status: "processing")

    # Simulate payment processing delay
    PaymentProcessingJob.perform_later(id)
  end

  def complete_payment!
    return false unless processing?

    transaction do
      update!(
        status: "completed",
        paid_at: Time.current,
        payment_metadata: (payment_metadata || {}).merge({
          completed_at: Time.current,
          processed_by: "system"
        })
      )

      # Check if loan is fully paid
      if loan.remaining_balance <= 0
        loan.mark_as_paid!
      end
    end
  end

  def fail_payment!(reason = nil)
    update!(
      status: "failed",
      payment_metadata: (payment_metadata || {}).merge({
        failed_at: Time.current,
        failure_reason: reason || "Payment processing failed"
      })
    )
  end

  def refund_payment!(reason = nil)
    return false unless completed?

    update!(
      status: "refunded",
      payment_metadata: (payment_metadata || {}).merge({
        refunded_at: Time.current,
        refund_reason: reason || "Payment refunded"
      })
    )
  end

  def payment_fee
    case payment_method
    when "gcash", "paymaya"
      [ amount * 0.02, 10 ].max # 2% with minimum 10 pesos
    when "bank_transfer"
      15 # Flat 15 pesos
    when "online_banking"
      [ amount * 0.015, 5 ].max # 1.5% with minimum 5 pesos
    else
      0
    end
  end

  def net_amount
    amount - payment_fee
  end

  def is_full_payment?
    amount >= loan.remaining_balance
  end

  def is_partial_payment?
    amount < loan.remaining_balance && amount > 0
  end

  private

  def generate_payment_reference
    loop do
      self.payment_reference = "PAY#{Time.current.strftime('%Y%m%d')}#{SecureRandom.alphanumeric(8).upcase}"
      break unless Payment.exists?(payment_reference: payment_reference)
    end
  end

  def update_loan_status
    case status
    when "completed"
      # Update loan if fully paid
      if loan.remaining_balance <= 0
        loan.mark_as_paid!
      end
    when "failed"
      # Could implement retry logic or notification here
      Rails.logger.info "Payment #{payment_reference} failed for loan #{loan.id}"
    end
  end
end
