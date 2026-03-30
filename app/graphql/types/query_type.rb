# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    field :translations, [ Types::TranslationType ], null: false,
      description: "List all available Bible translations"
    def translations
      Translation.order(:identifier)
    end

    field :books, [ Types::BookType ], null: false,
      description: "List all canonical books in order"
    def books
      Book.order(:position)
    end

    field :passage, Types::PassageType, null: false,
      description: "Look up a Bible passage by reference" do
      argument :translation, String, required: false, default_value: "eng-web",
        description: "Translation identifier (e.g. 'eng-web', 'spa-bes')"
      argument :reference, String, required: true,
        description: "Bible reference (e.g. 'John 3:16', 'Mateo 28:18-20')"
    end
    def passage(translation:, reference:)
      PassageLookup.new(translation_identifier: translation, reference: reference).call
    end

    field :chapter, [ Types::VerseType ], null: false,
      description: "Get all verses in a chapter" do
      argument :translation, String, required: false, default_value: "eng-web"
      argument :book, String, required: true, description: "Book ID (e.g. 'MAT') or localized name (e.g. 'Mateo')"
      argument :chapter, Integer, required: true
    end
    def chapter(translation:, book:, chapter:)
      t = Translation.find_by!(identifier: translation)
      book_record = find_book(t, book)
      Verse.includes(:book)
        .where(translation: t, book: book_record, chapter: chapter)
        .order(:verse_number)
    end

    field :verse, Types::VerseType, null: false,
      description: "Get a single verse" do
      argument :translation, String, required: false, default_value: "eng-web"
      argument :book, String, required: true, description: "Book ID or localized name"
      argument :chapter, Integer, required: true
      argument :verse, Integer, required: true
    end
    def verse(translation:, book:, chapter:, verse:)
      t = Translation.find_by!(identifier: translation)
      book_record = find_book(t, book)
      Verse.includes(:book)
        .find_by!(translation: t, book: book_record, chapter: chapter, verse_number: verse)
    end

    field :search, [ Types::VerseType ], null: false,
      description: "Search verses by text content" do
      argument :translation, String, required: false, default_value: "eng-web"
      argument :query, String, required: true
      argument :limit, Integer, required: false, default_value: 25
    end
    def search(translation:, query:, limit:)
      t = Translation.find_by!(identifier: translation)
      Verse.includes(:book)
        .where(translation: t)
        .where("text ILIKE ?", "%#{Verse.sanitize_sql_like(query)}%")
        .order(:book_id, :chapter, :verse_number)
        .limit([ limit, 100 ].min)
    end

    private

    def find_book(translation, book_identifier)
      # Try by book_id first, then by localized name
      Book.find_by(book_id: book_identifier) ||
        translation.book_names
          .joins(:book)
          .where("LOWER(book_names.name) = ?", book_identifier.downcase)
          .first&.book ||
        raise(ActiveRecord::RecordNotFound, "Book '#{book_identifier}' not found")
    end
  end
end
