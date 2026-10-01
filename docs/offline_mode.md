# Plan: Offline translation packages

Goal: let clients (first of all **bibleql-reader** on Tauri desktop and Android) download a
complete translation once and read, compare, search and run concordance queries fully offline.

Approach: BibleQL exports each **redistributable** translation into a prebuilt, gzipped
**SQLite** file, uploads it to object storage (Cloudflare R2, S3-compatible), and advertises it
through GraphQL. Clients download the file, verify its checksum, and open it directly. They don't
import anything, parse XML, or replay SQL.

> **Model and column names below are assumptions** (`Translation`, `Book`, `Verse`, `identifier`,
> `note`, `position`, …). Adjust them to the real schema in `db/schema.rb` before implementing.

---

## Why this format

| Option | Problem |
| --- | --- |
| Serve Zefania/USFX/OSIS XML | Client must re-implement the import (bible_parser, localized book names, `book_names_from`, fixes). Two parsers drift apart. Slow first open on phones. |
| Serve a generated `.sql` dump | Postgres ≠ SQLite dialect. Replaying ~31k INSERTs is slow on mobile. A downloaded script is *code* the app executes. |
| **Prebuilt SQLite (chosen)** | Postgres stays the single source of truth. The file is plain *data*: download → verify → open. One file per translation makes delete and update trivial. FTS5 gives offline search. |

Static files on a CDN also keep downloads outside Rack::Attack and the 1,000 req/day key limit.
Downloading a Bible shouldn't use up anyone's API quota.

---

## Phase 0 — Licensing gate (do first)

Most Bible List translations are copyrighted. Nothing is exported unless it is explicitly allowed.

- Migration: `add_column :translations, :offline_downloadable, :boolean, null: false, default: false`
- Data migration / rake task: set `true` only for open-bibles translations whose license is
  Public Domain or a CC license that permits redistribution. Leave every `db/biblelist/`
  translation `false` unless you hold redistribution rights, even when API access is permitted.
- Add `offline_downloadable:` to the `config/biblelist_translations.yml` entries (default `false`)
  so the decision lives next to the source.
- The export job must **refuse** any translation where `offline_downloadable` is false.

**Done when:** `Translation.where(offline_downloadable: true)` lists exactly the translations you
have reviewed, and there is a spec asserting the job raises for a non-downloadable one.

---

## Phase 1 — Package format (the contract)

This is the contract with every client. Version it with `SCHEMA_VERSION` and never change v1 in
place.

```sql
PRAGMA application_id = 1112624177;  -- 0x42514C31, "BQL1": clients check this magic
PRAGMA user_version   = 1;           -- SCHEMA_VERSION

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- keys: schema_version, translation_identifier, translation_name, language_code,
--       language_name, license_note, source_digest, exported_at (ISO8601), verse_count

CREATE TABLE books (
  id        INTEGER PRIMARY KEY,   -- canonical position 1..66 (or more if apocrypha later)
  osis      TEXT NOT NULL,         -- "Gen", "John"
  name      TEXT NOT NULL,         -- localized name for this translation ("Juan")
  testament TEXT NOT NULL,         -- "OT" | "NT"
  chapters  INTEGER NOT NULL
);

CREATE TABLE verses (
  id      INTEGER PRIMARY KEY,     -- assigned in canonical order: ORDER BY id == canonical order
  book_id INTEGER NOT NULL REFERENCES books(id),
  chapter INTEGER NOT NULL,
  verse   INTEGER NOT NULL,
  text    TEXT NOT NULL
);
CREATE UNIQUE INDEX verses_ref ON verses(book_id, chapter, verse);

CREATE VIRTUAL TABLE verses_fts USING fts5(
  text,
  content = 'verses',
  content_rowid = 'id',
  tokenize = "unicode61 remove_diacritics 2"
);
```

Decisions:

- **`verses.id` in canonical order** makes the Reader's "exhaustive, canonically ordered"
  concordance a plain `ORDER BY v.id`.
- **FTS5 index is built server-side and shipped.** It makes the file larger, but the tokenizer
  settings are controlled in one place and clients need no post-processing step.
  `remove_diacritics 2` makes `espiritu` match `espíritu`, which matters for the Spanish
  translations.
- Finish with `VACUUM` and `journal_mode = DELETE` so the file is compact and self-contained
  (no `-wal`/`-shm` side files).
- Compression: gzip (Ruby stdlib `Zlib`, `flate2` on the Rust side). There is no zstd dependency
  for now.

Put this SQL in `app/services/offline_packages/schema_v1.sql` and document it in
`docs/offline_packages.md`.

---

## Phase 2 — Builder

