namespace :biblelist do
  desc "Import all translations from db/biblelist/"
  task import: :environment do
    BiblelistImporter.import_all
    puts "\nImport complete!"
    puts "Translations: #{Translation.count}"
    puts "Verses: #{Verse.count}"
  end

  desc "Import a single db/biblelist/ translation, e.g. rake biblelist:import_one[eng-niv]"
  task :import_one, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rake biblelist:import_one[eng-niv]\nAvailable: #{BiblelistImporter.identifiers.join(', ')}" unless identifier

    puts "Importing #{identifier}..."
    count = BiblelistImporter.new(identifier: identifier).import!
    puts "Done. Verses: #{count}"
  rescue BiblelistImporter::Error => e
    abort e.message
  end

  desc "List the db/biblelist/ translations and their import status"
  task list: :environment do
    imported = Translation.where(identifier: BiblelistImporter.identifiers).index_by(&:identifier)

    BiblelistImporter::CONFIG.each do |identifier, metadata|
      translation = imported[identifier]
      status = if translation
        "imported (#{translation.verses.count} verses)"
      elsif File.exist?(BiblelistImporter::DIRECTORY.join(metadata["file"]))
        "not imported"
      else
        "file missing"
      end

      puts format("%-10<id>s %-30<name>s %<status>s", id: identifier, name: metadata["name"], status: status)
    end
  end
end
