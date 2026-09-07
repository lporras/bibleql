class ConcordanceIndexer
  BATCH_SIZE = 5_000

  def initialize(translation)
    @translation = translation
    @config = TextSearchConfigResolver.for(translation.language)
  end

  def call
    @translation.update!(
      text_search_config: @config,
      has_stemming: TextSearchConfigResolver.stemming?(@translation.language)
    )

    populate_text_search
    populate_word_index

    @translation.update!(concordance_indexed_at: Time.current)
  end

  private

  def populate_text_search
    @translation.verses.in_batches(of: BATCH_SIZE) do |batch|
      batch.update_all([ "text_search = to_tsvector(?::regconfig, text)", @config ])
    end
  end

  # ts_stat takes a *SQL query string* as its argument, so we build and quote
  # an inner SELECT, then quote that string again as ts_stat's own argument.
  def populate_word_index
    inner_sql = "SELECT text_search FROM verses WHERE translation_id = #{@translation.id}"
    quoted_inner_sql = ActiveRecord::Base.connection.quote(inner_sql)

    ActiveRecord::Base.transaction do
      ConcordanceWordIndex.where(translation_id: @translation.id).delete_all
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO concordance_word_index
          (translation_id, lemma, verse_count, total_occurrences, created_at, updated_at)
        SELECT #{@translation.id}, s.word, s.ndoc, s.nentry, NOW(), NOW()
        FROM ts_stat(#{quoted_inner_sql}) s
      SQL
    end
  end
end
