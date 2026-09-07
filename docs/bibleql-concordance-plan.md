# BibleQL — Plan de implementación: Concordancia bíblica

> Documento guía para sesiones de Claude Code en el repo `bibleql/`.
> Estilo: épicas tagueadas `[MVP]` / `[Phase 2]`, identificadores en inglés (convención Rails),
> UI/docs bilingües EN/ES.

---

## 0. Contexto

BibleQL ya expone `search(translation, query, limit)` (full-text) y `semanticSearch(query, limit)`
(embeddings vía RubyLLM + pgvector). Ninguna de las dos es una **concordancia**.

Diferencia funcional, que es la que justifica queries nuevos:

| | `search` | `semanticSearch` | `concordance` |
|---|---|---|---|
| Resultado | top-N rankeado | top-N por similitud | **exhaustivo** |
| Orden | relevancia | similitud | **canónico** (Gn → Ap) |
| Agregados | no | no | **conteo por libro / testamento** |
| Contexto | versículo completo | versículo completo | **KWIC** (palabra resaltada en su frase) |
| Cobertura | 47 traducciones | 1 traducción | 47 traducciones (nivel 1) |

El objetivo del MVP es el **nivel 1** (concordancia verbal): índice invertido sobre el texto de cada
traducción, sin datos externos. El **nivel 2** (concordancia analítica con números Strong) queda en
Phase 2 porque depende de importar datos etiquetados con licencia verificada.

### Alcance del MVP

- `concordance(...)` — ocurrencias exhaustivas y paginadas de una palabra, con agregados.
- `concordanceIndex(...)` — índice alfabético de palabras con frecuencias.
- Funciona en las 47 traducciones (con stemming donde PostgreSQL lo soporta, coincidencia exacta en el resto).
- Documentado en `README.md`, `CLAUDE.md`, `docs/example_queries.md` y el playground.

### Fuera del alcance del MVP

- Números Strong, léxico hebreo/griego, interlineal → Phase 2.
- Referencias cruzadas (TSK) → no planeado aquí.
- UI web de concordancia → consumidor de la API, repo aparte.

---

## 1. Fase 0 — Verificaciones previas (bloqueante)

**No escribas código hasta resolver estos cinco puntos.** El plan asume respuestas que hay que confirmar
contra el schema real.

### 0.1 ¿Cómo está implementado `search` hoy?

```bash
grep -rn "search" app/graphql/ app/services/ --include=*.rb
cat db/schema.rb | grep -A5 "create_table \"verses\""
```

- **Si ya usa `tsvector`** → la migración de E1 se reduce a agregar `translations.text_search_config`
  y re-poblar el vector con el `regconfig` correcto por idioma. Documenta qué config usaba antes.
- **Si usa `ILIKE` / `LIKE`** → E1 va completa, y considera migrar `search` al mismo índice
  (mejora de rendimiento gratis, pero hazlo en un commit separado).

### 0.2 ¿`Book` tiene orden canónico?

```bash
grep -A15 "create_table \"books\"" db/schema.rb
```

La concordancia **debe** ordenarse Génesis → Apocalipsis. Si `books` no tiene una columna `position`
(o `sort_order`, `canonical_order`), agrégala en E1 y pobla con el orden de los 66 libros. Ordenar por
`book_id` alfabéticamente sería incorrecto (`ACT` antes de `GEN`).

### 0.3 ¿Qué Reina Valera está importada?

```bash
bin/rails runner 'puts Translation.where("identifier LIKE ?", "spa%").pluck(:identifier, :name)'
```

Registra el identificador real. Los ejemplos de este documento usan `spa-rv1909`; **ajústalos** al
identificador que exista. Si no hay RV1909, ver nota en E7 — es la traducción estratégica para Phase 2.

### 0.4 ¿`semanticSearch` está documentado?

`CLAUDE.md` y `README.md` en `main` **no** mencionan `semanticSearch`, pero `ruby_llm` está en el
Gemfile. Antes de agregar queries nuevos, documenta el existente (ver E5.4). Un `CLAUDE.md`
desactualizado degrada todas las sesiones futuras.

### 0.5 Versión de PostgreSQL

```bash
bin/rails runner 'puts ActiveRecord::Base.connection.select_value("SELECT version()")'
```

Necesitas ≥ 12 para `ts_headline` con las opciones usadas aquí. Confirma también qué diccionarios hay:

```sql
SELECT cfgname FROM pg_ts_config ORDER BY cfgname;
```

---

