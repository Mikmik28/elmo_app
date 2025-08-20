# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "🌱 Seeding eLMO database..."

# Create admin user
admin = User.find_or_create_by!(email: 'admin@elmo.app') do |user|
  user.password = 'password123'
  user.first_name = 'Admin'
  user.last_name = 'User'
  user.phone_number = '+639171234567'
  user.status = 'verified'
  user.kyc_verified = true
  user.credit_limit = 1_000_000
  user.credit_score = 850
  user.monthly_income = 100_000
  user.employment_status = 'employed'
end

puts "✅ Created admin user: #{admin.email}"

# Create sample promo codes
promo_codes = [
  {
    code: 'WELCOME50',
    promo_type: 'credit_bonus',
    bonus_credit: 500,
    usage_limit: 100,
    valid_from: Date.current,
    valid_until: 3.months.from_now,
    conditions: { 'kyc_verified' => true }
  },
  {
    code: 'FIRSTLOAN',
    promo_type: 'interest_reduction',
    discount_percentage: 20,
    usage_limit: 1000,
    valid_from: Date.current,
    valid_until: 6.months.from_now,
    conditions: { 'max_previous_loans' => 0 }
  },
  {
    code: 'STUDENT15',
    promo_type: 'discount',
    discount_percentage: 15,
    usage_limit: 500,
    valid_from: Date.current,
    valid_until: 1.year.from_now,
    conditions: { 'employment_status' => 'student' }
  },
  {
    code: 'LOYALTY25',
    promo_type: 'credit_bonus',
    bonus_credit: 2500,
    usage_limit: 50,
    valid_from: Date.current,
    valid_until: 1.year.from_now,
    conditions: { 'min_credit_score' => 700 }
  }
]

promo_codes.each do |promo_data|
  promo = PromoCode.find_or_create_by!(code: promo_data[:code]) do |p|
    p.assign_attributes(promo_data)
  end
  puts "✅ Created promo code: #{promo.code}"
end

# Create sample users with different profiles
sample_users = [
  {
    email: 'juan.delacruz@email.com',
    first_name: 'Juan',
    last_name: 'Dela Cruz',
    phone_number: '+639171234568',
    employment_status: 'employed',
    monthly_income: 25_000,
    credit_score: 650,
    status: 'verified',
    kyc_verified: true
  },
  {
    email: 'maria.santos@email.com',
    first_name: 'Maria',
    last_name: 'Santos',
    phone_number: '+639171234569',
    employment_status: 'self_employed',
    monthly_income: 35_000,
    credit_score: 720,
    status: 'verified',
    kyc_verified: true
  },
  {
    email: 'pedro.garcia@email.com',
    first_name: 'Pedro',
    last_name: 'Garcia',
    phone_number: '+639171234570',
    employment_status: 'employed',
    monthly_income: 45_000,
    credit_score: 580,
    status: 'verified',
    kyc_verified: true
  },
  {
    email: 'ana.reyes@email.com',
    first_name: 'Ana',
    last_name: 'Reyes',
    phone_number: '+639171234571',
    employment_status: 'student',
    monthly_income: 8_000,
    credit_score: 400,
    status: 'verified',
    kyc_verified: true
  }
]

sample_users.each do |user_data|
  user = User.find_or_create_by!(email: user_data[:email]) do |u|
    u.password = 'password123'
    u.assign_attributes(user_data.except(:email))
    u.date_of_birth = 25.years.ago.to_date
    u.address = 'Sample Address, Metro Manila'
  end
  puts "✅ Created user: #{user.full_name} (#{user.email})"
end

puts "🎉 eLMO database seeded successfully!"
puts ""
puts "Sample accounts created:"
puts "Admin: admin@elmo.app / password123"
puts "Users: juan.delacruz@email.com / password123"
puts "       maria.santos@email.com / password123"
puts "       pedro.garcia@email.com / password123"
puts "       ana.reyes@email.com / password123"
puts ""
puts "Promo codes available:"
puts "WELCOME50 - ₱500 credit bonus for new verified users"
puts "FIRSTLOAN - 20% interest reduction for first-time borrowers"
puts "STUDENT15 - 15% discount for students"
puts "LOYALTY25 - ₱2,500 credit bonus for high credit score users"
