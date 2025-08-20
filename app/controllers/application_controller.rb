class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :first_name, :last_name, :phone_number, :date_of_birth, 
      :address, :employment_status, :monthly_income, :referred_by_code
    ])
    
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :first_name, :last_name, :phone_number, :date_of_birth, 
      :address, :employment_status, :monthly_income
    ])
  end

  def ensure_kyc_verified
    unless current_user.kyc_verified?
      redirect_to new_kyc_verification_path, alert: 'Please complete KYC verification to continue.'
    end
  end

  def ensure_account_verified
    unless current_user.verified?
      redirect_to account_verification_path, alert: 'Please verify your account to continue.'
    end
  end
end
