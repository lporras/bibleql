# frozen_string_literal: true

class GraphqlController < ApplicationController
  include ApiAuthenticatable

  # The only root fields an unauthenticated request may select.
  UNAUTHENTICATED_ROOT_FIELDS = %w[registerInstallation __typename].freeze
  DEFAULT_UPDATE_MESSAGE = "This version of the app is out of date. Please update to keep using BibleQL."
  DEFAULT_UPDATE_URL = "https://github.com/lporras/bibleql-reader/releases"

  # Public API — skip CSRF for external clients (Apollo Sandbox, curl, etc.)
  skip_forgery_protection
  before_action :authenticate_api_key!, unless: :registration_request?
  before_action :enforce_daily_limit!, if: :current_api_key

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_api_key: current_api_key
    }
    result = BibleqlSchema.execute(query, variables: variables, context: context, operation_name: operation_name).to_h
    record_usage(result) if current_api_key
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # True only for a request with no Authorization header whose selected operation is a
  # mutation selecting nothing but registerInstallation. Requiring the header to be absent
  # keeps every registration inside Rack::Attack's "graphql/unauthenticated/ip" throttle.
  def registration_request?
    return false if request.headers["Authorization"].present?

    document = GraphQL.parse(params[:query].to_s)
    operations = document.definitions.grep(GraphQL::Language::Nodes::OperationDefinition)
    operation = if params[:operationName].present?
      operations.find { |op| op.name == params[:operationName] }
    elsif operations.one?
      operations.first
    end

    operation&.operation_type == "mutation" &&
      operation.selections.any? &&
      operation.selections.all? do |selection|
        selection.is_a?(GraphQL::Language::Nodes::Field) && UNAUTHENTICATED_ROOT_FIELDS.include?(selection.name)
      end
  rescue GraphQL::ParseError
    false
  end

  def enforce_daily_limit!
    quota = ApiKeyRateLimiter.check!(current_api_key)
    return if quota.allowed?

    response.headers["Retry-After"] = quota.retry_after.to_s
    render status: :too_many_requests, json: {
      errors: [ {
        message: "Daily request limit of #{quota.limit} exceeded for this API key. Retry after #{quota.retry_after} seconds.",
        extensions: { code: "RATE_LIMITED", retryAfter: quota.retry_after }
      } ]
    }
  end

  def record_usage(result)
    current_api_key.track_usage!
    current_api_key.installation&.touch_seen!(request.headers["X-App-Version"])
    flag_deprecated_key(result) if current_api_key.deprecated?
  end

  def flag_deprecated_key(result)
    Rails.logger.info(
      "[deprecated_api_key] prefix=#{current_api_key.token_prefix} ip=#{request.remote_ip} " \
      "user_agent=#{request.user_agent.to_s.truncate(200).inspect}"
    )

    result["extensions"] = (result["extensions"] || {}).merge(
      "updateRequired" => true,
      "message" => ENV["DEPRECATED_KEY_MESSAGE"].presence || DEFAULT_UPDATE_MESSAGE,
      "updateUrl" => ENV["READER_UPDATE_URL"].presence || DEFAULT_UPDATE_URL
    )
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end
end