## 2. Decisiones de arquitectura (no las re-litigues)

Estas ya se discutieron. Están aquí para que no se reabran a mitad de implementación.

**La concordancia vive dentro de BibleQL, no en una app aparte.** Es una vista sobre el corpus que ya
posee este repo. Sacarla implicaría duplicar el corpus o llamar a la propia API.

**PostgreSQL, no base de grafos.** Las travesías son de profundidad fija (`palabra → verses`,
`strongs → occurrences → verses`). Eso es un B-tree sobre foreign key, no un grafo. Además, mantener
embeddings y concordancia en el mismo datastore permite componer ambas en una sola query.

**Sin columna generada para `text_search`.** El `regconfig` depende del idioma de la traducción, y una
columna generada exige config constante. Se puebla desde `BibleImporter` y desde un rake de backfill.

**Cache con TTL infinito.** El corpus es inmutable tras el import. Una vez calculada, la concordancia de
una palabra nunca cambia. Invalidación solo al re-importar una traducción.

**Paginación por cursor, no por offset.** `totalCount` puede ser de miles; offset se degrada y produce
resultados inconsistentes.

---

## 3. Épicas

### E1 `[MVP]` — Infraestructura de índice

**Objetivo:** que cada `Verse` tenga un `tsvector` construido con el diccionario correcto para el idioma
de su traducción.

#### E1.1 Migraciones

```ruby
# db/migrate/XXXXXX_add_text_search_to_verses.rb
class AddTextSearchToVerses < ActiveRecord::Migration[8.1]
  def change
    add_column :verses, :text_search, :tsvector
    add_index  :verses, :text_search, using: :gin

    add_column :translations, :text_search_config, :string, null: false, default: "simple"
    add_column :translations, :has_stemming, :boolean, null: false, default: false
    add_column :translations, :concordance_indexed_at, :datetime
  end
end
```

```ruby
# db/migrate/XXXXXX_add_position_to_books.rb   ← SOLO si Fase 0.2 lo confirma necesario
class AddPositionToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :position, :integer
    add_index  :books, :position, unique: true
  end
end
```

Índice compuesto para el orden canónico de la concordancia:

```ruby
add_index :verses, [:translation_id, :book_id, :chapter, :verse_number],
          name: "index_verses_on_canonical_order"
```

#### E1.2 Mapeo idioma → diccionario

Crear `config/text_search_configs.yml`. Las claves son el prefijo ISO 639-3 del identificador de la
traducción (`spa-rv1909` → `spa`):

```yaml
# ISO 639-3 → nombre de configuración de PostgreSQL
ara: arabic
cat: catalan
dan: danish
deu: german
ell: greek
eng: english
eus: basque
fin: finnish
fra: french
ger: german
gle: irish
gre: greek
hin: hindi
hun: hungarian
hye: armenian
ind: indonesian
ita: italian
lit: lithuanian
nep: nepali
nld: dutch
nor: norwegian
por: portuguese
ron: romanian
rus: russian
spa: spanish
srp: serbian
swe: swedish
tam: tamil
tur: turkish
yid: yiddish
# cualquier otro idioma → "simple" (sin stemming, coincidencia exacta de forma)
```

```ruby
# app/services/text_search_config_resolver.rb
class TextSearchConfigResolver
  CONFIGS = YAML.load_file(Rails.root.join("config/text_search_configs.yml")).freeze
  DEFAULT = "simple"

  def self.for(identifier)
    CONFIGS.fetch(identifier.to_s.split("-").first, DEFAULT)
  end

  def self.stemming?(identifier) = self.for(identifier) != DEFAULT
end
```

**Validar contra la base, no confiar en el YAML.** Si el diccionario no existe en esta instalación de
Postgres, caer a `simple` con un warning en el log en vez de reventar en runtime.

#### E1.3 Poblado del vector

Servicio idempotente, en batches, seguro para re-ejecutar:

```ruby
# app/services/concordance_indexer.rb
class ConcordanceIndexer
  BATCH_SIZE = 5_000

  def initialize(translation)
    @translation = translation
    @config = TextSearchConfigResolver.for(translation.identifier)
  end

  def call
    @translation.update!(
      text_search_config: @config,
      has_stemming: TextSearchConfigResolver.stemming?(@translation.identifier)
    )

    @translation.verses.in_batches(of: BATCH_SIZE) do |batch|
      batch.update_all(
        ActiveRecord::Base.sanitize_sql_array(
          ["text_search = to_tsvector(?::regconfig, text)", @config]
        )
      )
    end

    @translation.update!(concordance_indexed_at: Time.current)
  end
end
```

