# frozen_string_literal: true

if Rails.env.development?
  GraphiQL::Rails.config.initial_query = <<~GQL
    # Welcome to BibleQL!
    # A GraphQL API for querying Bible verses and passages
    # across 43 translations in 31 languages.
    #
    # Available Queries:
    #
    #   translations          — List all available Bible translations
    #   books                 — List all 66 canonical books
    #   passage(reference)    — Look up a passage (supports localized names)
    #   chapter(book,chapter) — Get all verses in a chapter
    #   verse(book,ch,verse)  — Get a single verse
    #   search(query)         — Full-text search across verses
    #
    # Reference formats supported:
    #   "John 3:16"              — single verse
    #   "John 3:16-18"           — verse range
    #   "Matthew 25:31-33,46"    — multiple ranges
    #   "Genesis 1"              — full chapter
    #   "Mateo 28:18-20"         — localized book names (Spanish)
    #
    # Try the examples below! Uncomment one block at a time.

    # — Look up a passage in English
    {
      passage(reference: "John 3:16") {
        reference
        text
        translationName
        verses {
          bookId
          bookName
          chapter
          verse
          text
        }
      }
    }

    # — Look up a passage in Spanish
    # {
    #   passage(translation: "spa-bes", reference: "Mateo 28:18-20") {
    #     reference
    #     text
    #     translationName
    #     verses { bookName chapter verse text }
    #   }
    # }

    # — List all translations
    # {
    #   translations {
    #     identifier
    #     name
    #     language
    #   }
    # }

    # — Get a full chapter
    # {
    #   chapter(book: "GEN", chapter: 1) {
    #     bookName
    #     chapter
    #     verse
    #     text
    #   }
    # }

    # — Search for verses
    # {
    #   search(query: "love", limit: 10) {
    #     bookName
    #     chapter
    #     verse
    #     text
    #   }
    # }
  GQL
end
