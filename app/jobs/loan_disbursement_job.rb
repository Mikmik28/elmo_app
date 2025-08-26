class LoanDisbursementJob < ApplicationJob
  queue_as :default

  def perform(loan_id, disbursement_method, disbursement_account)
    loan = Loan.find(loan_id)
    return unless loan.approved?

    begin
      case disbursement_method
      when "gcash"
        disburse_via_gcash(loan, disbursement_account)
      when "paymaya"
        disburse_via_paymaya(loan, disbursement_account)
      when "bank_transfer"
        disburse_via_bank_transfer(loan, disbursement_account)
      else
        raise "Unsupported disbursement method: #{disbursement_method}"
      end

      loan.disburse!(disbursement_method, disbursement_account)

      # Schedule monitoring for this loan
      DailyLoanMonitoringJob.set(wait: 1.day).perform_later(loan.id)

      # Send confirmation notification
      LoanDisbursementNotificationJob.perform_later(loan.id)

      Rails.logger.info "Loan #{loan.id} disbursed successfully via #{disbursement_method}"

    rescue StandardError => e
      Rails.logger.error "Loan disbursement failed for loan #{loan.id}: #{e.message}"

      # Update loan with disbursement failure
      loan.update!(
        approval_metadata: loan.approval_metadata.merge({
          disbursement_failed: true,
          disbursement_failure_reason: e.message,
          disbursement_failure_timestamp: Time.current.iso8601
        })
      )

      # Notify admin of failure
      AdminNotificationJob.perform_later(
        "Loan Disbursement Failed",
        "Loan ##{loan.id} disbursement failed: #{e.message}"
      )
    end
  end

  private

  def disburse_via_gcash(loan, gcash_number)
    # Simulate GCash disbursement API
    response = simulate_gcash_disbursement(loan.amount, gcash_number)

    if response[:success]
      Rails.logger.info "GCash disbursement successful: #{response[:reference_number]}"
    else
      raise "GCash disbursement failed: #{response[:error]}"
    end
  end

  def disburse_via_paymaya(loan, paymaya_account)
    # Simulate PayMaya disbursement API
    response = simulate_paymaya_disbursement(loan.amount, paymaya_account)

    if response[:success]
      Rails.logger.info "PayMaya disbursement successful: #{response[:transaction_id]}"
    else
      raise "PayMaya disbursement failed: #{response[:error]}"
    end
  end

  def disburse_via_bank_transfer(loan, bank_account)
    # Simulate bank transfer disbursement
    response = simulate_bank_disbursement(loan.amount, bank_account)

    if response[:success]
      Rails.logger.info "Bank transfer disbursement successful: #{response[:transfer_id]}"
    else
      raise "Bank transfer disbursement failed: #{response[:error]}"
    end
  end

  # Simulation methods (replace with actual API calls)
  def simulate_gcash_disbursement(amount, gcash_number)
    # Simulate 95% success rate
    if rand < 0.95
      {
        success: true,
        reference_number: "GCD#{Time.current.to_i}#{rand(1000..9999)}",
        amount: amount,
        recipient: gcash_number
      }
    else
      {
        success: false,
        error: "Recipient account not found or insufficient funds in disbursement account"
      }
    end
  end

  def simulate_paymaya_disbursement(amount, paymaya_account)
    # Simulate 90% success rate
    if rand < 0.90
      {
        success: true,
        transaction_id: "PMD#{Time.current.to_i}#{rand(1000..9999)}",
        amount: amount,
        recipient: paymaya_account
      }
    else
      {
        success: false,
        error: "PayMaya disbursement service temporarily unavailable"
      }
    end
  end

  def simulate_bank_disbursement(amount, bank_account)
    # Simulate 98% success rate for bank transfers
    if rand < 0.98
      {
        success: true,
        transfer_id: "BTD#{Time.current.to_i}#{rand(1000..9999)}",
        amount: amount,
        recipient: bank_account
      }
    else
      {
        success: false,
        error: "Invalid bank account details"
      }
    end
  end
end