Add the gem if it isn't already present: `gem "sqlite3"` (it only writes files, it is not
the app database). sqlite3-ruby 2.x ships a vendored SQLite; verify FTS5 is compiled in with a
spec: `SELECT sqlite_compileoption_used('ENABLE_FTS5')` → `1`.

`app/services/offline_packages/builder.rb` (sketch):

```ruby
module OfflinePackages
  class Builder
    SCHEMA_VERSION = 1
    SCHEMA_SQL = Rails.root.join("app/services/offline_packages/schema_v1.sql").read

    def initialize(translation)
      raise NotDownloadable, translation.identifier unless translation.offline_downloadable?
      @translation = translation
    end

    # Writes an uncompressed SQLite file to `path`. Returns the source digest.
    def build(path)
      db = SQLite3::Database.new(path)
      db.execute_batch(SCHEMA_SQL)

      db.transaction do
        insert_books(db)
        insert_verses(db)
        insert_meta(db)
      end

      db.execute("INSERT INTO verses_fts(verses_fts) VALUES('rebuild')")
      db.execute("VACUUM")
      source_digest
    ensure
      db&.close
    end

    def source_digest
      @source_digest ||= Digest::SHA256.hexdigest(
        { schema: SCHEMA_VERSION, books: book_rows, verses: verse_rows }.to_json
      )
    end

    private

    # Assumed columns — adapt to the real schema.
    def verse_rows
      @verse_rows ||= @translation.verses
        .joins(:book)
        .order("books.position, verses.chapter, verses.verse")
        .pluck("books.position", "verses.chapter", "verses.verse", "verses.text")
    end

    def insert_verses(db)
      stmt = db.prepare("INSERT INTO verses (id, book_id, chapter, verse, text) VALUES (?, ?, ?, ?, ?)")
      verse_rows.each.with_index(1) { |(book, ch, v, text), id| stmt.execute(id, book, ch, v, text) }
    ensure
      stmt&.close
    end

    # insert_books / book_rows: localized names for this translation, osis, testament, chapter count
    # insert_meta: keys listed in the format section; verse_count = verse_rows.size
  end
end
```

About 31k rows fit comfortably in memory, so `pluck` in one ordered query is simpler and faster
than `find_each`, which can't keep canonical order anyway.

`source_digest` is computed from the data, not the file bytes. It is how the job decides that
nothing changed and skips re-uploading.

---

## Phase 3 — Storage and publishing

**Bucket:** Cloudflare R2 (no egress fees, which is the cost that matters for downloads) with a
public custom domain, e.g. `https://downloads.bibleql.org`.

**Object keys are immutable and content-addressed:**

```
translations/{identifier}/v{schema_version}/{sha256}.sqlite.gz
```

Upload with `Cache-Control: public, max-age=31536000, immutable` and
`Content-Type: application/gzip`. A new export always means a new key, so CDN caches never
serve stale data and in-flight downloads of the old file don't break. Keep old objects for at
least 30 days (a lifecycle rule or cleanup task can delete them later).

Use `aws-sdk-s3` pointed at the R2 endpoint, not Active Storage. Stable public URLs and your
own sha256 are what's needed here, and Active Storage's blob URLs and MD5 checksums don't fit
that contract.

Config (Rails credentials, passed through Kamal secrets):

```yaml
offline_packages:
  r2_account_id: ...
  access_key_id: ...
  secret_access_key: ...
  bucket: bibleql-downloads
  public_base_url: https://downloads.bibleql.org
```

`app/services/offline_packages/publisher.rb`:
1. gzip the built file (`Zlib::GzipWriter`, streaming, level 9)
2. `sha256` and `size_bytes` of the **compressed** file (what the client downloads and verifies)
3. `put_object` with the headers above
4. return `{ storage_key:, url:, sha256:, size_bytes:, uncompressed_size_bytes: }`

---

## Phase 4 — Model and job

Migration:

```ruby
create_table :offline_packages do |t|
  t.references :translation, null: false, foreign_key: true
  t.integer :schema_version, null: false
  t.string  :storage_key, null: false
  t.string  :url, null: false
  t.string  :sha256, null: false          # of the .sqlite.gz
  t.bigint  :size_bytes, null: false
  t.bigint  :uncompressed_size_bytes, null: false
  t.string  :source_digest, null: false
  t.integer :verse_count, null: false
  t.timestamps
end
add_index :offline_packages, [:translation_id, :schema_version], unique: true
```

One row per translation per schema version, updated in place when a new export is published.

`app/jobs/export_offline_package_job.rb` (Solid Queue):

