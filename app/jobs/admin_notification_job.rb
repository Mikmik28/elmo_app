class AdminNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(subject, message)
    # In a real application, this would send email or SMS to admin
    Rails.logger.warn "ADMIN NOTIFICATION - #{subject}: #{message}"

    # Could also store in database for admin dashboard
    # AdminNotification.create!(subject: subject, message: message, created_at: Time.current)
  end
end
