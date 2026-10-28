# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BibleQL is a GraphQL API for querying Bible verses and passages across multiple translations. Built with Rails 8.1, Ruby 4.0, PostgreSQL, and RSpec for testing.

### Goals

- Provide a GraphQL endpoint to query Bible verses and passages
- Support multiple Bible translations (~45 public domain from open-bibles, plus extras from biblelist.netlify.app in `db/biblelist/`)
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

# Backfill translation names/abbreviations/licenses from config/translations.yml
bundle exec rake bible:update_metadata          # all translations
DRY_RUN=1 bundle exec rake bible:update_metadata
bundle exec rake "bible:update_metadata[eng-web]"

# Regenerate config/translations.yml from the open-bibles README (after a submodule update)
bundle exec rake bible:generate_metadata

# Import the db/biblelist/ translations (different XML format, see BiblelistFormat)
bundle exec rake biblelist:list                    # show config + import status
bundle exec rake biblelist:import                  # all
bundle exec rake "biblelist:import_one[eng-niv]"   # one

# Import from Holy-Bible-XML-Format (github.com/lporras/Holy-Bible-XML-Format, 1000+ files,
# 200+ languages, same XML shape as biblelist; identifier/language/abbrev derived from the
# filename, not a config file). NOT a git submodule (Render syncs every registered submodule
# on deploy) — download only the files you want into db/holy-bible-xml/ (gitignored), e.g.:
curl -fsSL -o db/holy-bible-xml/ArabicSVDBible.xml \
  https://raw.githubusercontent.com/lporras/Holy-Bible-XML-Format/master/ArabicSVDBible.xml
bundle exec rake "holy_bible_xml:import_one[ara-svd]"    # one, by derived identifier
bundle exec rake holy_bible_xml:import                  # every file already downloaded, skipping duplicates

# Generate embeddings for semanticSearch (currently only spa-rv1909)
bundle exec rake "embeddings:generate[spa-rv1909]"
bundle exec rake "embeddings:clear[spa-rv1909]"

# Concordance index (required for concordance/concordanceIndex queries)
bundle exec rake concordance:index                  # all translations
bundle exec rake "concordance:index[spa-rv1909]"    # one translation
bundle exec rake concordance:status                 # per-translation index status

# Offline translation packages (see docs/offline_packages.md). Needs OFFLINE_R2_* env vars and a
# running Solid Queue worker (bin/jobs, started by bin/dev)
bundle exec rake offline:check_storage              # verify R2 credentials + public URL
DRY_RUN=1 bundle exec rake offline:flag_public_domain
bundle exec rake "offline:flag[eng-web,true]"       # licensing gate, default false
bundle exec rake offline:list
bundle exec rake "offline:export_one[spa-rv1909]"   # FORCE=1 to republish unchanged data
bundle exec rake offline:export_all

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
bundle exec rake api_keys:list                     # KIND=developer|installation to filter
bundle exec rake "api_keys:deprecate[prefix]"      # old shared reader key, after the new reader ships
bundle exec rake "api_keys:undeprecate[prefix]"

# Admin panel (development)
# Visit http://localhost:3000/admin (admin@example.com / password)

