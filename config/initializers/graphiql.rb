# frozen_string_literal: true

if Rails.env.development?
  GraphiQL::Rails.config.headers = {
    "Authorization" => "Bearer YOUR_API_KEY"
  }

  GraphiQL::Rails.config.initial_query = <<~GQL
    # Welcome to BibleQL API Playground!
    #
    # A GraphQL API for querying Bible verses and passages
    # across 43 translations in 31 languages.
    #
    # Supported reference formats:
    #   "John 3:16"              — single verse
    #   "John 3:16-18"           — verse range
    #   "Matthew 25:31-33,46"    — multiple ranges
    #   "Genesis 1"              — full chapter
    #   "Mateo 28:18-20"         — localized book names
    #
    # Try the examples below! Uncomment one block at a time.

    # — 1. Look up a passage
    {
      passage(translation: "eng-web", reference: "John 3:16") {
        reference
        text
        translationName
        translationNote
        verses {
          bookId
          bookName
          chapter
          verse
          text
        }
      }
    }

    # — 2. Look up a passage in Spanish
    # {
    #   passage(translation: "spa-bes", reference: "Mateo 28:18-20") {
    #     reference
    #     text
    #     translationName
    #     verses { bookName chapter verse text }
    #   }
    # }

    # — 3. Look up multiple verse ranges
    # {
    #   passage(reference: "Matthew 25:31-33,46") {
    #     reference
    #     text
    #     verses { chapter verse text }
    #   }
    # }

    # — 4. Get a full chapter
    # {
    #   chapter(book: "GEN", chapter: 1) {
    #     bookName
    #     chapter
    #     verse
    #     text
    #   }
    # }

    # — 5. Get a single verse
    # {
    #   verse(book: "JHN", chapter: 3, verse: 16) {
    #     bookName
    #     chapter
    #     verse
    #     text
    #   }
    # }

    # — 6. Search verses by text
    # {
    #   search(query: "love", limit: 10) {
    #     bookName
    #     chapter
    #     verse
    #     text
    #   }
    # }

    # — 7. List all available translations
    # {
    #   translations {
    #     identifier
    #     name
    #     language
    #   }
    # }

    # — 8. List all 66 canonical books
    # {
    #   books {
    #     bookId
    #     name
    #     testament
    #     position
    #   }
    # }
  GQL
end
