namespace :concordance do
  desc "Build the concordance index for all translations, or one: rake \"concordance:index[spa-rv1909]\""
  task :index, [ :identifier ] => :environment do |_t, args|
    scope = args[:identifier] ? Translation.where(identifier: args[:identifier]) : Translation.order(:identifier)
    abort "No translation found for '#{args[:identifier]}'" if args[:identifier] && scope.none?

    scope.find_each do |translation|
      print "Indexing #{translation.identifier}... "
      ConcordanceIndexer.new(translation).call
      puts "done (#{translation.text_search_config}, stemming=#{translation.has_stemming})"
    end
  end

  desc "Show concordance indexing status per translation"
  task status: :environment do
    Translation.order(:identifier).find_each do |t|
      unindexed = t.verses.where(text_search: nil).count
      status = t.concordance_indexed_at&.iso8601 || "never"
      puts format("%-14s config=%-10s stemming=%-5s indexed_at=%-25s unindexed_verses=%d",
        t.identifier, t.text_search_config, t.has_stemming, status, unindexed)
    end
  end
end
