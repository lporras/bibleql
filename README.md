# BibleQL

[![CI](https://github.com/lporras/bibleql/actions/workflows/ci.yml/badge.svg)](https://github.com/lporras/bibleql/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/lporras/bibleql/branch/main/graph/badge.svg)](https://codecov.io/gh/lporras/bibleql)
[![Donate using Liberapay](https://img.shields.io/liberapay/receives/bibleql.svg?logo=liberapay)](https://liberapay.com/bibleql/donate)

A GraphQL API for querying Bible verses and passages across multiple translations. Supports localized book names so you can query in English (`"John 3:16"`), Spanish (`"Juan 3:16"`), and 30+ other languages.

## Features

- **47 Bible translations** in 31 languages — 41 public domain / freely licensed from [open-bibles](https://github.com/seven1m/open-bibles), plus 6 from [Bible List](https://biblelist.netlify.app/)
- **Flexible passage lookup** — single verses, ranges, multi-ranges (e.g., `"Matthew 25:31-33,46"`)
- **Localized book names** — query using book names in the translation's language (e.g., `"Mateo 28:18-20"` for Spanish)
- **Full-text search** across verses
- **Semantic search** — find verses by meaning using AI embeddings (pgvector + RubyLLM), currently available for spa-rv1909
- **Bible concordance** — exhaustive word lookup with canonical ordering, per-book distribution, and keyword-in-context snippets
- **Verse of the Day** — curated daily verse for any translation and date
- **Language discovery** — list all available languages with translation counts
- **Translation hierarchy** — browse books, chapters, and verse counts per translation
- **Bible index** — full structural overview of any translation
- **API Key authentication** with environment-aware prefixes (`bql_live_` / `bql_test_`)
- **Rate limiting** — 100 req/min per IP, 1,000 req/day per API key
- **Interactive Playground** at `/playground` for exploring the API
- **Admin panel** at `/admin` for managing API keys and requests

## Playground

The interactive GraphQL playground is available at [`/playground`](https://bibleql.org/playground) and lets you explore the API with example queries and a headers panel for authentication.

![BibleQL Playground](docs/playground-screenshot.png)

## Tech Stack

- Ruby 4.0 / Rails 8.1
- PostgreSQL
- [graphql-ruby](https://graphql-ruby.org)
- [bible_parser](https://github.com/seven1m/bible_parser) — parses USFX/OSIS/Zefania XML Bible files
- [bible_ref](https://github.com/seven1m/bible_ref) — parses Bible reference strings
- [open-bibles](https://github.com/seven1m/open-bibles) — public domain Bible translations (git submodule)
- [Bible List](https://biblelist.netlify.app/) — searchable collection of 1,550+ XML Bibles, source of the additional translations in `db/biblelist/`
- [Holy-Bible-XML-Format](https://github.com/lporras/Holy-Bible-XML-Format) — 1,000+ XML Bibles across 200+ languages (git submodule)
- Docker + [Kamal](https://kamal-deploy.org) for deployment

## Client Libraries

- **Ruby:** [bibleql-ruby](https://github.com/lporras/bibleql-ruby) — idiomatic Ruby client gem
- **Node.js:** [bibleql-js](https://github.com/lporras/bibleql-js) — JavaScript/TypeScript client package
- **Examples:** [bibleql-example](https://github.com/lporras/bibleql-example) — working examples using both SDKs

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

# Import Bible translations (all ~45 open-bibles translations)
bundle exec rake bible:import

# Or import a single translation
bundle exec rake "bible:import_one[eng-web]"

# Build the concordance index (required for concordance queries)
bundle exec rake concordance:index
```

### Additional translations

Beyond the open-bibles submodule, BibleQL can import XML Bibles from
[Bible List](https://biblelist.netlify.app/) — a searchable collection of 1,550+ XML Bibles.
Drop the downloaded files in `db/biblelist/`, describe them in
`config/biblelist_translations.yml`, and import them with their own command:

```bash
bundle exec rake biblelist:list                    # show configured files and import status
bundle exec rake biblelist:import                  # import all of them
bundle exec rake "biblelist:import_one[eng-niv]"   # import a single one
```

These files use a different XML shape than the open-bibles formats (`<bible><testament><book
number="1">`), handled by the `bible_parser` format plugin in `lib/biblelist_format/`. They
identify books by ordinal number only, so their localized book names are copied from an
already-imported translation of the same language (`book_names_from` in the YAML) — run
`rake bible:import` first.

> **Note:** most translations available through Bible List are copyrighted. Confirm you hold the
> necessary rights before exposing any of them through a public API.

### Holy-Bible-XML-Format translations

A third source, [Holy-Bible-XML-Format](https://github.com/lporras/Holy-Bible-XML-Format), is a
1,000+ file, 200+ language collection wired up as a real git submodule — its XML files are never
committed to this repo, only pulled locally when you want to run an import:

```bash
git submodule update --init db/holy-bible-xml

bundle exec rake holy_bible_xml:import                    # import everything not already imported
bundle exec rake "holy_bible_xml:import_one[ara-svd]"      # import a single translation
```

These files use the same XML shape as `db/biblelist/`'s, so they're parsed by the same
`BiblelistFormat::Parser`. Unlike `db/biblelist/`, there's no hand-curated metadata file for
1,000+ translations — `HolyBibleXmlFilenameParser` derives each translation's identifier,
language code, and abbreviation straight from its filename (e.g. `ArabicSVDBible.xml` →
`ara-svd`), falling back to a slugified language name for anything not in
`config/language_codes.yml`. See [`docs/holy-bible-xml-identifiers.md`](docs/holy-bible-xml-identifiers.md)
for exactly how that derivation works. Both import tasks skip any identifier that's already in
the database, so re-running them never creates duplicates. Book names are copied from whichever
already-imported translation of the same language has the most of them, falling back to the
canonical book name — run `rake bible:import` first.

Since this submodule isn't checked out in CI or production by default, these tasks are meant to
be run locally (or from any machine with the submodule cloned) against whichever database you
point `DATABASE_URL`/`RAILS_ENV` at, including production:

```bash
RAILS_ENV=production DATABASE_URL=<production-db-url> bundle exec rake holy_bible_xml:import
```

`HolyBibleXmlImporter` builds the concordance index automatically as the last step of every
import (same as every other importer), so freshly imported translations are immediately
queryable via `concordance`/`concordanceIndex`. If you ever need to rebuild the index for a
specific translation by hand — e.g. after editing `config/language_codes.yml` and re-importing,
or to pick up a new `text_search_config` — target it directly by identifier instead of
reindexing everything:

```bash
bundle exec rake "concordance:index[spa-ntv]"
bundle exec rake "concordance:index[spa-tla]"

bundle exec rake concordance:status   # confirm indexed_at / stemming per translation
```

> **Note:** confirm you hold the necessary rights before exposing any imported translation through
> a public API.

## Running Locally

```bash
bin/rails server
```

- **GraphQL endpoint:** `POST http://localhost:3000/graphql`
- **Playground:** `http://localhost:3000/playground`
- **GraphiQL IDE:** `http://localhost:3000/graphiql` (development only)
- **Admin panel:** `http://localhost:3000/admin` (development only)

## Authentication

All `POST /graphql` requests require an API key via the `Authorization` header:

```
Authorization: Bearer bql_live_xxxxxxxxxxxxxxxx
```

- **Token prefixes:** `bql_live_` (production), `bql_test_` (development/test)
- **Get an API key:** Visit `/api-keys/request/new` to submit a request (admin approval required)
- **Manage keys via rake:**

```bash
# Create a key
bundle exec rake "api_keys:create[name,email,environment]"

# List all keys
bundle exec rake api_keys:list

# Revoke a key
bundle exec rake "api_keys:revoke[prefix]"
```

## GraphQL API

### Quick example

```graphql
{
  passage(translation: "eng-web", reference: "John 3:16") {
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

Response:

```json
{
  "data": {
    "passage": {
      "reference": "John 3:16",
      "text": "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.",
      "translationName": "World English Bible",
      "verses": [
        {
          "bookName": "John",
          "chapter": 3,
          "verse": 16,
          "text": "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life."
        }
      ]
    }
  }
}
```

### Available queries

| Query | Description |
|-------|-------------|
| `translations` | List all available translations |
| `translation(identifier)` | Get a single translation with nested books and chapters |
| `books` | List all 66 canonical books |
| `languages` | List all languages with translation counts |
| `passage(translation, reference)` | Look up a passage (e.g., `"John 3:16"`, `"Mateo 28:18-20"`) |
| `chapter(translation, book, chapter)` | Get all verses in a chapter |
| `verse(translation, book, chapter, verse)` | Get a single verse |
| `search(translation, query, limit)` | Full-text search across verses |
| `semanticSearch(query, translation, limit)` | Search verses by semantic meaning using AI embeddings |
| `randomVerse(translation, testament, books)` | Get a random verse with optional filters |
| `verseOfTheDay(translation, date)` | Get the curated verse of the day |
| `bibleIndex(translation)` | Get the structural hierarchy (books, chapters, verse counts) |
| `concordance(translation, word, book, testament, first, after)` | Exhaustive, canonically-ordered concordance for a word, with per-book counts and KWIC context |
| `concordanceIndex(translation, prefix, minOccurrences, first)` | Alphabetical word index with occurrence frequencies |

See [docs/example_queries.md](docs/example_queries.md) for complete examples with responses for every query.

### Reference Formats

The `passage` query supports these reference formats:

| Format | Example |
|--------|---------|
| Single verse | `"John 3:16"` |
| Verse range | `"John 3:16-18"` |
| Multiple ranges | `"Matthew 25:31-33,46"` |
| Full chapter | `"Genesis 1"` |
| Cross-chapter | `"Romans 12:1,3-4 & 13:2-4"` |
| Localized names | `"Mateo 28:18-20"`, `"Lucas 3:1-10"` |

### Concordance

Unlike `search`, which returns the top-N most relevant verses, `concordance` returns **every**
occurrence of a word in canonical order, along with aggregate counts.

Stemming availability varies by language. PostgreSQL ships dictionaries for about 30 languages;
translations in other languages fall back to exact form matching. Check `translation.hasStemming`
to know which behavior applies.

Run `rake concordance:index` after importing translations, or concordance queries will return
an error prompting you to build the index.

## Rate Limiting

The API is protected by rate limiting via [Rack::Attack](https://github.com/rack/rack-attack):

| Scope | Limit |
|-------|-------|
| GraphQL requests per IP | 100/minute |
| GraphQL requests per API key | 1,000/day |
| API key request form per IP | 5/hour |

Exceeded limits return a `429 Too Many Requests` response with a `Retry-After` header.

## Running Tests

```bash
bundle exec rspec
```

## Linting

```bash
bin/rubocop
```

## Deployment

BibleQL is deployed using Docker and Kamal. See [config/deploy.yml](config/deploy.yml) and [Dockerfile](Dockerfile) for details.

The CI pipeline (GitHub Actions) runs security scans (Brakeman, Bundler Audit), linting (RuboCop), and tests (RSpec) on every PR.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

This project is open source. Bible translations included via [open-bibles](https://github.com/seven1m/open-bibles) are Public Domain or Creative Commons licensed.