# API Key request form
# Visit http://localhost:3000/api-keys/request/new
```

## Architecture

- **Framework**: Rails 8.1 (API + standard views via Hotwire/Turbo/Stimulus)
- **GraphQL**: graphql-ruby gem (v2.5) with GraphiQL IDE in development; max_complexity: 300, max_depth: 15
- **Database**: PostgreSQL with Solid Cache, Solid Queue, and Solid Cable for production
- **Background jobs**: Solid Queue in development and production, tables in the primary DB. Production runs the worker inside Puma (`SOLID_QUEUE_IN_PUMA=true`); development runs `bin/jobs` (in `Procfile.dev`)
- **Offline packages**: per-translation SQLite files (`sqlite3` gem, FTS5) uploaded to Cloudflare R2 (`aws-sdk-s3`)
- **CORS**: Enabled for `/graphql` endpoint (origins: "*")
- **Bible Data**: open-bibles git submodule (db/open-bibles/) parsed via bible_parser gem
- **Reference Parsing**: bible_ref gem + localized book name fallback
- **Asset Pipeline**: Propshaft with import maps (no Node.js bundler); Sprockets coexists for ActiveAdmin assets
- **Authentication**: API Key-based auth for GraphQL endpoint (Bearer token in Authorization header)
- **Rate Limiting**: rack-attack (100 req/min per IP; 10/hour per IP for requests without an `Authorization` header, i.e. `registerInstallation`) plus `ApiKeyRateLimiter` in `GraphqlController` (per key, `api_keys.daily_limit`, default 1000/day, counted in `Rails.cache`, resets midnight UTC). Errors carry `extensions.code` (`RATE_LIMITED`, `UNAUTHENTICATED`)
- **Unsplash**: `unsplash` gem from the `lporras/unsplash_rb` fork (`master`; the released 3.x gem declares Ruby < 4), configured in `config/initializers/unsplash.rb`
- **Admin Panel**: ActiveAdmin at /admin (Devise auth for AdminUser)
- **Testing**: RSpec (not Minitest) with Capybara/Selenium for system tests
- **Deployment**: Docker + Kamal; hosted on Render (bibleql.org)
- **CI/CD**: GitHub Actions (Brakeman, Bundler Audit, Importmap Audit, RuboCop, RSpec)
- **Linting**: rubocop-rails-omakase style guide
- **Email**: Resend API for transactional emails (API key approval/rejection notifications)
- **Playground**: Public GraphQL playground at `/playground` (CDN-hosted GraphiQL v3.8.3)

## Key Models

- **Translation** — Bible translation (e.g., "eng-web", "spa-bes"), plus `text_search_config`, `has_stemming`, `concordance_indexed_at`
- **Book** — Canonical book with standardized book_id (e.g., "MAT", "GEN")
- **BookName** — Localized book name per translation (e.g., "Mateo" for Spanish Matthew)
- **Verse** — Individual verse with translation, book, chapter, verse_number, text, plus `text_search` (tsvector, GIN-indexed) for concordance
- **OfflinePackage** — Published offline SQLite package per translation and schema version (`url`, `sha256`, sizes, `source_digest`); gated by `translations.offline_downloadable`
- **ConcordanceWordIndex** — Per-translation word frequency (`lemma`, `verse_count`, `total_occurrences`) from `ts_stat`, backing `concordanceIndex`
- **ApiKey** — API key with bcrypt digest, environment-aware prefixes (`bql_live_`/`bql_test_`), usage tracking; `kind` is `developer` (email-based, request form) or `installation` (owned by an `Installation`, no email); `deprecated` keys still work but responses carry `extensions.updateRequired`
- **Installation** — One installed client app (`installation_id` UUID, `platform`, `app_version`, `last_seen_at`, `revoked_at`); registers via `registerInstallation`; revoking it revokes its keys and blocks re-registration
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
- `semanticSearch(query, translation, limit)` — Embedding-based similarity search (pgvector + RubyLLM), currently only spa-rv1909 has embeddings
- `verseOfTheDay(translation, date)` — Get the curated verse of the day (defaults to today)
- `bibleIndex(translation)` — Get the structural hierarchy of books, chapters, and verse counts
- `concordance(translation, word, book, testament, first, after)` — Exhaustive, canonically-ordered concordance for a word, with per-book/testament counts and KWIC context
- `concordanceIndex(translation, prefix, minOccurrences, first)` — Alphabetical word index with occurrence frequencies
- `translations { offlineDownloadable offlinePackage(schemaVersion) { url sha256 sizeBytes … } }` — Downloadable offline SQLite packages (batch-loaded via `Sources::OfflinePackageSource`)
- `backgroundImages(query, page, perPage)` — **Installation keys only** (hidden from other keys and from the public SDL via `installation_only:`). Unsplash photo search proxied through the server (key never leaves it); Unsplash failures return `images: []` + `errorCode`, not GraphQL errors. Internal doc: `docs/background_images.md` (not on docs.bibleql.org)
- Mutation `registerInstallation(input: { installationId, platform, appVersion })` — No auth; issues a new installation token, revoking any previous one for that installation
- Mutation `trackImageDownload(input: { imageId })` — **Installation keys only**. Enqueues Unsplash's required download ping (`TrackUnsplashDownloadJob`)

## Key Services

- **BibleImporter** (`app/services/bible_importer.rb`) — Imports Bible translations from XML files using bible_parser
- **BiblelistImporter** (`app/services/biblelist_importer.rb`) — Imports the `db/biblelist/` translations (from biblelist.netlify.app); metadata in `config/biblelist_translations.yml`, book names copied from a same-language translation
- **BiblelistFormat** (`lib/biblelist_format/`) — A `bible_parser` format plugin (`Base::Parser`/`Base::Document` subclasses) for the `<bible><testament><book number>` XML shape; not registered in `BibleParser::PARSERS`, instantiate directly
- **HolyBibleXmlImporter** (`app/services/holy_bible_xml_importer.rb`) — Imports files hand-downloaded into `db/holy-bible-xml/` (gitignored, not a submodule — see docs/holy-bible-xml-identifiers.md) from github.com/lporras/Holy-Bible-XML-Format (1000+ files); same XML shape/parser as `BiblelistFormat`, but no metadata config file exists for it — identifier/language/abbrev come from `HolyBibleXmlFilenameParser` instead; skips any identifier already in the database
- **HolyBibleXmlFilenameParser** (`app/services/holy_bible_xml_filename_parser.rb`) — Derives identifier/language code/variant/abbrev from a Holy-Bible-XML-Format filename (e.g. `ArabicSVDBible.xml` → `ara-svd`), using `config/language_codes.yml` with a slug fallback for unmapped languages; see `docs/holy-bible-xml-identifiers.md` for the full algorithm
- **PassageLookup** (`app/services/passage_lookup.rb`) — Resolves Bible references (supports both English and localized book names)
- **VerseOfTheDayLookup** (`app/services/verse_of_the_day_lookup.rb`) — Returns a curated daily verse using a YAML list (`config/verse_of_the_day.yml`)
- **BibleIndexBuilder** (`app/services/bible_index_builder.rb`) — Builds structural hierarchy (books, chapters, verse counts) for a translation
- **TranslationMetadata** (`app/services/translation_metadata.rb`) — Reads curated per-translation metadata (name, abbrev, language name, license) from `config/translations.yml`
- **TranslationMetadataSync** (`app/services/translation_metadata_sync.rb`) — Backfills existing Translation rows from that YAML (`rake bible:update_metadata`)
- **TranslationMetadataGenerator** (`app/services/translation_metadata_generator.rb`) — Regenerates `config/translations.yml` from the open-bibles README table (dev maintenance)
- **EmbeddingService** (`app/services/embedding_service.rb`) — RubyLLM wrapper generating embeddings for `semanticSearch` and `rake embeddings:generate`
- **ConcordanceLookup** (`app/services/concordance_lookup.rb`) — Builds concordance results: exhaustive occurrences in canonical order, per-book/testament counts, KWIC context via `ts_headline`. All concordance SQL lives here; resolvers must not contain SQL.
- **ConcordanceWordIndexLookup** (`app/services/concordance_word_index_lookup.rb`) — Alphabetical word-frequency lookup backing `concordanceIndex`
- **ConcordanceIndexer** (`app/services/concordance_indexer.rb`) — Populates `verses.text_search` using the per-translation `regconfig` and rebuilds `concordance_word_index`. Called at the end of every import.
- **TextSearchConfigResolver** (`app/services/text_search_config_resolver.rb`) — Maps a translation's `language` to a PostgreSQL text search configuration; falls back to `simple`
- **OfflinePackages** (`app/services/offline_packages.rb` + `offline_packages/`) — `Builder` writes a translation to SQLite following `schema_v1.sql` (canonical-order `verses.id`, localized book names, FTS5 `unicode61 remove_diacritics 2`); `Publisher` gzips and uploads to R2 under an immutable content-addressed key; `ExportOfflinePackageJob` ties them together and skips unchanged `source_digest`. Config via `OFFLINE_R2_*`/`OFFLINE_PUBLIC_BASE_URL`. Every importer calls `OfflinePackages.enqueue_export` after indexing. Admin page: **Offline Packages** (`app/admin/offline_packages.rb`)
- **ApiKeyMailer** (`app/mailers/api_key_mailer.rb`) — Sends approval/rejection emails via Resend
- **InstallationRegistrar** (`app/services/installation_registrar.rb`) — Backs `registerInstallation`: find-or-create the `Installation` (race-safe), revoke its active keys, create a new installation key
- **ApiKeyRateLimiter** (`app/services/api_key_rate_limiter.rb`) — Per-key daily quota, checked in `GraphqlController` after auth
- **UnsplashClient** (`app/services/unsplash_client.rb`) — Wraps the unsplash gem; maps all failures to `UnsplashClient::{NotConfigured,RateLimited,Unavailable}`; `track_download` only sends the key to `https://api.unsplash.com/photos/:id/download`
- **BackgroundImageSearch** (`app/services/background_image_search.rb`) — Backs `backgroundImages`: normalizes/clamps args, caches results 12h per query+page, caches each photo's `download_location` 24h for `trackImageDownload`, 5-minute backoff after an Unsplash rate limit

