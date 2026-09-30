namespace :offline do
  desc "List offline-downloadable translations and their package status"
  task list: :environment do
    packages = OfflinePackage.where(schema_version: OfflinePackages::Builder::SCHEMA_VERSION).index_by(&:translation_id)
    translations = Translation.offline_downloadable.order(:identifier)
    puts "Storage: #{OfflinePackages.configured? ? 'configured' : 'NOT configured'}"
    puts "No translations are flagged offline_downloadable." if translations.none?

    translations.each do |translation|
      package = packages[translation.id]
      status = if package
        format("%.1f MB (%d verses) updated %s", package.size_bytes / 1_048_576.0, package.verse_count, package.updated_at.iso8601)
      else
        "not exported"
      end
      puts format("%-14s %s", translation.identifier, status)
    end
  end

  desc "Enqueue an export for one translation, e.g. rake \"offline:export_one[eng-web]\" (FORCE=1 skips the digest check)"
  task :export_one, [ :identifier ] => :environment do |_t, args|
    abort "Usage: rake \"offline:export_one[eng-web]\"" unless args[:identifier]
    abort "Storage not configured: set #{OfflinePackages::CONFIG_ENV.values.join(', ')}" unless OfflinePackages.configured?

    translation = Translation.find_by(identifier: args[:identifier]) or abort "No translation '#{args[:identifier]}'"
    abort "#{translation.identifier} is not offline_downloadable (rake \"offline:flag[#{translation.identifier},true]\")" unless translation.offline_downloadable?

    ExportOfflinePackageJob.perform_later(translation.id, force: ENV["FORCE"].present?)
    puts "Enqueued export of #{translation.identifier}. A worker must be running (bin/jobs or SOLID_QUEUE_IN_PUMA)."
  end

  desc "Enqueue exports for every offline-downloadable translation (FORCE=1 skips the digest check)"
  task export_all: :environment do
    abort "Storage not configured: set #{OfflinePackages::CONFIG_ENV.values.join(', ')}" unless OfflinePackages.configured?

    Translation.offline_downloadable.order(:identifier).each do |translation|
      ExportOfflinePackageJob.perform_later(translation.id, force: ENV["FORCE"].present?)
      puts "Enqueued #{translation.identifier}"
    end
  end

  desc "Flag one translation, e.g. rake \"offline:flag[eng-web,true]\""
  task :flag, [ :identifier, :value ] => :environment do |_t, args|
    abort "Usage: rake \"offline:flag[eng-web,true|false]\"" unless args[:identifier] && %w[true false].include?(args[:value])

    translation = Translation.find_by(identifier: args[:identifier]) or abort "No translation '#{args[:identifier]}'"
    translation.update!(offline_downloadable: args[:value] == "true")
    puts "#{translation.identifier}: offline_downloadable=#{translation.offline_downloadable}"
  end

  desc "Flag translations whose note says Public Domain; lists the rest for manual review (DRY_RUN=1 to preview)"
  task flag_public_domain: :environment do
    dry_run = ENV["DRY_RUN"].present?
    public_domain, other = Translation.order(:identifier).partition { |t| t.note.to_s.match?(/public domain/i) }

    puts "Public Domain#{' (dry run)' if dry_run}:"
    public_domain.each do |translation|
      translation.update!(offline_downloadable: true) unless dry_run
      puts "  #{translation.identifier}"
    end

    puts "\nNeeds manual review (use offline:flag):"
    other.each do |translation|
      puts format("  %-14s %-5s %s", translation.identifier, translation.offline_downloadable, translation.note.to_s.truncate(90))
    end
  end

  desc "Check the R2 credentials and public URL with a tiny probe object"
  task check_storage: :environment do
    require "net/http"
    abort "Storage not configured: set #{OfflinePackages::CONFIG_ENV.values.join(', ')}" unless OfflinePackages.configured?

    config = OfflinePackages.config
    client = OfflinePackages.s3_client
    key = "healthcheck/#{SecureRandom.hex(8)}.txt"
    body = "bibleql #{Time.current.iso8601}"

    client.head_bucket(bucket: config[:bucket])
    puts "✓ bucket #{config[:bucket]} reachable"
    client.put_object(bucket: config[:bucket], key: key, body: body, content_type: "text/plain")
    puts "✓ uploaded #{key}"

    url = "#{config[:public_base_url].chomp('/')}/#{key}"
    response = Net::HTTP.get_response(URI(url))
    if response.is_a?(Net::HTTPSuccess) && response.body == body
      puts "✓ public URL serves it: #{url}"
    else
      puts "✗ public URL returned #{response.code} for #{url} (is public access enabled on the bucket?)"
    end
  ensure
    client&.delete_object(bucket: config[:bucket], key: key) if key
  end
end
