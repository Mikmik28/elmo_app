class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_user!

  respond_to :json

  private

  def authenticate_api_user!
    token = request.headers["Authorization"]&.split(" ")&.last

    if token.blank?
      render json: { error: "Missing authorization token" }, status: :unauthorized
      return
    end

    # Simple token-based authentication (you might want to use JWT)
    @current_user = User.find_by(authentication_token: token)

    unless @current_user
      render json: { error: "Invalid authorization token" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def render_error(message, status = :unprocessable_entity)
    render json: {
      error: message,
      status: "error"
    }, status: status
  end

  def render_success(data = {}, message = "Success")
    render json: {
      status: "success",
      message: message,
      data: data
    }
  end
end
