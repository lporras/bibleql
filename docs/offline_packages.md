# Offline translation packages

BibleQL exports each redistributable translation as a gzipped **SQLite** file. Clients (first of
all bibleql-reader) download it once, verify it, and open it directly to read, compare, search and
run concordance queries offline. They don't import anything, parse XML, or replay SQL. Downloads
come from a CDN (Cloudflare R2), not the API, so they don't count against rate limits or API key
quotas.

The design rationale is in [offline_mode.md](offline_mode.md). This page is the contract.

## Discovering packages (GraphQL)

```graphql
{
  translations {
    identifier
    offlineDownloadable
    offlinePackage(schemaVersion: 1) { url sha256 sizeBytes uncompressedSizeBytes schemaVersion verseCount updatedAt }
  }
}
```

- `offlinePackage` is `null` when the translation's license doesn't allow redistribution
  (`offlineDownloadable: false`) or when no package has been exported yet.
- Pass the highest `schemaVersion` the client understands. v1 stays published for as long as
  released clients may request it.
- `url` is immutable and content-addressed
  (`translations/{identifier}/v{schema}/{sha256}.sqlite.gz`). A new export gets a new URL, so
  "update available" means `offlinePackage.sha256` differs from the sha256 stored locally.

## Client procedure

1. Download `url` to a temporary file, e.g. `{identifier}.v1.sqlite.gz.tmp`.
2. Verify that the SHA-256 of the downloaded bytes equals `sha256`. Discard the file if it doesn't.
3. Gunzip, then check `PRAGMA application_id` = `1112624177` (`0x42514C31`, "BQL1") and
   `PRAGMA user_version` = the requested schema version.
4. Atomically rename the file to `{identifier}.v1.sqlite` and store the sha256 locally.
5. Open the file read-only. Show `meta.license_note` wherever the translation is displayed.

## File format, schema v1

The authoritative DDL is
[`app/services/offline_packages/schema_v1.sql`](../app/services/offline_packages/schema_v1.sql).
It never changes in place. A breaking change adds schema v2.

| Table | Columns | Notes |
| --- | --- | --- |
| `meta` | `key`, `value` (TEXT) | Keys: `schema_version`, `translation_identifier`, `translation_name`, `translation_abbrev`, `language_code`, `language_name`, `license_note`, `source_digest`, `exported_at` (ISO 8601), `verse_count` |
| `books` | `id` (canonical position 1–66), `code` (`GEN`, `JHN`, the same as BibleQL `bookId`), `name` (localized, e.g. `Juan`), `testament` (`OT`/`NT`), `chapters` | Only books the translation contains |
| `verses` | `id`, `book_id` → `books.id`, `chapter`, `verse`, `text` | `id` is assigned in canonical order, so `ORDER BY id` is canonical order. Unique index on `(book_id, chapter, verse)` |
| `verses_fts` | FTS5 over `verses.text` (external content, `content_rowid = id`) | Tokenizer `unicode61 remove_diacritics 2`: `espiritu` matches `espíritu` |

Examples:

```sql
-- John 3:16
SELECT v.text FROM verses v JOIN books b ON b.id = v.book_id
WHERE b.code = 'JHN' AND v.chapter = 3 AND v.verse = 16;

-- Concordance: every verse containing a word, in canonical order (never ranked)
SELECT v.id, b.name, v.chapter, v.verse, v.text
FROM verses_fts f JOIN verses v ON v.id = f.rowid JOIN books b ON b.id = v.book_id
WHERE verses_fts MATCH 'espiritu' ORDER BY v.id;

-- Search with highlighting
SELECT rowid, highlight(verses_fts, 0, '<mark>', '</mark>') FROM verses_fts WHERE verses_fts MATCH 'amor';
```

Size for reference: spa-rv1909 is about 7.2 MB uncompressed and 3.2 MB gzipped, FTS index included.

## Operating it (server side)

### Licensing gate

Nothing is exported unless `translations.offline_downloadable` is true. The flag defaults to
false. API access is not the same as redistribution rights: the `db/biblelist/` translations are
copyrighted and stay `false` (`offline_downloadable:` in `config/biblelist_translations.yml`).

```bash
DRY_RUN=1 bundle exec rake offline:flag_public_domain   # preview: flags notes matching "Public Domain"
bundle exec rake offline:flag_public_domain
bundle exec rake "offline:flag[eng-web,true]"            # flag/unflag one by hand
```

The flag can also be toggled in the admin panel under **Offline Packages**.

### Storage configuration

| ENV | Credentials fallback (`offline_packages.*`) | Example |
| --- | --- | --- |
| `OFFLINE_R2_ACCOUNT_ID` | `account_id` | Cloudflare account ID |
| `OFFLINE_R2_ACCESS_KEY_ID` | `access_key_id` | R2 API token (Object Read & Write, scoped to the bucket) |
| `OFFLINE_R2_SECRET_ACCESS_KEY` | `secret_access_key` | |
| `OFFLINE_R2_BUCKET` | `bucket` | `bibleql-downloads` |
| `OFFLINE_PUBLIC_BASE_URL` | `public_base_url` | `https://downloads.bibleql.org` (or the bucket's `https://pub-….r2.dev` URL in development) |

In development, put these in `.env` (gitignored, loaded by dotenv-rails). Until all five are
set, exports are refused and the import hook does nothing. Check the setup with:

```bash
bundle exec rake offline:check_storage   # head bucket, upload a probe, fetch it via the public URL, delete it
```

### Exporting

Exports run as `ExportOfflinePackageJob` on Solid Queue, so a worker must be running: `bin/jobs`
(or `bin/dev`, which starts it) in development, and `SOLID_QUEUE_IN_PUMA=true` on the web service
in production.

```bash
bundle exec rake offline:list                       # downloadable translations + package status
bundle exec rake "offline:export_one[spa-rv1909]"   # FORCE=1 republishes even if nothing changed
bundle exec rake offline:export_all
```

- The job skips the upload when the translation's `source_digest` (a hash of the data, not the
  file bytes) matches the published package, unless forced.
- Every import (`bible:`, `biblelist:`, `holy_bible_xml:`) enqueues an export for downloadable
  translations, so fixing an import bug republishes automatically.
- In the admin panel, **Offline Packages** has a **Generate** button per translation and a batch
  action for several. Both force a republish.
- Uploaded objects are immutable (`Cache-Control: public, max-age=31536000, immutable`). Old
  versions are left in the bucket, so configure an R2 lifecycle rule to delete objects under
  `translations/` older than 30+ days.
