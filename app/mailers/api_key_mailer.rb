class ApiKeyMailer < ApplicationMailer
  def key_approved(api_key_request, plaintext_token)
    @api_key_request = api_key_request
    @token = plaintext_token

    mail(to: api_key_request.email, subject: "Your BibleQL API Key is Ready")
  end

  def key_rejected(api_key_request)
    @api_key_request = api_key_request

    mail(to: api_key_request.email, subject: "BibleQL API Key Request Update")
  end
end
