class ApiKeyRequestsController < ApplicationController
  def new
    @api_key_request = ApiKeyRequest.new
  end

  def success
    @email = params[:email]
  end

  def create
    @api_key_request = ApiKeyRequest.new(api_key_request_params)
    @api_key_request.environment = ApiKey.expected_environment

    if @api_key_request.save
      redirect_to success_api_key_requests_path(email: @api_key_request.email)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def api_key_request_params
    params.require(:api_key_request).permit(:name, :email, :description)
  end
end
