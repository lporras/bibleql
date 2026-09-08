namespace :holy_bible_xml do
  desc "Import all translations from db/holy-bible-xml/ (skips identifiers already imported)"
  task import: :environment do
    HolyBibleXmlImporter.import_all
    puts "\nImport complete!"
    puts "Translations: #{Translation.count}"
    puts "Verses: #{Verse.count}"
  end

  desc "Import a single db/holy-bible-xml/ translation by derived identifier, e.g. rake holy_bible_xml:import_one[ara-svd]"
  task :import_one, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rake holy_bible_xml:import_one[ara-svd]" unless identifier

    HolyBibleXmlImporter.import_one(identifier)
  rescue HolyBibleXmlImporter::Error => e
    abort e.message
  end
end
