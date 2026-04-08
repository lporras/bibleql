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

# Playground (all environments)
# Visit http://localhost:3000/playground

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

# API Key management
bundle exec rake "api_keys:create[name,email,environment]"  # environment: test or live
bundle exec rake "api_keys:revoke[prefix]"
bundle exec rake api_keys:list

# Admin panel (development)
# Visit http://localhost:3000/admin (admin@example.com / password)

# API Key request form
# Visit http://localhost:3000/api-keys/request/new
```

## Architecture

- **Framework**: Rails 8.1 (API + standard views via Hotwire/Turbo/Stimulus)
- **GraphQL**: graphql-ruby gem (v2.5) with GraphiQL IDE in development; max_complexity: 300, max_depth: 15
- **Database**: PostgreSQL with Solid Cache, Solid Queue, and Solid Cable for production
- **CORS**: Enabled for `/graphql` endpoint (origins: "*")
- **Bible Data**: open-bibles git submodule (db/open-bibles/) parsed via bible_parser gem
- **Reference Parsing**: bible_ref gem + localized book name fallback
- **Asset Pipeline**: Propshaft with import maps (no Node.js bundler); Sprockets coexists for ActiveAdmin assets
- **Authentication**: API Key-based auth for GraphQL endpoint (Bearer token in Authorization header)
- **Rate Limiting**: rack-attack (100 req/min per IP, 1000 req/day per API key)
- **Admin Panel**: ActiveAdmin at /admin (Devise auth for AdminUser)
- **Testing**: RSpec (not Minitest) with Capybara/Selenium for system tests
- **Deployment**: Docker + Kamal; hosted on Render (bibleql.org)
- **CI/CD**: GitHub Actions (Brakeman, Bundler Audit, Importmap Audit, RuboCop, RSpec)
- **Linting**: rubocop-rails-omakase style guide
- **Email**: Resend API for transactional emails (API key approval/rejection notifications)
- **Playground**: Public GraphQL playground at `/playground` (CDN-hosted GraphiQL v3.8.3)

## Key Models

- **Translation** — Bible translation (e.g., "eng-web", "spa-bes")
- **Book** — Canonical book with standardized book_id (e.g., "MAT", "GEN")
- **BookName** — Localized book name per translation (e.g., "Mateo" for Spanish Matthew)
- **Verse** — Individual verse with translation, book, chapter, verse_number, text
- **ApiKey** — API key with bcrypt digest, environment-aware prefixes (`bql_live_`/`bql_test_`), usage tracking
- **ApiKeyRequest** — Self-service API key request (pending/approved/rejected workflow)
- **AdminUser** — Devise-authenticated admin user for ActiveAdmin panel

## GraphQL Queries

- `translations` — List all available translations
- `translation(identifier)` — Get a single translation with nested books and chapters
- `books` — List all 66 canonical books
- `languages` — List all languages with translation counts and nested translations
- `passage(translation, reference)` — Look up a passage (e.g., "John 3:16", "Mateo 28:18-20")
- `chapter(translation, book, chapter)` — Get all verses in a chapter
- `verse(translation, book, chapter, verse)` — Get a single verse
- `search(translation, query, limit)` — Full-text search across verses
- `verseOfTheDay(translation, date)` — Get the curated verse of the day (defaults to today)
- `bibleIndex(translation)` — Get the structural hierarchy of books, chapters, and verse counts

## Key Services

- **BibleImporter** (`app/services/bible_importer.rb`) — Imports Bible translations from XML files using bible_parser
- **PassageLookup** (`app/services/passage_lookup.rb`) — Resolves Bible references (supports both English and localized book names)
- **VerseOfTheDayLookup** (`app/services/verse_of_the_day_lookup.rb`) — Returns a curated daily verse using a YAML list (`config/verse_of_the_day.yml`)
- **BibleIndexBuilder** (`app/services/bible_index_builder.rb`) — Builds structural hierarchy (books, chapters, verse counts) for a translation
- **ApiKeyMailer** (`app/mailers/api_key_mailer.rb`) — Sends approval/rejection emails via Resend

## Authentication

All `POST /graphql` requests require an API key via the `Authorization: Bearer <token>` header.

- **Token prefixes**: `bql_live_` (production), `bql_test_` (development/test)
- **One key per email per environment** (unique constraint)
- Keys can be created via rake tasks or through the self-service request flow (admin approval required)
- GraphiQL and Playground have a headers panel for entering the API key

## Skills

When working on Rails features, load and follow the guidelines in `.agents/skills/rails-expert/SKILL.md`. Reference files for specific topics (Active Record, Hotwire, RSpec, etc.) are in `.agents/skills/rails-expert/references/`.
