class ConcordanceLookup
  class InvalidCursorError < StandardError; end

  MAX_PAGE_SIZE = 100
  DEFAULT_PAGE_SIZE = 25
  HEADLINE_OPTIONS = "StartSel=<mark>, StopSel=</mark>, MaxWords=25, MinWords=10, " \
                     "MaxFragments=1, FragmentDelimiter= … "
  SURFACE_FORM_SAMPLE_SIZE = 100
  SURFACE_FORM_LIMIT = 10

  Result     = Struct.new(:entry, :edges, :total_count, :has_next_page, :end_cursor, keyword_init: true)
  Edge       = Struct.new(:node, :cursor, keyword_init: true)
  Occurrence = Struct.new(:verse, :context, keyword_init: true)
  Entry      = Struct.new(:lemma, :surface_forms, :total_occurrences, :verse_count,
                          :occurrences_by_book, :occurrences_by_testament, keyword_init: true)
  BookCount      = Struct.new(:book_id, :book_name, :count, keyword_init: true)
  TestamentCount = Struct.new(:old, :new, keyword_init: true)

  def initialize(translation:, word:, book: nil, testament: nil)
    @translation = translation
    @word = word.to_s.strip
    @book = book             # a Book record or nil — resolved by the caller
    @testament = testament   # "OT" / "NT" or nil — already mapped by the GraphQL enum
    @config = translation.text_search_config
  end

  def call(first: DEFAULT_PAGE_SIZE, after: nil)
    first = first.clamp(1, MAX_PAGE_SIZE)
    ttl = after.present? ? 1.hour : nil
    Rails.cache.fetch(cache_key("page:#{first}:#{after}"), expires_in: ttl) do
      fetch_page(first: first, after: after)
    end
  end

  private

  def fetch_page(first:, after:)
    relation = apply_cursor(ordered(with_context(scope)), after)
    rows = relation.preload(:book).limit(first + 1).to_a
    has_next = rows.size > first
    page_rows = rows.first(first)

    edges = page_rows.map do |verse|
      Edge.new(node: Occurrence.new(verse: verse, context: verse.context), cursor: encode_cursor(verse))
    end

    Result.new(entry: entry, edges: edges, total_count: total_count,
      has_next_page: has_next, end_cursor: edges.last&.cursor)
  end

  def scope
    s = base_scope
    s = s.where(book: @book) if @book
    s = s.where(books: { testament: @testament }) if @testament
    s
  end

  def base_scope
    @translation.verses.joins(:book)
      .where("verses.text_search @@ plainto_tsquery(?::regconfig, ?)", @config, @word)
  end

  def with_context(relation)
    relation.select(
      "verses.*",
      ActiveRecord::Base.sanitize_sql_array([
        "ts_headline(?::regconfig, verses.text, plainto_tsquery(?::regconfig, ?), ?) AS context",
        @config, @config, @word, HEADLINE_OPTIONS
      ])
    )
  end

  def ordered(relation)
    relation.order(Arel.sql("books.position ASC, verses.chapter ASC, verses.verse_number ASC"))
  end

  def encode_cursor(verse)
    Base64.urlsafe_encode64("#{verse.book.position}:#{verse.chapter}:#{verse.verse_number}")
  end

  def apply_cursor(relation, cursor)
    return relation if cursor.blank?
    pos, chapter, vnum = decode_cursor(cursor)
    relation.where("(books.position, verses.chapter, verses.verse_number) > (?, ?, ?)", pos, chapter, vnum)
  end

  def decode_cursor(cursor)
    Base64.urlsafe_decode64(cursor).split(":").map(&:to_i)
  rescue ArgumentError
    raise InvalidCursorError, "Invalid cursor: #{cursor.inspect}"
  end

  def entry
    Entry.new(
      lemma: lemma,
      surface_forms: surface_forms,
      total_occurrences: total_occurrences,
      verse_count: total_count,
      occurrences_by_book: counts_by_book,
      occurrences_by_testament: counts_by_testament
    )
  end

  def lemma
    @lemma ||= begin
      tsvector = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([ "SELECT to_tsvector(?::regconfig, ?)::text", @config, @word ])
      )
      first_lexeme = tsvector.to_s.split(" ").first.to_s.split(":").first
      first_lexeme.present? ? first_lexeme.delete("'") : @word.downcase
    end
  end

  def total_count
    Rails.cache.fetch(cache_key("total_count")) { scope.count }
  end

  # Raw token occurrences — can exceed verse_count if the word repeats within a verse.
  def total_occurrences
    Rails.cache.fetch(cache_key("total_occurrences")) do
      inner_sql = scope.select("verses.text_search").to_sql
      quoted_inner_sql = ActiveRecord::Base.connection.quote(inner_sql)
      quoted_lemma = ActiveRecord::Base.connection.quote(lemma)
      row = ActiveRecord::Base.connection.select_one(
        "SELECT COALESCE(SUM(nentry), 0) AS total FROM ts_stat(#{quoted_inner_sql}) WHERE word = #{quoted_lemma}"
      )
      row["total"].to_i
    end
  end

  def counts_by_book
    Rails.cache.fetch(cache_key("counts_by_book")) do
      names = localized_book_names
      scope.group("books.id", "books.book_id", "books.position")
        .order("books.position")
        .count
        .map { |(_pk, book_id, _pos), count| BookCount.new(book_id: book_id, book_name: names[book_id] || book_id, count: count) }
    end
  end

  def counts_by_testament
    Rails.cache.fetch(cache_key("counts_by_testament")) do
      rows = scope.group("books.testament").count
      TestamentCount.new(old: rows["OT"] || 0, new: rows["NT"] || 0)
    end
  end

  def localized_book_names
    @translation.book_names.joins(:book).pluck("books.book_id", "book_names.name").to_h
  end

  # Sampled from ts_headline's <mark> spans — cheap, reuses the KWIC machinery
  # already required for the connection, not an exhaustive dictionary lookup.
  def surface_forms
    Rails.cache.fetch(cache_key("surface_forms")) do
      with_context(scope).limit(SURFACE_FORM_SAMPLE_SIZE)
        .map(&:context)
        .flat_map { |html| html.to_s.scan(%r{<mark>(.*?)</mark>}i).flatten }
        .map(&:downcase)
        .tally
        .sort_by { |_word, count| -count }
        .first(SURFACE_FORM_LIMIT)
        .map(&:first)
    end
  end

  def cache_key(suffix)
    [
      "concordance", "v1", @translation.identifier, @translation.concordance_indexed_at&.to_i,
      Digest::SHA256.hexdigest(@word.downcase)[0, 16], @book&.book_id, @testament, suffix
    ].compact.join(":")
  end
end
