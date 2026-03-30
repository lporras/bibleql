# frozen_string_literal: true

class PassageLookup
  class NotFoundError < StandardError; end

  REFERENCE_PATTERN = /^(.+?)\s+(\d+)(?::(.+))?$/

  def initialize(translation_identifier:, reference:)
    @translation = Translation.find_by!(identifier: translation_identifier)
    @reference = reference.strip
  rescue ActiveRecord::RecordNotFound
    raise NotFoundError, "Translation '#{translation_identifier}' not found"
  end

  def call
    # Try localized name resolution first — this handles Spanish, German, etc.
    # Falls back to bible_ref for English names
    match = @reference.match(REFERENCE_PATTERN)

    if match && localized_book?(match[1])
      resolve_with_localized_name
    else
      ref = BibleRef::Reference.new(@reference)
      raise NotFoundError, "Invalid reference: '#{@reference}'" unless ref.valid?
      resolve_with_bible_ref(ref)
    end
  end

  private

  def localized_book?(name)
    @translation.book_names
      .where("LOWER(book_names.name) = ?", name.downcase)
      .exists?
  end

  def resolve_with_bible_ref(ref)
    ranges = ref.ranges
    verses = fetch_verses_from_ranges(ranges)
    build_passage(ref.normalize, verses)
  end

  def resolve_with_localized_name
    match = @reference.match(REFERENCE_PATTERN)
    raise NotFoundError, "Invalid reference format: '#{@reference}'" unless match

    book_name_str = match[1]
    chapter = match[2].to_i
    verse_part = match[3]

    book = find_book_by_localized_name(book_name_str)
    verse_ranges = parse_verse_part(verse_part)
    verses = fetch_verses_for_book(book, chapter, verse_ranges)
    reference_str = build_reference_string(book, chapter, verse_part)

    build_passage(reference_str, verses)
  end

  def find_book_by_localized_name(name)
    book_name = @translation.book_names
      .joins(:book)
      .where("LOWER(book_names.name) = ?", name.downcase)
      .first

    raise NotFoundError, "Book '#{name}' not found for translation '#{@translation.identifier}'" unless book_name

    book_name.book
  end

  def parse_verse_part(verse_part)
    return nil unless verse_part

    verse_part.split(",").map do |segment|
      segment = segment.strip
      if segment.include?("-")
        from, to = segment.split("-").map(&:to_i)
        (from..to)
      else
        segment.to_i..segment.to_i
      end
    end
  end

  def fetch_verses_from_ranges(ranges)
    all_verses = []

    ranges.each do |from_ref, to_ref|
      book = Book.find_by!(book_id: from_ref[:book])
      scope = Verse.includes(:book)
        .where(translation: @translation, book: book)

      if from_ref[:chapter] && from_ref[:verse]
        if from_ref[:chapter] == to_ref[:chapter]
          scope = scope.where(chapter: from_ref[:chapter], verse_number: from_ref[:verse]..to_ref[:verse])
        else
          scope = scope.where(
            "(chapter = ? AND verse_number >= ?) OR (chapter > ? AND chapter < ?) OR (chapter = ? AND verse_number <= ?)",
            from_ref[:chapter], from_ref[:verse],
            from_ref[:chapter], to_ref[:chapter],
            to_ref[:chapter], to_ref[:verse]
          )
        end
      elsif from_ref[:chapter]
        scope = scope.where(chapter: from_ref[:chapter])
      end

      all_verses.concat(scope.order(:chapter, :verse_number).to_a)
    end

    all_verses
  end

  def fetch_verses_for_book(book, chapter, verse_ranges)
    scope = Verse.includes(:book)
      .where(translation: @translation, book: book, chapter: chapter)

    if verse_ranges
      verse_numbers = verse_ranges.flat_map(&:to_a)
      scope = scope.where(verse_number: verse_numbers)
    end

    scope.order(:verse_number).to_a
  end

  def build_reference_string(book, chapter, verse_part)
    localized_name = @translation.book_names.find_by(book: book)&.name || book.name
    verse_part ? "#{localized_name} #{chapter}:#{verse_part}" : "#{localized_name} #{chapter}"
  end

  def build_passage(reference, verses)
    {
      reference: reference,
      verses: verses,
      text: verses.map { |v| v.text.strip }.join("\n"),
      translation_id: @translation.identifier,
      translation_name: @translation.name,
      translation_note: @translation.note
    }
  end
end
