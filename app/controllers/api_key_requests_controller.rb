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
      auto_approve(@api_key_request)
      redirect_to success_api_key_requests_path(email: @api_key_request.email)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def auto_approve(api_key_request)
    ApiKeyRequest.transaction do
      api_key = api_key_request.approve!
      ApiKeyMailer.key_approved(api_key_request, api_key.token).deliver_now
    end
  rescue => e
    Rails.logger.error("Auto-approve failed for request ##{api_key_request.id}: #{e.message}")
    api_key_request.reload.reject!("Auto-approval failed: email delivery error")
  end

  def api_key_request_params
    params.require(:api_key_request).permit(:name, :email, :description)
  end
end
