import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "termDays", "interestRate", "totalDue", "dailyPayment"]
  static values = { 
    userCreditScore: Number,
    maxAmount: Number 
  }

  connect() {
    this.calculate()
  }

  calculate() {
    const amount = parseFloat(this.amountTarget.value) || 0
    const termDays = parseInt(this.termDaysTarget.value) || 30
    
    if (amount <= 0 || termDays <= 0) {
      this.clearResults()
      return
    }

    // Calculate interest rate based on credit score (simplified)
    let interestRate = this.calculateInterestRate(this.userCreditScoreValue)
    
    // Calculate total amount due
    const interestAmount = amount * (interestRate / 100) * (termDays / 365)
    const totalDue = amount + interestAmount
    const dailyPayment = totalDue / termDays

    // Update display
    if (this.hasInterestRateTarget) {
      this.interestRateTarget.textContent = `${interestRate.toFixed(2)}%`
    }
    
    if (this.hasTotalDueTarget) {
      this.totalDueTarget.textContent = `₱${this.formatNumber(totalDue.toFixed(2))}`
    }
    
    if (this.hasDailyPaymentTarget) {
      this.dailyPaymentTarget.textContent = `₱${this.formatNumber(dailyPayment.toFixed(2))}`
    }

    // Validate amount
    this.validateAmount(amount)
  }

  calculateInterestRate(creditScore) {
    if (creditScore >= 750) return 4.0
    if (creditScore >= 700) return 6.0
    if (creditScore >= 650) return 8.0
    if (creditScore >= 600) return 12.0
    if (creditScore >= 550) return 15.0
    if (creditScore >= 500) return 18.0
    if (creditScore >= 450) return 20.0
    return 25.0
  }

  validateAmount(amount) {
    const amountInput = this.amountTarget
    
    if (amount > this.maxAmountValue) {
      amountInput.classList.add("border-red-500")
      this.showError(`Maximum loan amount is ₱${this.formatNumber(this.maxAmountValue)}`)
    } else {
      amountInput.classList.remove("border-red-500")
      this.hideError()
    }
  }

  showError(message) {
    let errorDiv = this.element.querySelector(".error-message")
    if (!errorDiv) {
      errorDiv = document.createElement("div")
      errorDiv.className = "error-message text-red-600 text-sm mt-2"
      this.amountTarget.parentNode.appendChild(errorDiv)
    }
    errorDiv.textContent = message
  }

  hideError() {
    const errorDiv = this.element.querySelector(".error-message")
    if (errorDiv) {
      errorDiv.remove()
    }
  }

  clearResults() {
    if (this.hasInterestRateTarget) this.interestRateTarget.textContent = "0%"
    if (this.hasTotalDueTarget) this.totalDueTarget.textContent = "₱0"
    if (this.hasDailyPaymentTarget) this.dailyPaymentTarget.textContent = "₱0"
  }

  formatNumber(num) {
    return parseFloat(num).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
