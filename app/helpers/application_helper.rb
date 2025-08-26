module ApplicationHelper
  def user_initials(user)
    first_initial = user.first_name&.strip&.first&.upcase || "?"
    last_initial = user.last_name&.strip&.first&.upcase || ""
    "#{first_initial}#{last_initial}"
  end
end
