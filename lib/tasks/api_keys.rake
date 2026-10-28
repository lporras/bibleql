# frozen_string_literal: true

module ApiKeyTasks
  # Prefixes are only 12 characters, so with many installation keys more than one active key
  # can share one; refuse to guess.
  def self.find_active_key_by_prefix!(prefix, task_name)
    abort("Usage: rake api_keys:#{task_name}[prefix]") if prefix.blank?

    keys = ApiKey.active.where(token_prefix: prefix).to_a
    abort("No active API key with prefix #{prefix}.") if keys.empty?
    abort("#{keys.size} active keys share prefix #{prefix}; use the admin panel instead.") if keys.size > 1

    keys.first
  end
end

namespace :api_keys do
  desc "Create a new API key. Usage: rake api_keys:create[name,email,environment]"
  task :create, [ :name, :email, :environment ] => :environment do |_t, args|
    name = args[:name] || abort("Usage: rake api_keys:create[name,email,environment]")
    email = args[:email] || abort("Email is required")
    environment = args[:environment] || "test"

    api_key = ApiKey.create!(name: name, email: email, environment: environment)

    puts "\nAPI Key created successfully!"
    puts "  Name:        #{api_key.name}"
    puts "  Email:       #{api_key.email}"
    puts "  Environment: #{api_key.environment}"
    puts "  Prefix:      #{api_key.token_prefix}"
    puts ""
    puts "  Token: #{api_key.token}"
    puts ""
    puts "  Save this token securely — it will not be shown again."
  end

  desc "Revoke an API key by prefix. Usage: rake api_keys:revoke[prefix]"
  task :revoke, [ :prefix ] => :environment do |_t, args|
    prefix = args[:prefix] || abort("Usage: rake api_keys:revoke[prefix]")
    api_key = ApiKey.find_by!(token_prefix: prefix)

    if api_key.revoked?
      puts "API key #{prefix} is already revoked."
    else
      api_key.revoke!
      puts "API key #{prefix} (#{api_key.name}) has been revoked."
    end
  end

  # Deprecated keys keep working under the same daily limit, but every
  # response carries extensions.updateRequired. Use for the old shared reader key once the
  # per-installation release has shipped.
  desc "Mark an active API key deprecated. Usage: rake api_keys:deprecate[prefix]"
  task :deprecate, [ :prefix ] => :environment do |_t, args|
    api_key = ApiKeyTasks.find_active_key_by_prefix!(args[:prefix], "deprecate")
    api_key.update!(deprecated: true)
    puts "API key #{api_key.token_prefix} (#{api_key.name}) is now deprecated: " \
      "clients will be told to update."
  end

  desc "Clear the deprecated flag on an active API key. Usage: rake api_keys:undeprecate[prefix]"
  task :undeprecate, [ :prefix ] => :environment do |_t, args|
    api_key = ApiKeyTasks.find_active_key_by_prefix!(args[:prefix], "undeprecate")
    api_key.update!(deprecated: false)
    puts "API key #{api_key.token_prefix} (#{api_key.name}) is no longer deprecated."
  end

  desc "List API keys (KIND=developer|installation to filter)"
  task list: :environment do
    keys = ApiKey.order(:created_at)
    keys = keys.where(kind: ENV["KIND"]) if ENV["KIND"].present?

    if keys.empty?
      puts "No API keys found."
      next
    end

    printf "%-14s %-20s %-30s %-12s %-6s %8s %-20s %-10s\n",
      "PREFIX", "NAME", "EMAIL", "KIND", "ENV", "REQUESTS", "LAST USED", "STATUS"
    puts "-" * 143

    keys.find_each do |key|
      status = if key.revoked? then "revoked"
      elsif key.deprecated? then "deprecated"
      else "active"
      end
      last_used = key.last_used_at&.strftime("%Y-%m-%d %H:%M") || "never"

      printf "%-14s %-20s %-30s %-12s %-6s %8d %-20s %-10s\n",
        key.token_prefix, key.name.truncate(20), key.email.to_s.truncate(30), key.kind,
        key.environment, key.requests_count, last_used, status
    end
  end
end