```ruby
class ExportOfflinePackageJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(translation_id) { "offline-export-#{translation_id}" }

  def perform(translation_id, force: false)
    translation = Translation.find(translation_id)
    builder = OfflinePackages::Builder.new(translation)
    existing = translation.offline_packages.find_by(schema_version: OfflinePackages::Builder::SCHEMA_VERSION)
    return if existing && existing.source_digest == builder.source_digest && !force

    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{translation.identifier}.sqlite")
      builder.build(path)
      result = OfflinePackages::Publisher.new(translation, path).publish
      OfflinePackage.upsert(
        result.merge(translation_id: translation.id,
                     schema_version: OfflinePackages::Builder::SCHEMA_VERSION,
                     source_digest: builder.source_digest,
                     verse_count: builder.verse_count,
                     updated_at: Time.current),
        unique_by: [:translation_id, :schema_version]
      )
    end
  end
end
```

Rake tasks (`lib/tasks/offline.rake`):

```
bundle exec rake offline:list                     # downloadable translations + package status/size
bundle exec rake "offline:export_one[spa-rv1909]" # enqueue one (FORCE=1 to skip digest check)
bundle exec rake offline:export_all               # enqueue all downloadable translations
```

Hook into imports: at the end of `bible:import_one` / `biblelist:import_one`, enqueue
`ExportOfflinePackageJob` when the translation is `offline_downloadable`. Fixing an import bug then
automatically republishes the package.

---

## Phase 5 — GraphQL

```graphql
type OfflinePackage {
  url: String!
  sha256: String!
  sizeBytes: Int!                # compressed download size, for the UI ("2.4 MB")
  uncompressedSizeBytes: Int!    # disk space needed
  schemaVersion: Int!
  verseCount: Int!
  updatedAt: ISO8601DateTime!
}

type Translation {
  # ...existing fields
  offlineDownloadable: Boolean!
  offlinePackage(schemaVersion: Int = 1): OfflinePackage   # null if not downloadable or not yet exported
}
```

Clients pass the highest `schemaVersion` they understand. Keep publishing v1 for as long as
released Reader builds might request it.

Avoid N+1 queries when listing `translations { offlinePackage { … } }`: use `GraphQL::Dataloader`
or `includes(:offline_packages)`. Also add an example to `docs/example_queries.md`.

---

## Phase 6 — Tests (RSpec)

- **Builder**, using a small fixture translation:
  - opens the output file; `PRAGMA user_version` = 1 and `application_id` is correct
  - `books` and `verses` counts match Postgres; `verses.id` follows canonical order
  - localized book names are used (a Spanish fixture gives `Juan`)
  - FTS: `SELECT … FROM verses_fts WHERE verses_fts MATCH 'espiritu'` finds a verse containing `espíritu`
  - FTS5 is compiled in
  - raises `NotDownloadable` for a non-downloadable translation
- **Publisher:** `Aws::S3::Client.new(stub_responses: true)`; asserts the key format, headers,
  and that the sha256 matches the gzipped bytes
- **Job:** skips when `source_digest` is unchanged; republishes with `force: true`; upserts rather
  than duplicating
- **GraphQL:** `offlinePackage` is null for non-downloadable translations and returns the fields
  for exported ones; there are no N+1 queries on `translations`

---

## Phase 7 — Rollout

1. Deploy the migrations and code with no translations flagged yet.
2. Configure the R2 bucket, custom domain and credentials (Kamal secrets).
3. Flag one public-domain translation (e.g. `eng-web`), run `offline:export_one`, then download
   the file by hand and inspect it with `sqlite3` (`.tables`, an FTS query, `PRAGMA integrity_check`).
4. Flag the reviewed translations and run `offline:export_all`.
5. Announce the GraphQL fields and document the package format so the Reader (and other
   clients) can build against it.

---

## Client contract (for bibleql-reader, not implemented here)

For reference, so both sides agree on it:

1. Query `translations { identifier offlinePackage(schemaVersion: 1) { url sha256 sizeBytes … } }`.
2. Download in Rust to `app_data_dir/bibles/{identifier}.v1.sqlite.gz.tmp` and emit progress events.
3. Verify sha256 → gunzip → check `application_id` and `user_version` → atomic rename to
   `{identifier}.v1.sqlite`. Store the sha256 locally.
4. Open the file read-only. When online, compare the local sha256 with `offlinePackage.sha256`
   and offer "Update available".
5. Show `meta.license_note` exactly as it does today in the status bar.

---

## Open questions

- Should packages include apocrypha/deuterocanonical books for translations that have them?
  (The `books.id` scheme would need positions beyond 66.)
- Do you want a public manifest (`/offline/manifest.json`) as well, for clients that don't use
  GraphQL? It is cheap to add later from the same table.
- Is there a per-translation expected size budget? If the FTS index makes files too large for
  mobile downloads, v2 could ship without it and have clients run `rebuild` on device.
