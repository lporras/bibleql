namespace :bible do
  desc "Import all Bible translations from db/open-bibles/"
  task import: :environment do
    BibleImporter.import_all
    puts "\nImport complete!"
    puts "Translations: #{Translation.count}"
    puts "Books: #{Book.count}"
    puts "Book names: #{BookName.count}"
    puts "Verses: #{Verse.count}"
  end

  desc "Import a single Bible translation, e.g. rake bible:import_one[eng-web]"
  task :import_one, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rake bible:import_one[eng-web]" unless identifier

    file = Dir.glob("db/open-bibles/#{identifier}.*.xml").first
    abort "No file found for #{identifier}" unless file

    puts "Importing #{identifier}..."
    BibleImporter.new(file_path: file).import!
    translation = Translation.find_by!(identifier: identifier)
    puts "Done. Verses: #{translation.verses.count}"
  end

  desc "Update translation names/licenses from config/translations.yml, e.g. rake bible:update_metadata[eng-web] (DRY_RUN=1 to preview)"
  task :update_metadata, [ :identifier ] => :environment do |_t, args|
    dry_run = ENV["DRY_RUN"].present?
    puts "DRY RUN — nothing will be saved.\n\n" if dry_run

    result = TranslationMetadataSync.call(identifier: args[:identifier], dry_run: dry_run)

    result.updated.each do |change|
      puts change.translation.identifier
      change.changes.each { |attribute, (before, after)| puts "  #{attribute}: #{before.inspect} → #{after.inspect}" }
    end

    result.missing.each { |translation| puts "#{translation.identifier}: no metadata in config/translations.yml" }

    puts "\n#{result.summary}"
  end

  desc "Regenerate config/translations.yml from the db/open-bibles README"
  task generate_metadata: :environment do
    abort "db/open-bibles/README.md not found — run: git submodule update --init" unless File.exist?(TranslationMetadataGenerator::README_PATH)

    metadata = TranslationMetadataGenerator.new.call
    puts "Wrote #{metadata.size} translations to config/translations.yml"

    todo = metadata.select { |_identifier, data| data["note"].to_s.start_with?("TODO") }
    puts "\nUnrecognized licenses needing a manual entry: #{todo.keys.join(', ')}" if todo.any?
  end
end
