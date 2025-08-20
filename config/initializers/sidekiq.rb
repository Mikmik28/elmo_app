require 'sidekiq/web'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Schedule recurring jobs
Sidekiq.configure_server do |config|
  scheduler = Sidekiq::Cron::Job.new(
    name: 'Daily Loan Monitoring',
    cron: '0 9 * * *', # Run daily at 9 AM
    class: 'DailyLoanMonitoringJob'
  )
  scheduler.save

  # Add more recurring jobs as needed
end if defined?(Sidekiq::Cron)
