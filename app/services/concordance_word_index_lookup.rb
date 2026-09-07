class ConcordanceWordIndexLookup
  MAX_PAGE_SIZE = 200
  DEFAULT_PAGE_SIZE = 50

  def initialize(translation:, prefix: nil, min_occurrences: 1)
    @translation = translation
    @prefix = prefix.to_s.strip.downcase
    @min_occurrences = [ min_occurrences || 1, 1 ].max
  end

  def call(first: DEFAULT_PAGE_SIZE)
    first = first.clamp(1, MAX_PAGE_SIZE)
    Rails.cache.fetch(cache_key(first)) { scope.limit(first).to_a }
  end

  private

  def scope
    s = ConcordanceWordIndex.where(translation_id: @translation.id)
      .where("total_occurrences >= ?", @min_occurrences)
      .order(:lemma)
    s = s.where("lemma LIKE ?", "#{ConcordanceWordIndex.sanitize_sql_like(@prefix)}%") if @prefix.present?
    s
  end

  def cache_key(first)
    [ "concordance_index", "v1", @translation.identifier, @translation.concordance_indexed_at&.to_i,
      @prefix, @min_occurrences, first ].compact.join(":")
  end
end
