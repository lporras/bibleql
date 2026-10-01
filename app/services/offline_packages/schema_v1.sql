-- BibleQL offline package, schema v1. This is the contract with every client
-- (see docs/offline_packages.md). Never change it in place: add schema_v2.sql.

PRAGMA application_id = 1112624177;  -- 0x42514C31, "BQL1": clients check this magic
PRAGMA user_version   = 1;           -- OfflinePackages::Builder::SCHEMA_VERSION

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE books (
  id        INTEGER PRIMARY KEY,   -- canonical position 1..66
  code      TEXT NOT NULL UNIQUE,  -- "GEN", "JHN" (BibleQL book_id)
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
