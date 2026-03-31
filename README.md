# BibleQL

A GraphQL API for querying Bible verses and passages across multiple translations. Supports localized book names so you can query in English (`"John 3:16"`), Spanish (`"Juan 3:16"`), and 30+ other languages.

## Features

- **43 Bible translations** in 31 languages (public domain)
- **Flexible passage lookup** — single verses, ranges, multi-ranges (e.g., `"Matthew 25:31-33,46"`)
- **Localized book names** — query using book names in the translation's language (e.g., `"Mateo 28:18-20"` for Spanish)
- **Full-text search** across verses
- **API Key authentication** with environment-aware prefixes (`bql_live_` / `bql_test_`)
- **Rate limiting** — 100 req/min per IP, 1,000 req/day per API key
- **Interactive Playground** at `/playground` for exploring the API
- **Admin panel** at `/admin` for managing API keys and requests

## Playground

The interactive GraphQL playground is available at [`/playground`](https://bibleql-rails.onrender.com/playground) and lets you explore the API with example queries and a headers panel for authentication.

![BibleQL Playground](docs/playground-screenshot.png)

## Tech Stack

- Ruby 4.0 / Rails 8.1
- PostgreSQL
- [graphql-ruby](https://graphql-ruby.org)
- [bible_parser](https://github.com/seven1m/bible_parser) — parses USFX/OSIS/Zefania XML Bible files
- [bible_ref](https://github.com/seven1m/bible_ref) — parses Bible reference strings
- [open-bibles](https://github.com/seven1m/open-bibles) — public domain Bible translations (git submodule)
- Docker + [Kamal](https://kamal-deploy.org) for deployment

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

### List translations

```graphql
{
  translations {
    identifier
    name
    language
  }
}
```

Response:

```json
{
  "data": {
    "translations": [
      {
        "identifier": "eng-web",
        "name": "World English Bible",
        "language": "eng"
      },
      {
        "identifier": "spa-bes",
        "name": "Biblia en Espanol",
        "language": "spa"
      }
    ]
  }
}
```

### List books

```graphql
{
  books {
    bookId
    name
    testament
    position
  }
}
```

Response:

```json
{
  "data": {
    "books": [
      {
        "bookId": "GEN",
        "name": "Genesis",
        "testament": "OT",
        "position": 1
      },
      {
        "bookId": "EXO",
        "name": "Exodus",
        "testament": "OT",
        "position": 2
      }
    ]
  }
}
```

### Look up a passage

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

### Look up a passage in Spanish

```graphql
{
  passage(translation: "spa-bes", reference: "Lucas 3:1-10") {
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
      "reference": "Lucas 3:1-10",
      "text": "En el ano quince del emperador de Tiberio Cesar, Poncio Pilato fue gobernador de Judea...",
      "translationName": "spa-bes",
      "verses": [
        {
          "bookName": "Lucas",
          "chapter": 3,
          "verse": 1,
          "text": "En el ano quince del emperador de Tiberio Cesar..."
        }
      ]
    }
  }
}
```

### Get a full chapter

```graphql
{
  chapter(book: "GEN", chapter: 1) {
    bookName
    chapter
    verse
    text
  }
}
```

Response:

```json
{
  "data": {
    "chapter": [
      {
        "bookName": "Genesis",
        "chapter": 1,
        "verse": 1,
        "text": "In the beginning, God created the heavens and the earth."
      },
      {
        "bookName": "Genesis",
        "chapter": 1,
        "verse": 2,
        "text": "The earth was formless and empty. Darkness was on the surface of the deep and God's Spirit was hovering over the surface of the waters."
      }
    ]
  }
}
```

### Get a single verse

```graphql
{
  verse(book: "JHN", chapter: 3, verse: 16) {
    bookName
    chapter
    verse
    text
  }
}
```

Response:

```json
{
  "data": {
    "verse": {
      "bookName": "John",
      "chapter": 3,
      "verse": 16,
      "text": "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life."
    }
  }
}
```

### Search verses

```graphql
{
  search(query: "love", limit: 5) {
    bookName
    chapter
    verse
    text
  }
}
```

Response:

```json
{
  "data": {
    "search": [
      {
        "bookName": "Genesis",
        "chapter": 22,
        "verse": 2,
        "text": "He said, \"Now take your son, your only son, Isaac, whom you love, and go into the land of Moriah. Offer him there as a burnt offering on one of the mountains which I will tell you of.\""
      },
      {
        "bookName": "Genesis",
        "chapter": 24,
        "verse": 67,
        "text": "Isaac brought her into his mother Sarah's tent, and took Rebekah, and she became his wife. He loved her. So Isaac was comforted after his mother's death."
      }
    ]
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
| Localized names | `"Mateo 28:18-20"`, `"Lucas 3:1-10"` |

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