#### E1.4 Enganche en el importador

`BibleImporter` y `BiblelistImporter` deben llamar a `ConcordanceIndexer` al final de cada import.
Verificar que ambos comparten un punto de salida; si no, agregarlo en los dos.

#### E1.5 Rake tasks

```ruby
# lib/tasks/concordance.rake
namespace :concordance do
  desc "Build the text search index for all translations (or one)"
  task :index, [:identifier] => :environment do |_t, args|
    scope = args[:identifier] ? Translation.where(identifier: args[:identifier]) : Translation.all
    scope.find_each do |translation|
      print "Indexing #{translation.identifier}... "
      ConcordanceIndexer.new(translation).call
      puts "done (#{translation.text_search_config})"
    end
  end

  desc "Show indexing status per translation"
  task status: :environment do
    # identifier | config | stemming | indexed_at | verses sin vector
  end

  desc "Refresh the concordance_word_index materialized view"
  task refresh_index: :environment do
    ActiveRecord::Base.connection.execute(
      "REFRESH MATERIALIZED VIEW CONCURRENTLY concordance_word_index"
    )
  end
end
```

**Definition of done E1:** `rake concordance:status` muestra las 47 traducciones indexadas, con
`spanish` en las traducciones `spa-*` y `english` en las `eng-*`.

---

### E2 `[MVP]` — Servicio `ConcordanceLookup`

**Objetivo:** encapsular toda la lógica SQL. El resolver de GraphQL no debe contener SQL.

```ruby
# app/services/concordance_lookup.rb
class ConcordanceLookup
  MAX_PAGE_SIZE = 100
  DEFAULT_PAGE_SIZE = 25

  Result = Struct.new(:entry, :occurrences, :total_count, :has_next_page, :end_cursor,
                      keyword_init: true)

  def initialize(translation:, word:, book: nil, testament: nil)
    @translation = translation
    @word = word.to_s.strip
    @book = book
    @testament = testament
    @config = translation.text_search_config
  end

  def call(first: DEFAULT_PAGE_SIZE, after: nil)
    # ...
  end

  # Agregados — cacheables por separado de la página
  def total_count
  def counts_by_book        # => [{ book_id:, book_name:, count: }, ...]
  def counts_by_testament   # => { old:, new: }
  def surface_forms         # formas reales encontradas, para UI legible
end
```

#### E2.1 Query base

```ruby
def scope
  s = @translation.verses
        .where("verses.text_search @@ plainto_tsquery(?::regconfig, ?)", @config, @word)
  s = s.where(book_id: @book) if @book
  s = s.joins(:book).where(books: { testament: @testament }) if @testament
  s
end
```

`plainto_tsquery`, no `to_tsquery`: acepta entrada del usuario sin sintaxis de operadores y no lanza
excepción con input arbitrario. Esto también es la defensa contra inyección de sintaxis tsquery.

#### E2.2 Contexto KWIC

```ruby
HEADLINE_OPTS = "StartSel=<mark>, StopSel=</mark>, MaxWords=25, MinWords=10, " \
                "MaxFragments=1, FragmentDelimiter= … "

def with_context(relation)
  relation.select(
    "verses.*",
    ActiveRecord::Base.sanitize_sql_array([
      "ts_headline(?::regconfig, verses.text, plainto_tsquery(?::regconfig, ?), ?) AS context",
      @config, @config, @word, HEADLINE_OPTS
    ])
  )
end
```

`<mark>` en la salida es HTML. **Documentar explícitamente en el schema** que `context` contiene markup
y que el cliente debe sanitizarlo o renderizarlo con cuidado. El texto base ya viene de fuentes
confiables (los XML importados), pero dilo igual en la descripción del campo.

#### E2.3 Orden canónico y cursor

```ruby
def ordered(relation)
  relation.joins(:book).order("books.position ASC, verses.chapter ASC, verses.verse_number ASC")
end
```

Cursor keyset codificado en Base64 sobre la tupla `(book_position, chapter, verse_number)`:

```ruby
def encode_cursor(verse)
  Base64.urlsafe_encode64([verse.book.position, verse.chapter, verse.verse_number].join(":"))
end

def apply_cursor(relation, cursor)
  return relation if cursor.blank?
  pos, chapter, verse_number = Base64.urlsafe_decode64(cursor).split(":").map(&:to_i)
  relation.where(
    "(books.position, verses.chapter, verses.verse_number) > (?, ?, ?)",
    pos, chapter, verse_number
  )
rescue ArgumentError
  raise GraphQL::ExecutionError, "Invalid cursor"
end
```

