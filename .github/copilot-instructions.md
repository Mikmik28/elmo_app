# eLMO Digital Lending Platform - AI Coding Instructions

## Architecture Overview

eLMO is a **Rails 8 microfinance platform** providing quick loans (₱1K-₱50K, 1-60 days) with gamified credit building. Built on modern Rails defaults with PostgreSQL, Solid Queue/Cache/Cable, and Hotwire.

### Core Business Flow

1. **User onboarding** → KYC verification → Credit scoring
2. **Loan application** → AI approval via `CreditScoringService` → Disbursement
3. **Payment processing** → Credit limit increases → Repeat lending

### Key Domain Models & Relationships

- `User` (has referral system, credit limits, payment history scoring)
- `Loan` (state machine: pending→approved→disbursed→paid/overdue/defaulted)
- `Payment` (tracks partial/full payments with external gateway integration)
- `PromoCode` (referral bonuses, discount mechanics)

## Development Workflows

### Starting Development

```bash
bin/dev  # Starts rails server + tailwind watcher via Procfile.dev
```

### Database Operations

```bash
rails db:seed    # Creates sample users/loans for testing
rails db:migrate # Standard migrations
```

### Background Jobs (Solid Queue)

- Jobs are processed automatically with `rails server`
- Monitor via Sidekiq web UI at `/sidekiq` (configured in routes)
- Key jobs: `LoanApprovalJob`, `DailyLoanMonitoringJob`, `PaymentProcessingJob`

## Critical Patterns & Conventions

### State Management

- **Loans**: Use instance methods like `approve!`, `disburse!`, `mark_as_paid!` for state transitions
- **Payments**: Status updates trigger loan status checks via `after_update` callbacks
- **Users**: Credit score recalculation happens automatically on loan status changes

### Financial Calculations

- **Interest**: Simple interest using `amount * (interest_rate/100) * (term_days/365)`
- **Penalties**: Daily penalty rate (0.5%) applied to overdue amounts
- **Credit scoring**: Multi-factor algorithm in `CreditScoringService` (payment history 35%, utilization 30%, etc.)

### Business Logic Services

- `CreditScoringService.new(user).loan_approval_decision(amount)` - Returns approval status, recommended amount, interest rate
- Use service classes for complex business logic, keep models focused on data integrity

### Payment Integration Points

- Payment methods: `gcash`, `paymaya`, `bank_transfer`, `cash`, `online_banking`
- Webhook handling at `/webhooks/payments/:payment_reference`
- Payment references auto-generated as `PAY{YYYYMMDD}{8-char-code}`

## Rails 8 Specific Patterns

### Background Processing

- Uses **Solid Queue** (not Sidekiq in production) - jobs stored in database
- Job configuration in `config/application.rb`: `config.active_job.queue_adapter = :sidekiq` (dev only)

### Asset Pipeline

- **Propshaft** for assets (not Sprockets)
- **Tailwind CSS** with `bin/rails tailwindcss:watch` for development
- **Importmap** for JavaScript (no npm build step needed)

### Real-time Features

- Uses **Solid Cable** for WebSocket connections
- Hotwire Turbo Streams for dynamic updates

## Testing & Quality

### Model Testing Focus

- Credit scoring accuracy with different user profiles
- Loan state transitions and business rule validation
- Payment processing with partial/full payment scenarios
- Referral bonus calculations

### External Dependencies

- SMS via Twilio (`twilio-ruby` gem)
- Payment gateways require sandbox credentials in `.env`
- Database indexing on `loans(user_id, status)`, `loans(due_date)` for performance

## Security & Compliance

### Data Protection

- Sensitive fields in `approval_metadata` and `payment_metadata` JSON columns
- KYC documents stored in `kyc_documents` JSON field
- Use `audited` gem for financial transaction trails

### Authentication & Authorization

- **Devise** for authentication
- **Pundit** for authorization (not fully implemented yet)
- Admin access to Sidekiq web UI needs protection

## Common Development Patterns

### Adding New Loan Types

1. Update `loan_type` enum in `Loan` model
2. Adjust scoring factors in `CreditScoringService`
3. Add business rules in `can_be_approved?`

### Payment Gateway Integration

1. Create service class in `app/services/payments/`
2. Implement webhook handler in `PaymentsController#webhook`
3. Add payment method to enum and fee calculation

### Credit Limit Adjustments

- Automatic increases in `Loan#mark_as_paid!` (10% of loan amount)
- Referral bonuses in `User#apply_referral_bonus` (₱500 referrer, ₱250 referee)

## Performance Considerations

### Database Queries

- Eager load associations: `user.loans.includes(:payments)`
- Use scopes for common filters: `Loan.overdue`, `User.eligible_for_loan`
- Payment history calculations can be expensive - consider caching

### Background Job Patterns

- Use `perform_later` for non-critical tasks
- Daily monitoring job runs via cron/scheduler
- Avoid heavy calculations in request/response cycle

## Debugging Tips

### Loan State Issues

- Check `approval_metadata` JSON for scoring details
- Use `rails console` to test `CreditScoringService` with real user data
- Monitor overdue loans with `Loan.overdue.includes(:user)`

### Payment Problems

- Check `payment_metadata` for gateway responses
- Verify webhook endpoint accessibility
- Test payment reference uniqueness constraints
