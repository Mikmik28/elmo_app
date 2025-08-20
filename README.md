# eLMO (Loan More App) - Digital Lending Platform

![eLMO Logo](https://via.placeholder.com/150x50/007BFF/FFFFFF?text=eLMO)

## 📋 Project Overview

eLMO (Enhanced Loan More Operations) is a modern digital lending platform built with Rails 8, designed to provide quick, accessible microloans to underbanked populations. Similar to platforms like Tala and Billease, eLMO offers flexible loan terms with competitive interest rates and a gamified credit-building experience.

### 🎯 Key Features

- **Instant Loan Approval**: AI-powered credit scoring for rapid decision-making
- **Three-Tier Loan Products**: Micro (1-60 days, 0.5% daily), Extended (3-6 months, 3.49% monthly), and Long-term (9-12 months, 3% monthly)
- **Dynamic Credit Limits**: Starting at ₱5,000, expandable up to ₱50,000 based on payment history
- **Smart Credit Growth**: Automatic credit limit increases for users who borrow and repay ≥₱5,000 within 2 months
- **Referral System**: Integrated promo codes and referral rewards
- **Multi-Payment Support**: GCash, PayMaya, bank transfers, and over-the-counter payments
- **Real-time Calculations**: Interactive loan calculator with instant payment breakdowns

## 🛠 Technology Stack

- **Backend**: Ruby on Rails 8.0+ with PostgreSQL 16+
- **Frontend**: Hotwire (Turbo + Stimulus) with Tailwind CSS
- **Background Jobs**: Solid Queue (Rails 8 default)
- **Caching**: Solid Cache (Rails 8 default)
- **Real-time**: Solid Cable + Turbo Streams (Rails 8 default)
- **Asset Pipeline**: Propshaft (Rails 8 default)
- **Authentication**: Devise + Pundit
- **Payments**: Integration-ready for GCash, PayMaya, local banks
- **Deployment**: Kamal 2 (containerized, zero-downtime)
- **Monitoring**: Sentry/Honeybadger + New Relic

## 🏗 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │    │   Mobile API    │    │   Admin Panel   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Rails 8 App    │
                    │  (Hotwire)      │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │  Solid Queue    │    │   Solid Cache   │
│   (Primary DB)  │    │ (Background     │    │   (Redis-free   │
│                 │    │  Jobs)          │    │   Caching)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 💰 Business Model

### Interest Rate Structure

- **Micro Loans (1-60 days)**: 0.5% daily interest rate
- **Extended Loans (61-180 days)**: 3.49% monthly interest rate
- **Long-term Loans (9-12 months only)**: 3% monthly interest rate
- **Penalty Rate**: 0.5% daily for overdue amounts (all loan types)
- **No Hidden Fees**: Transparent pricing with upfront calculations

### Competitive Analysis

| Feature           | eLMO          | Billease           | Tala       |
| ----------------- | ------------- | ------------------ | ---------- |
| Micro Rate        | 0.5% daily    | N/A                | 0.5% daily |
| Extended Rate     | 3.49% monthly | 3% + 3.49% monthly | N/A        |
| Long-term Rate    | 3% monthly    | N/A                | N/A        |
| Max Term          | 12 months     | 6 months           | 60 days    |
| Term Options      | Fixed tiers   | Flexible           | Flexible   |
| Credit Limit      | ₱5K-₱50K      | Varies             | Varies     |
| Auto-Increase     | ✅ Yes        | ❌ No              | ❌ No      |
| Three-Tier System | ✅ Yes        | ❌ No              | ❌ No      |
| Referral Program  | ✅ Yes        | Limited            | Limited    |

## 🚀 Quick Start

### Prerequisites

- Ruby 3.2+
- PostgreSQL 16+
- Node.js 18+
- Redis (for development only)

### Installation

```bash
# Clone the repository
git clone https://github.com/Mikmik28/elmo_app.git
cd elmo_app

# Install dependencies
bundle install
npm install

# Setup database
rails db:create
rails db:migrate
rails db:seed

# Start the development server
bin/dev
```

### Environment Setup

Create a `.env` file in the root directory:

```env
DATABASE_URL=postgresql://username:password@localhost/elmo_development
REDIS_URL=redis://localhost:6379/0
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
SECRET_KEY_BASE=your_secret_key_base
GCASH_API_KEY=your_gcash_api_key
PAYMAYA_PUBLIC_KEY=your_paymaya_public_key
PAYMAYA_SECRET_KEY=your_paymaya_secret_key
```

## 📊 Database Schema

### Core Entities

```mermaid
erDiagram
    USERS ||--o{ LOANS : has
    USERS ||--o{ PAYMENTS : makes
    LOANS ||--o{ PAYMENTS : receives
    USERS ||--o{ PROMO_CODES : uses

    USERS {
        bigint id PK
        string email UK
        string phone_number UK
        string first_name
        string last_name
        decimal credit_limit
        integer credit_score
        string status
        string referral_code UK
        boolean kyc_verified
    }

    LOANS {
        bigint id PK
        bigint user_id FK
        decimal amount
        decimal interest_rate
        decimal total_amount_due
        integer term_days
        date due_date
        string status
        datetime approved_at
        datetime disbursed_at
    }

    PAYMENTS {
        bigint id PK
        bigint loan_id FK
        bigint user_id FK
        decimal amount
        string payment_method
        string status
        datetime paid_at
    }
```

## 🔐 Security Features

- **KYC Verification**: Document upload and verification workflow
- **Fraud Detection**: AI-powered risk assessment
- **Data Encryption**: Sensitive data encryption at rest and in transit
- **Rate Limiting**: API rate limiting to prevent abuse
- **Audit Trails**: Complete audit logging for all financial transactions
- **PCI Compliance**: Payment processing follows PCI DSS standards

## 📱 API Documentation

### Authentication

All API endpoints require authentication via Bearer token.

```bash
# Login
curl -X POST /api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'
```

### Loan Application

```bash
# Apply for loan
curl -X POST /api/v1/loans \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 5000,
    "term_days": 30,
    "purpose": "emergency",
    "disbursement_method": "gcash",
    "disbursement_account": "09171234567"
  }'
```

## 🎯 Project Goals & Milestones

### Phase 1: MVP (Weeks 1-8)

- [x] Rails 8 application setup
- [x] Core database schema
- [x] User authentication with Devise
- [ ] Basic loan application flow
- [ ] Credit scoring engine
- [ ] Payment processing framework
- [ ] Admin dashboard

### Phase 2: Core Features (Weeks 9-16)

- [ ] Mobile-responsive UI with Hotwire
- [ ] Real-time loan calculator
- [ ] Payment gateway integrations (GCash, PayMaya)
- [ ] SMS notifications via Twilio
- [ ] Referral system implementation
- [ ] Credit limit auto-increase logic

### Phase 3: Advanced Features (Weeks 17-24)

- [ ] Mobile API for native apps
- [ ] Advanced fraud detection
- [ ] Machine learning credit scoring
- [ ] Automated collections system
- [ ] Business intelligence dashboard
- [ ] A/B testing framework

### Phase 4: Scale & Growth (Weeks 25-52)

- [ ] Multi-tenant architecture
- [ ] Regional expansion features
- [ ] Advanced financial products
- [ ] Partnership integrations
- [ ] Compliance automation
- [ ] Advanced analytics

## 📈 Business Metrics & KPIs

### Growth Metrics

- **User Acquisition Rate**: Target 1,000 new users/month by Month 6
- **Loan Volume**: Target ₱10M total disbursed by Month 12
- **Default Rate**: Maintain <5% default rate
- **Customer Lifetime Value**: Target ₱2,500 CLV
- **Credit Limit Utilization**: Target 60% average utilization

### Revenue Targets

- Month 1-2: ₱0-5K (MVP testing)
- Month 3-4: ₱5K-25K (Initial traction)
- Month 5-6: ₱25K-75K (Growth phase)
- Month 7-12: ₱75K-300K (Scale phase)

## 🤝 Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow Ruby Style Guide
- Use Rubocop for linting
- Write tests for all new features
- Maintain >90% test coverage
- Document all public APIs

## 📝 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 📞 Support & Contact

- **Developer**: Mikmik28
- **Email**: developer@elmo-app.com
- **GitHub**: [@Mikmik28](https://github.com/Mikmik28)
- **Project Board**: [GitHub Projects](https://github.com/Mikmik28/elmo_app/projects)

## 🙏 Acknowledgments

- Rails 8 team for the amazing opinionated defaults
- Hotwire team for making modern web development enjoyable
- Tala and Billease for inspiration in the digital lending space
- Philippine fintech community for market insights

---

**Last Updated**: 2025-08-20 17:56:44 UTC  
**Version**: 1.0.0  
**Status**: In Development