#### E2.4 `surfaceForms`

El `lemma` que devuelve el stemmer español es feo (`misericordi`). El cliente necesita las formas reales:

```ruby
def surface_forms(limit: 10)
  # Extraer los términos que efectivamente matchearon, deduplicados y en minúscula.
  # Implementación recomendada: ts_stat acotado a los verses del scope,
  # o regex sobre el output de ts_headline de una muestra.
end
```

Si resulta caro, es aceptable derivarlo de una muestra de las primeras 100 ocurrencias. Documenta la
decisión en el código.

#### E2.5 Índice alfabético — vista materializada

`ts_stat` sobre toda la tabla en cada request es inviable. Vista materializada, refrescada tras cada
import:

```sql
CREATE MATERIALIZED VIEW concordance_word_index AS
SELECT
  v.translation_id,
  s.word AS lemma,
  s.ndoc AS verse_count,
  s.nentry AS total_occurrences
FROM translations t
CROSS JOIN LATERAL ts_stat(
  format('SELECT text_search FROM verses WHERE translation_id = %s', t.id)
) s
JOIN verses v ON v.translation_id = t.id AND FALSE  -- placeholder, ver nota
;

CREATE UNIQUE INDEX ON concordance_word_index (translation_id, lemma);
CREATE INDEX ON concordance_word_index (translation_id, lemma text_pattern_ops);
```

> **Nota para el implementador:** `ts_stat` toma una query SQL como *string* y no se combina bien con
> `CROSS JOIN LATERAL` sobre una tabla. Es probable que tengas que generar la vista con un bloque
> `DO`/PL-pgSQL que itere las traducciones e inserte en una tabla real `concordance_word_index`, en vez
> de una vista materializada. **Evalúa ambas y elige la que funcione**; el contrato hacia arriba (tabla
> con `translation_id, lemma, verse_count, total_occurrences`) es lo que importa. Si optas por tabla
> real, el refresh va en `ConcordanceIndexer`.

El índice `text_pattern_ops` es el que hace rápido el filtro por `prefix`.

**Definition of done E2:** specs de `ConcordanceLookup` en verde, incluyendo palabra inexistente,
palabra con acentos, palabra con mayúsculas, cursor inválido, y traducción sin stemming.

---

### E3 `[MVP]` — Tipos y queries GraphQL

**Ubicación:** seguir la estructura existente en `app/graphql/`.

#### E3.1 Tipos

```ruby
# app/graphql/types/concordance_entry_type.rb
module Types
  class ConcordanceEntryType < Types::BaseObject
    description "Aggregate information about a word across a translation"

    field :lemma, String, null: false,
      description: "Normalized stem as produced by the translation's text search dictionary. " \
                   "May not be a readable word — use surfaceForms for display."
    field :surface_forms, [String], null: false,
      description: "Actual word forms found in the text (e.g. amó, amaba, amado)"
    field :total_occurrences, Integer, null: false
    field :verse_count, Integer, null: false,
      description: "Number of distinct verses containing the word"
    field :occurrences_by_book, [Types::BookCountType], null: false
    field :occurrences_by_testament, Types::TestamentCountType, null: false
  end
end
```

```ruby
# app/graphql/types/concordance_occurrence_type.rb
field :verse, Types::VerseType, null: false
field :context, String, null: false,
  description: "Keyword-in-context snippet. Contains <mark> HTML tags around the matched " \
               "term — sanitize before rendering as HTML."
field :strongs, Types::StrongsEntryType, null: true,
  description: "Null unless the translation has Strong's tagging. See translation.hasStrongsTagging."
```

`strongs` se declara en el MVP devolviendo siempre `null`. Así el schema queda estable y Phase 2 no es
un breaking change.

```ruby
# app/graphql/types/book_count_type.rb
field :book_id, String, null: false
field :book_name, String, null: false   # localizado según la traducción
field :count, Integer, null: false

# app/graphql/types/testament_count_type.rb
field :old, Integer, null: false
field :new, Integer, null: false

# app/graphql/types/testament_type.rb  (enum)
value "OLD"
value "NEW"
```

Connection:

```ruby
# app/graphql/types/concordance_connection_type.rb
field :entry, Types::ConcordanceEntryType, null: false
field :total_count, Integer, null: false
field :edges, [Types::ConcordanceEdgeType], null: false
field :page_info, Types::PageInfoType, null: false
```

