# BibleQL

A GraphQL API for querying Bible verses and passages across multiple translations. Supports localized book names so you can query in English (`"John 3:16"`), Spanish (`"Juan 3:16"`), and 30+ other languages.

## Features

- **43 Bible translations** in 31 languages (public domain)
- **Flexible passage lookup** — single verses, ranges, multi-ranges (e.g., `"Matthew 25:31-33,46"`)
- **Localized book names** — query using book names in the translation's language (e.g., `"Mateo 28:18-20"` for Spanish)
- **Full-text search** across verses
- **GraphiQL IDE** for interactive exploration in development

## Tech Stack

- Ruby 4.0 / Rails 8.1
- PostgreSQL
- [graphql-ruby](https://graphql-ruby.org)
- [bible_parser](https://github.com/seven1m/bible_parser) — parses USFX/OSIS/Zefania XML Bible files
- [bible_ref](https://github.com/seven1m/bible_ref) — parses Bible reference strings
- [open-bibles](https://github.com/seven1m/open-bibles) — public domain Bible translations (git submodule)

## Prerequisites

- Ruby 4.0+
- PostgreSQL
- Git (for submodules)

## Setup

```bash
# Clone the repository (with submodules)
git clone --recurse-submodules https://github.com/lporras/bibleql.git
cd bibleql

# If you already cloned without submodules
git submodule update --init

# Install dependencies
bundle install

# Create and migrate the database
bin/rails db:create db:migrate

# Import Bible translations (all ~43 translations)
bundle exec rake bible:import

# Or import a single translation
bundle exec rake "bible:import_one[eng-web]"
```

## Running Locally

```bash
bin/rails server
```

- **GraphQL endpoint:** `POST http://localhost:3000/graphql`
- **GraphiQL IDE:** `http://localhost:3000/graphiql` (development only)

## GraphQL API

### Available Queries

#### List translations

```graphql
{
  translations {
    identifier
    name
    language
  }
}
```

#### Look up a passage

```graphql
{
  passage(translation: "eng-web", reference: "John 3:16") {
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
```

#### Look up a passage in Spanish

```graphql
{
  passage(translation: "spa-bes", reference: "Mateo 28:18-20") {
    reference
    text
    translationName
    verses {
      bookName
      chapter
      verse
      text
    }
  }
}
```

#### Get a full chapter

```graphql
{
  chapter(translation: "eng-web", book: "GEN", chapter: 1) {
    bookName
    chapter
    verse
    text
  }
}
```

#### Get a single verse

```graphql
{
  verse(translation: "eng-web", book: "JHN", chapter: 3, verse: 16) {
    bookName
    chapter
    verse
    text
  }
}
```

#### Search verses

```graphql
{
  search(translation: "eng-web", query: "love", limit: 10) {
    bookName
    chapter
    verse
    text
  }
}
```

### Reference Formats

The `passage` query supports these reference formats:

| Format | Example |
|--------|---------|
| Single verse | `"John 3:16"` |
| Verse range | `"John 3:16-18"` |
| Multiple ranges | `"Matthew 25:31-33,46"` |
| Full chapter | `"Genesis 1"` |
| Cross-chapter | `"Romans 12:1,3-4 & 13:2-4"` |
| Localized names | `"Mateo 28:18-20"`, `"Genesi 1:1"` |

## Running Tests

```bash
bundle exec rspec
```

## Linting

```bash
bin/rubocop
```

## License

This project is open source. Bible translations included via [open-bibles](https://github.com/seven1m/open-bibles) are Public Domain or Creative Commons licensed.