## Authentication

All `POST /graphql` requests require an API key via the `Authorization: Bearer <token>` header.

- **Token prefixes**: `bql_live_` (production), `bql_test_` (development/test)
- **One key per email per environment** (unique constraint)
- Keys can be created via rake tasks or through the self-service request flow (admin approval required)
- **Installation keys**: client apps (bibleql-reader) call `registerInstallation` without an `Authorization` header. `GraphqlController#registration_request?` parses the query and skips auth only when the selected operation is a mutation whose root fields are all `registerInstallation`/`__typename` and no `Authorization` header is present. Clients may send `X-App-Version`; `Installation#touch_seen!` records it at most once an hour
- **Unsplash key**: `UNSPLASH_ACCESS_KEY` env (fallback `credentials.unsplash.access_key`) is server-only and must never appear in a response; `UNSPLASH_UTM_SOURCE` defaults to `bibleql-reader`
- **Deprecated keys**: `DEPRECATED_KEY_MESSAGE` / `READER_UPDATE_URL` env override the `extensions.updateRequired` message and link; each use is logged as `[deprecated_api_key]`
- GraphiQL and Playground have a headers panel for entering the API key

## Concordance Invariants

- Concordance results are **exhaustive and canonically ordered**, never ranked or truncated by
  relevance. This is the distinction from `search`.