Si graphql-ruby ya genera connections en el repo, reutiliza el mecanismo existente en vez de escribir
la connection a mano. Revisa `app/graphql/types/` antes de decidir.

#### E3.2 Campos nuevos en tipos existentes

```ruby
# Types::TranslationType
field :has_stemming, Boolean, null: false,
  description: "Whether concordance queries apply linguistic stemming for this translation. " \
               "When false, only exact word forms match."
field :has_strongs_tagging, Boolean, null: false,
  description: "Whether verses in this translation carry Strong's number annotations"
field :concordance_indexed_at, GraphQL::Types::ISO8601DateTime, null: true
```

`hasStrongsTagging` devuelve `false` para todas en el MVP.

#### E3.3 Resolvers

```ruby
# app/graphql/resolvers/concordance_resolver.rb
module Resolvers
  class ConcordanceResolver < Resolvers::BaseResolver
    type Types::ConcordanceConnectionType, null: false

    argument :translation, String, required: true
    argument :word, String, required: true
    argument :book, String, required: false,
      description: "Canonical book id (e.g. PSA) or localized book name (e.g. Salmos)"
    argument :testament, Types::TestamentType, required: false
    argument :first, Integer, required: false, default_value: 25
    argument :after, String, required: false

    def resolve(translation:, word:, first:, **args)
      first = first.clamp(1, ConcordanceLookup::MAX_PAGE_SIZE)
      # ...
    end
  end
end
```

Validaciones que deben lanzar `GraphQL::ExecutionError` con mensaje claro:

- traducción inexistente
- traducción no indexada (`concordance_indexed_at` nulo) → sugerir `rake concordance:index`
- `word` vacío o solo espacios
- `word` de más de 100 caracteres
- `book` que no resuelve (aceptar tanto `book_id` como nombre localizado, reutilizando la lógica de
  `PassageLookup`)

#### E3.4 Complejidad

Con `max_complexity: 300`, `concordance` con `first: 100` y `verse` anidado se pasa. Definir:

```ruby
field :concordance, resolver: Resolvers::ConcordanceResolver,
      complexity: ->(_ctx, args, child_complexity) {
        ((args[:first] || 25) * child_complexity) / 5
      }
```

Verifica con el query de E5.3 (el que combina `concordance` + `semanticSearch` + `strongsEntry`) que no
se pase del límite. **Si se pasa, ajusta el divisor antes de subir `max_complexity`** — el límite global
protege contra abuso y no debería moverse por una feature.

#### E3.5 Query root

```ruby
# app/graphql/types/query_type.rb
field :concordance, resolver: Resolvers::ConcordanceResolver
field :concordance_index, resolver: Resolvers::ConcordanceIndexResolver
```

**Definition of done E3:** el schema dump refleja los tipos nuevos, GraphiQL autocompleta `concordance`,
y los ejemplos de E5.3 corren sin error contra la base de desarrollo.

---

### E4 `[MVP]` — Caché

El corpus es inmutable tras el import. Cachear con TTL infinito y invalidar solo al re-indexar.

```ruby
# En ConcordanceLookup
def cache_key(suffix)
  [
    "concordance", "v1",
    @translation.identifier,
    @translation.concordance_indexed_at.to_i,   # invalidación automática al re-importar
    Digest::SHA256.hexdigest(@word.downcase)[0, 16],
    @book, @testament, suffix
  ].compact.join(":")
end
```

Incluir `concordance_indexed_at` en la clave hace que un re-import invalide todo sin borrado explícito.
El `v1` permite invalidar globalmente si cambia el formato de serialización.

Qué cachear:

- **Agregados** (`total_count`, `counts_by_book`, `counts_by_testament`, `surface_forms`) — siempre,
  son los más caros y los más repetidos.
- **Primera página** — sí, es la que pide todo el mundo.
- **Páginas siguientes** — sí, pero con TTL de 1 hora en vez de infinito, para no llenar el cache con
  colas largas que nadie vuelve a pedir.

Usa el `Rails.cache` existente (Solid Cache en producción).

---

### E5 `[MVP]` — Documentación

Esta épica **no es opcional ni se pospone**. Sin ella los queries nuevos son invisibles.

#### E5.1 `README.md`

En la tabla **Available queries**, agregar dos filas manteniendo el formato existente:

```markdown
| `concordance(translation, word, book, testament, first, after)` | Exhaustive, canonically-ordered concordance for a word, with per-book counts and KWIC context |
| `concordanceIndex(translation, prefix, minOccurrences, first)`  | Alphabetical word index with occurrence frequencies |
```

En **Features**, agregar un bullet:

```markdown
- **Bible concordance** — exhaustive word lookup with canonical ordering, per-book distribution,
  and keyword-in-context snippets across all 47 translations
```

Agregar una subsección nueva después de *Reference Formats*:

```markdown
### Concordance

Unlike `search`, which returns the top-N most relevant verses, `concordance` returns **every**
occurrence of a word in canonical order, along with aggregate counts.

Stemming availability varies by language. PostgreSQL ships dictionaries for ~30 languages;
translations in other languages fall back to exact form matching. Check `translation.hasStemming`
to know which behaviour applies.

Run `rake concordance:index` after importing translations, or concordance queries will return
an error prompting you to build the index.
```

En **Setup**, después del import de traducciones:

```bash
# Build the concordance index (required for concordance queries)
bundle exec rake concordance:index
```

#### E5.2 `CLAUDE.md`

Tres bloques a tocar:

1. **Common Commands** — agregar:

```bash
# Concordance index
bundle exec rake concordance:index                  # all translations
bundle exec rake "concordance:index[spa-rv1909]"    # one translation
bundle exec rake concordance:status                 # per-translation index status
bundle exec rake concordance:refresh_index          # rebuild the word index
```

2. **GraphQL Queries** — agregar `concordance`, `concordanceIndex` y, **corrigiendo la omisión actual**,
   `semanticSearch`:

```markdown
- `search(translation, query, limit)` — Full-text search across verses (ranked, top-N)
- `semanticSearch(query, limit)` — Embedding-based similarity search (pgvector + RubyLLM)
- `concordance(translation, word, ...)` — Exhaustive concordance, canonical order, KWIC context
- `concordanceIndex(translation, prefix, ...)` — Alphabetical word index with frequencies
```

3. **Key Services** — agregar:

```markdown
- **ConcordanceLookup** (`app/services/concordance_lookup.rb`) — Builds concordance results:
  exhaustive occurrences in canonical order, per-book/testament counts, KWIC context via `ts_headline`.
  All concordance SQL lives here; resolvers must not contain SQL.
- **ConcordanceIndexer** (`app/services/concordance_indexer.rb`) — Populates `verses.text_search`
  using the per-translation `regconfig`. Called at the end of every import.
- **TextSearchConfigResolver** (`app/services/text_search_config_resolver.rb`) — Maps an ISO 639-3
  language prefix to a PostgreSQL text search configuration; falls back to `simple`.
```

4. **Key Models** — actualizar `Translation` y `Verse`:

```markdown
- **Translation** — ... plus `text_search_config`, `has_stemming`, `concordance_indexed_at`
- **Verse** — ... plus `text_search` (tsvector, GIN-indexed) for search and concordance
```

Agregar una sección corta de invariantes, en el espíritu del resto del archivo:

```markdown
## Concordance Invariants

- Concordance results are **exhaustive and canonically ordered**, never ranked or truncated by
  relevance. This is the distinction from `search`.
- `verses.text_search` must be built with the translation's own `regconfig`. Never assume `english`.
- Concordance cache keys include `translation.concordance_indexed_at` so a re-import invalidates
  automatically. Do not add manual cache-clearing logic.
- `context` contains `<mark>` HTML. Never interpolate user input into it beyond `plainto_tsquery`.
- Always use `plainto_tsquery`, never `to_tsquery`, for user-supplied words.
```

#### E5.3 `docs/example_queries.md`

Agregar una sección **Concordance** siguiendo el formato existente (query + respuesta JSON real, no
inventada — corre cada query y pega el output). Mínimo seis ejemplos:

1. Concordancia básica con agregados
2. Filtrada por libro
3. Filtrada por testamento
4. Paginación (segunda página usando `endCursor`)
5. Índice alfabético por prefijo
6. Query combinada — **este es el ejemplo estrella**:

```graphql
query StudyOnMercy {
  exact: concordance(translation: "spa-rv1909", word: "misericordia", first: 5) {
    totalCount
    entry { surfaceForms occurrencesByTestament { old new } }
    edges { node { verse { bookName chapter verse } context } }
  }
  semantic: semanticSearch(query: "la compasión de Dios hacia el pecador", limit: 5) {
    verse { bookName chapter verse text }
    similarity
  }
}
```

