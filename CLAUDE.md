# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BibleQL is a GraphQL API for querying Bible verses and passages across multiple translations. Built with Rails 8.1, Ruby 4.0, PostgreSQL, and RSpec for testing.

### Goals

- Provide a GraphQL endpoint to query Bible verses and passages
- Support multiple Bible translations (~43 public domain translations)
- Enable flexible queries by book, chapter, verse, and passage ranges
- Support localized book names (e.g., "Mateo" for Spanish, "Matthew" for English)

## Common Commands

```bash
# Setup
git submodule update --init
bin/rails db:create db:migrate

# Import all Bible translations
bundle exec rake bible:import

# Import a single translation
bundle exec rake "bible:import_one[eng-web]"

# Run the server
bin/rails server

# GraphiQL IDE (development only)
# Visit http://localhost:3000/graphiql

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/path/to/file_spec.rb

# Run a specific test by line number
bundle exec rspec spec/path/to/file_spec.rb:42

# Linting
bin/rubocop

# Security audit
bin/brakeman
bundle exec bundler-audit

# Rails console
bin/rails console

# Database
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:test:prepare
```

## Architecture

- **Framework**: Rails 8.1 (API + standard views via Hotwire/Turbo/Stimulus)
- **GraphQL**: graphql-ruby gem with GraphiQL IDE in development
- **Database**: PostgreSQL with Solid Cache, Solid Queue, and Solid Cable for production
- **Bible Data**: open-bibles git submodule (db/open-bibles/) parsed via bible_parser gem
- **Reference Parsing**: bible_ref gem + localized book name fallback
- **Asset Pipeline**: Propshaft with import maps (no Node.js bundler)
- **Testing**: RSpec (not Minitest) with Capybara/Selenium for system tests
- **Deployment**: Docker + Kamal
- **Linting**: rubocop-rails-omakase style guide

## Key Models

- **Translation** — Bible translation (e.g., "eng-web", "spa-bes")
- **Book** — Canonical book with standardized book_id (e.g., "MAT", "GEN")
- **BookName** — Localized book name per translation (e.g., "Mateo" for Spanish Matthew)
- **Verse** — Individual verse with translation, book, chapter, verse_number, text

## GraphQL Queries

- `translations` — List all available translations
- `books` — List all 66 canonical books
- `passage(translation, reference)` — Look up a passage (e.g., "John 3:16", "Mateo 28:18-20")
- `chapter(translation, book, chapter)` — Get all verses in a chapter
- `verse(translation, book, chapter, verse)` — Get a single verse
- `search(translation, query, limit)` — Full-text search across verses

## Key Services

- **BibleImporter** (`app/services/bible_importer.rb`) — Imports Bible translations from XML files using bible_parser
- **PassageLookup** (`app/services/passage_lookup.rb`) — Resolves Bible references (supports both English and localized book names)
