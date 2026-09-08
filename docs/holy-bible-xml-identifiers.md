# How Holy-Bible-XML-Format identifiers are derived

`db/holy-bible-xml/` (the [Holy-Bible-XML-Format](https://github.com/lporras/Holy-Bible-XML-Format)
submodule) has no per-file metadata table like `config/biblelist_translations.yml` — with 1,000+
files across 200+ languages, hand-curating one entry per file isn't practical. Instead,
`HolyBibleXmlFilenameParser` derives everything (`Translation#identifier`, `#language`,
`#language_name`, `#abbrev`) straight from the filename. This is a **best-effort** heuristic, not
a lookup — it gets the common cases right and degrades gracefully on the rest.

## The algorithm

Given a filename like `AmharicDawroDFBEBible.xml`:

1. **Strip the suffix.** Drop the trailing `Bible.xml` (case-insensitive), leaving
   `AmharicDawroDFBE`.
2. **Split into words** at PascalCase/digit boundaries, keeping a run of capitals together as one
   word instead of splitting every letter (so an acronym like `SVD` or `DFBE` isn't torn apart):
   `AmharicDawroDFBE` → `["Amharic", "Dawro", "DFBE"]`.
3. **Match the language.** Try the *longest* leading run of words against
   `config/language_codes.yml` (a curated `"Language Name" => "iso_code"` map), then shorter runs,
   down to just the first word. The first match wins:
   - `"Amharic Dawro DFBE"` → not in the table
   - `"Amharic Dawro"` → not in the table
   - `"Amharic"` → **`amh`** ✓
   - If nothing matches at all, the first word alone becomes the language: lowercased, used
     verbatim as both the code and the display name (e.g. a language not yet in the table becomes
     its own slug — see [Fallback languages](#fallback-languages-not-in-the-table) below).
4. **Everything left over is the variant**: `["Dawro", "DFBE"]` → lowercased and hyphenated →
   `dawro-dfbe`.
5. **Identifier** = `"#{language_code}-#{variant}"`, or just `language_code` if there's no
   variant (a bare `AfrikaansBible.xml` → `afr`, no trailing dash).
6. **Abbreviation**: if the variant is a *single* word and it's all-caps in the original filename
   (e.g. `SVD`, `NIV`, `LSB`), it's used as `Translation#abbrev` too. A multi-word variant
   (`dawro-dfbe`) or a plain year (`1983`) is not treated as an abbreviation.

## Worked examples

| Filename                          | Words                          | Language match | Identifier          | Abbrev |
|------------------------------------|---------------------------------|-----------------|----------------------|--------|
| `AfrikaansBible.xml`               | `Afrikaans`                     | `afr`           | `afr`                | —      |
| `Afrikaans1983Bible.xml`           | `Afrikaans`, `1983`              | `afr`           | `afr-1983`           | —      |
| `ArabicSVDBible.xml`               | `Arabic`, `SVD`                  | `ara`           | `ara-svd`            | `SVD`  |
| `AmharicDawroDFBEBible.xml`        | `Amharic`, `Dawro`, `DFBE`        | `amh`           | `amh-dawro-dfbe`     | —      |
| `BalochiSoutherenLatinBible.xml`   | `Balochi`, `Southeren`, `Latin`   | `bal`           | `bal-southeren-latin`| —      |

## Why this doubles as cross-source dedup

The `<lang>-<variant>` shape deliberately mirrors the identifier convention already used by
`BibleImporter` (`eng-web`) and `BiblelistImporter` (`eng-niv`). So when this source happens to
carry the same translation under a recognizable name — e.g. `EnglishNIVBible.xml` deriving
`eng-niv` — it lands on the *same* identifier as the one already imported from `db/biblelist/`,
and `HolyBibleXmlImporter` skips it as already-imported rather than creating a duplicate row. This
is a happy consequence of the naming convention, not a guarantee: a translation can still be
imported twice under different identifiers if this source's filename doesn't happen to match the
abbreviation used elsewhere.

## Fallback languages not in the table

`config/language_codes.yml` is seeded from `config/text_search_configs.yml` (so every language
that already has real PostgreSQL text-search stemming keeps it) plus a handful of other common
languages — it does not attempt to cover all 200+ languages in the source repo. A language not in
the table still imports fine: it just gets a slug of its own name as both `language` and
`language_name` (e.g. a hypothetical `ZarmaBible.xml` → `language: "zarma"`), and
`TextSearchConfigResolver` safely falls back to the `"simple"` (non-stemmed) text search
configuration for any code it doesn't recognize — so an unmapped language is never a correctness
bug, just less precise concordance stemming.

Add an entry to `config/language_codes.yml` any time you want a specific language imported through
this source to line up with its proper ISO 639-3 code (for stemming, or for grouping with
same-language translations from other sources in the `languages` query).

## Known limitations

- A language name that is itself multiple words and **not yet** in `config/language_codes.yml`
  (e.g. a regional dialect like `AdilabadGondiBible.xml`) is split at the first word only —
  `Adilabad` becomes the "language" and `Gondi` becomes part of the variant. Add a multi-word
  entry to the table (e.g. `"Adilabad Gondi": <code>`) to fix a specific case.
- A purely numeric variant (a year) is never mistaken for an abbreviation, but a genuine
  alphabetic abbreviation that happens to also be a real word won't be distinguished from a
  descriptive variant name — the all-caps check is a heuristic, not certainty.