Acompáñalo de una línea explicando por qué importa: en una sola llamada el cliente obtiene el listado
exhaustivo verificable y los pasajes temáticamente cercanos que no usan la palabra.

#### E5.4 Playground

Ubicar cómo están definidos los ejemplos actuales del playground (probablemente en la vista o en un JS
embebido; buscar `playground` en `app/views/`). Agregar tres entradas nuevas al selector:

| Nombre | Contenido |
|---|---|
| `Concordance — basic` | Ejemplo 1, con variables `$word` y `$translation` |
| `Concordance — by book` | Ejemplo 2 |
| `Concordance + semantic` | Ejemplo 6, el combinado |

Usar variables en vez de literales, para que el usuario pueda editar sin tocar el query:

```graphql
query Concordance($translation: String! = "spa-rv1909", $word: String! = "misericordia") {
  concordance(translation: $translation, word: $word, first: 10) { ... }
}
```

```json
{ "translation": "spa-rv1909", "word": "misericordia" }
```

Verifica que los ejemplos del playground **corren sin error contra producción** con una API key válida.
Un ejemplo roto en el playground es peor que no tenerlo.

#### E5.5 Descripciones GraphQL

Cada campo y argumento nuevo lleva `description:`. El playground y GraphiQL las muestran, y son la
documentación que más gente va a leer. Prioriza explicar:

- por qué `lemma` puede verse raro (es un stem)
- que `context` contiene HTML
- que `strongs` y `hasStrongsTagging` son placeholders hasta Phase 2
- qué significa `hasStemming: false`

---

### E6 `[MVP]` — Tests

RSpec, siguiendo la estructura existente en `spec/`.

**`spec/services/concordance_lookup_spec.rb`**
- palabra frecuente: conteo correcto, orden canónico verificado (Génesis antes que Salmos)
- palabra inexistente: `totalCount: 0`, sin excepción
- acentos y mayúsculas: `Misericordia`, `misericordia`, `MISERICORDIA` dan el mismo resultado
- stemming activo: `amó` encuentra versículos con `amaba` en `spa-*`
- stemming inactivo: en una traducción con config `simple`, solo coincidencia exacta
- filtro por libro y por testamento
- paginación: página 1 + página 2 no se solapan y cubren todo
- cursor inválido → `GraphQL::ExecutionError`
- input malicioso: `"'; DROP TABLE verses; --"` no rompe ni ejecuta nada

**`spec/graphql/queries/concordance_spec.rb`**
- shape de la respuesta
- traducción inexistente → error con mensaje útil
- traducción sin indexar → error que menciona el rake task
- `first` mayor a `MAX_PAGE_SIZE` se recorta silenciosamente
- `strongs` es `null` y `hasStrongsTagging` es `false`
- complejidad: el query combinado de E5.3 no excede `max_complexity`

**`spec/services/concordance_indexer_spec.rb`**
- asigna `spanish` a `spa-*`, `english` a `eng-*`, `simple` a un idioma sin diccionario
- es idempotente
- setea `concordance_indexed_at`

**`spec/services/text_search_config_resolver_spec.rb`**
- mapeo correcto, fallback a `simple`, identificadores malformados

Fixtures: usa una traducción pequeña o un subconjunto de verses; no dependas de las 47 importadas.

Cobertura: el repo tiene Codecov. No dejes caer el porcentaje.

---

### E7 `[Phase 2]` — Concordancia analítica (Strong)

**No empezar hasta que el MVP esté mergeado y desplegado.** Se documenta aquí para que el diseño del
MVP no cierre puertas.

#### E7.1 Datos y licencias — hacer primero

La **RV1909** es la traducción estratégica: su texto es dominio público **y** es la única Reina Valera
con etiquetado Strong disponible públicamente (el módulo lo editó Rubén Gómez; circula en STEP Bible y
en el ecosistema theWord). La RVR1960 sigue bajo copyright y no tiene etiquetado abierto.

**El texto es dominio público; el etiquetado es trabajo derivado con autor identificable.** Antes de
importar, obtén permiso explícito por escrito para uso en una API abierta. Registra la respuesta en
`docs/licenses/`.

Fuentes candidatas:

| Recurso | Contenido | Licencia |
|---|---|---|
| `scrollmapper/bible_databases` | Léxico Strong hebreo/griego | Dominio público |
| `openscriptures/HebrewLexicon` | Léxico hebreo | Verificar |
| `openscriptures/morphhb` | Morfología hebrea (OSHB) | CC BY 4.0 — requiere atribución |
| STEP Bible (Tyndale House) | Tablas TSV de lemas y morfología | Verificar términos |
| BSB (`BSB-publishing/bsb2usfm`) | Texto inglés con Strong | CC0 |

