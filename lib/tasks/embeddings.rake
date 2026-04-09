namespace :embeddings do
  desc "Generate embeddings for a translation, e.g. rake embeddings:generate[spa-rv1909]"
  task :generate, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rake embeddings:generate[spa-rv1909]" unless identifier

    translation = Translation.find_by!(identifier: identifier)
    remaining = Verse.where(translation: translation, embedding: nil).count

    if remaining == 0
      puts "All verses for #{identifier} already have embeddings."
      next
    end

    puts "Generating embeddings for #{remaining} verses of #{identifier}..."
    puts "Model: #{EmbeddingService::MODEL}"
    puts "Estimated cost: ~$#{(remaining * 20.0 / 1_000_000 * 0.02).round(4)}"
    puts

    done = 0
    Verse.where(translation: translation, embedding: nil)
         .find_in_batches(batch_size: 500) do |batch|
      texts = batch.map(&:text)
      vectors = EmbeddingService.embed_batch(texts)

      batch.each_with_index do |verse, i|
        verse.update_column(:embedding, vectors[i].to_s)
      end

      done += batch.size
      puts "  #{done}/#{remaining} verses embedded"
    end

    indexed = Verse.where(translation: translation).with_embedding.count
    puts "\nDone! #{indexed} verses with embeddings for #{identifier}."
  end

  desc "Clear embeddings for a translation, e.g. rake embeddings:clear[spa-rv1909]"
  task :clear, [ :identifier ] => :environment do |_t, args|
    identifier = args[:identifier]
    abort "Usage: rake embeddings:clear[spa-rv1909]" unless identifier

    translation = Translation.find_by!(identifier: identifier)
    count = Verse.where(translation: translation).update_all(embedding: nil)
    puts "Cleared embeddings for #{count} verses of #{identifier}."
  end
end
