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
end