BSB es la ruta de menor fricción legal para validar el pipeline en inglés antes de tocar el español.

#### E7.2 Modelos

```ruby
# strongs_entries — el léxico, independiente de traducción (~14K filas)
#   number:string (H2617, G26), lemma, transliteration, pronunciation,
#   definition:text, part_of_speech, language:string (hebrew|greek)

# word_occurrences — la alineación, por traducción etiquetada
#   verse_id, translation_id, position:integer,
#   surface_form:string, strongs_number:string, morphology:string
```

Índices: `(strongs_number, translation_id)` y `(verse_id, position)`.
Volumen: ~800K filas por traducción etiquetada. Considera particionar por `translation_id` solo si
llegas a varias traducciones etiquetadas.

#### E7.3 Queries

- `strongsEntry(number)` con `occurrences(translation:, first:)` y `occurrenceCount(translation:)`
- `Verse.words` → `[Word!]` para el interlineal
- `ConcordanceOccurrence.strongs` deja de ser `null` en traducciones etiquetadas
- `Translation.hasStrongsTagging` empieza a devolver `true`

#### E7.4 Atribución

Si usas OSHB (CC BY 4.0), la atribución debe aparecer en el README **y** en la respuesta de la API
(campo `translation.attribution` o similar). No es opcional bajo esa licencia.

---

## 4. Orden de ejecución sugerido

Un PR por épica, mergeable de forma independiente:

1. **PR 0** — Documentar `semanticSearch` en `README.md` y `CLAUDE.md`. Pequeño, desbloquea todo lo demás.
2. **PR 1** — E1 (migraciones, indexer, rake tasks) + specs de E6 correspondientes.
3. **PR 2** — E2 (`ConcordanceLookup`) + specs.
4. **PR 3** — E3 (GraphQL) + E4 (caché) + specs.
5. **PR 4** — E5 (README, CLAUDE.md, example_queries, playground).
6. **Phase 2** — E7, en su propia rama larga.

Cada PR debe pasar el CI completo: Brakeman, Bundler Audit, Importmap Audit, RuboCop, RSpec.

---

## 5. Convenciones del repo (recordatorio)

- **Identificadores en inglés.** Nombres de clases, métodos, columnas, campos GraphQL. Los ejemplos en
  español van solo en datos y documentación de usuario.
- **RSpec**, no Minitest.
- **rubocop-rails-omakase**. Corre `bin/rubocop` antes de commitear.
- **Skill `rails-expert`**: cargar y seguir `.agents/skills/rails-expert/SKILL.md` al trabajar en
  features de Rails, según indica `CLAUDE.md`.
- Servicios en `app/services/`, una clase por archivo, `call` como punto de entrada.
- No SQL en resolvers de GraphQL.

---

## 6. Riesgos conocidos

| Riesgo | Mitigación |
|---|---|
| `ts_stat` no compone con `CROSS JOIN LATERAL` como está escrito en E2.5 | Evaluar tabla real poblada por PL/pgSQL; el contrato de columnas es lo que importa |
| `max_complexity: 300` bloquea queries legítimos | Complejidad calculada sobre `first` (E3.4); ajustar el divisor antes de subir el límite global |
| Idiomas sin diccionario en Postgres dan resultados pobres | `hasStemming` expuesto en el schema; documentado en README |
| El backfill de 47 traducciones es pesado en producción | `in_batches`, y correrlo como job de Solid Queue o en una release task, no en el request cycle |
| Licencia del etiquetado Strong en español | Bloqueante de E7.1; no importar sin permiso escrito |
| `<mark>` en `context` mal renderizado por clientes | Descripción explícita en el campo GraphQL |

---

## 7. Definition of done — MVP completo

- [ ] `rake concordance:status` muestra las 47 traducciones indexadas
- [ ] `concordance` y `concordanceIndex` responden en `/graphql` con API key
- [ ] Orden canónico verificado manualmente en al menos una palabra frecuente
- [ ] Los seis ejemplos de `docs/example_queries.md` corren y su output pegado es real
- [ ] Los tres ejemplos del playground corren contra producción
- [ ] `README.md` y `CLAUDE.md` actualizados, incluyendo `semanticSearch`
- [ ] CI en verde, cobertura no bajó
- [ ] `hasStrongsTagging` y `strongs` presentes en el schema devolviendo `false`/`null`