- `verses.text_search` must be built with the translation's own `regconfig`. Never assume `english`.
- Concordance cache keys include `translation.concordance_indexed_at`, so a re-import invalidates
  automatically. Do not add manual cache-clearing logic.
- `context` contains `<mark>` HTML. Never interpolate user input into it beyond `plainto_tsquery`.
- Always use `plainto_tsquery`, never `to_tsquery`, for user-supplied words.

## Unsplash Proxy Invariants

- `backgroundImages` / `trackImageDownload` are for the BibleQL client apps only: keep them `installation_only: true`, and never document them on docs.bibleql.org (internal doc: `docs/background_images.md`).
- The Unsplash access key never leaves the server: not in responses, error messages or logs.
- `trackImageDownload` never fetches a client-supplied URL; it only pings `https://api.unsplash.com/photos/:id/download`.
- Unsplash failures are returned as `errorCode` in the payload, never as GraphQL errors or 500s.

## Offline Package Invariants

- Nothing is exported unless `translations.offline_downloadable` is true. Never default it to true, and never flag `db/biblelist/` translations without redistribution rights.
- `schema_v1.sql` is a client contract: never change it in place. Add `schema_v2.sql` and bump `SCHEMA_VERSION`.
- Storage keys are content-addressed and uploaded as immutable. Never overwrite an existing key.

## Skills

When working on Rails features, load and follow the guidelines in `.agents/skills/rails-expert/SKILL.md`. Reference files for specific topics (Active Record, Hotwire, RSpec, etc.) are in `.agents/skills/rails-expert/references/`.
