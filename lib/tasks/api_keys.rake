# frozen_string_literal: true

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

  desc "List all API keys"
  task list: :environment do
    keys = ApiKey.order(:created_at)

    if keys.empty?
      puts "No API keys found."
      next
    end

    printf "%-14s %-20s %-30s %-6s %8s %-20s %-10s\n",
      "PREFIX", "NAME", "EMAIL", "ENV", "REQUESTS", "LAST USED", "STATUS"
    puts "-" * 130

    keys.find_each do |key|
      status = key.revoked? ? "revoked" : "active"
      last_used = key.last_used_at&.strftime("%Y-%m-%d %H:%M") || "never"

      printf "%-14s %-20s %-30s %-6s %8d %-20s %-10s\n",
        key.token_prefix, key.name.truncate(20), key.email.truncate(30),
        key.environment, key.requests_count, last_used, status
    end
  end
end
