# frozen_string_literal: true

class BibleIndexBuilder
  ChapterData = Struct.new(:number, :verse_count, :translation_id, :book_id, keyword_init: true)
  BookData = Struct.new(:book_id, :name, :testament, :position, :chapter_count, :chapters, keyword_init: true)

  def initialize(translation:)
    @translation = translation
  end

  def call
    chapter_data = Verse
      .where(translation: @translation)
      .group(:book_id, :chapter)
      .order(:book_id, :chapter)
      .count

    # Group by book_id: { book_id => { chapter_number => verse_count } }
    grouped = chapter_data.each_with_object({}) do |((book_id, chapter), count), hash|
      hash[book_id] ||= {}
      hash[book_id][chapter] = count
    end

    # Load all books in canonical order
    books = Book.where(id: grouped.keys).order(:position)

    # Load localized names for this translation
    localized_names = @translation.book_names.index_by(&:book_id)

    books.map do |book|
      chapters_hash = grouped[book.id] || {}
      chapters = chapters_hash.map do |chapter_number, verse_count|
        ChapterData.new(
          number: chapter_number,
          verse_count: verse_count,
          translation_id: @translation.id,
          book_id: book.id
        )
      end

      BookData.new(
        book_id: book.book_id,
        name: localized_names[book.id]&.name || book.name,
        testament: book.testament,
        position: book.position,
        chapter_count: chapters.size,
        chapters: chapters
      )
    end
  end
end
