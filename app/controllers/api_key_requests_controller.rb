class ApiKeyRequestsController < ApplicationController
  # Set API_KEY_REQUESTS_PAUSED=true to close the form (e.g. while a bot is flooding it and
  # exhausting the email quota). Unset or any other value keeps the form open.
  def self.accepting_requests?
    !ActiveModel::Type::Boolean.new.cast(ENV["API_KEY_REQUESTS_PAUSED"])
  end
  helper_method def accepting_requests? = self.class.accepting_requests?

  def new
    @api_key_request = ApiKeyRequest.new
    set_meta_tags(
      title: "Get a Free Bible API Key",
      description: "Request a free API key for BibleQL, the open-source GraphQL Bible API. " \
                   "Access verses, passages, and chapters across 43+ translations."
    )
  end

  def success
    @email = params[:email]
    set_meta_tags(
      title: "Request Submitted",
      robots: "noindex, nofollow"
    )
  end

  def create
    unless accepting_requests?
      @api_key_request = ApiKeyRequest.new
      return render :new, status: :service_unavailable
    end

    @api_key_request = ApiKeyRequest.new(api_key_request_params)
    @api_key_request.environment = ApiKey.expected_environment

    # Before save, so a bot that fails the challenge never touches the database or sends email.
    unless human_verified?
      @api_key_request.errors.add(:base, "Please complete the verification challenge and try again.")
      return render :new, status: :unprocessable_content
    end

    # Looks like a bot: keep the record for review, but no key and no email. The redirect below
    # is the same as for a real request, so the bot can't tell it was caught.
    spam_check = ApiKeyRequestSpamCheck.new(@api_key_request, honeypot: params[:website])
    if spam_check.spam?
      @api_key_request.status = "rejected"
      @api_key_request.rejection_reason = "Flagged as spam: #{spam_check.reasons.join(', ')}"
    end

    if @api_key_request.save
      if spam_check.spam?
        Rails.logger.info("[spam] API key request ##{@api_key_request.id} flagged: #{spam_check.reasons.join(', ')}")
      else
        auto_approve(@api_key_request)
      end
      redirect_to success_api_key_requests_path(email: @api_key_request.email)
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def human_verified?
    return true unless TurnstileVerifier.enabled?

    TurnstileVerifier.new.verify(params["cf-turnstile-response"], remote_ip: ClientIp.for(request))
  end

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
