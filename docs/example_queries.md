# BibleQL — Example GraphQL Queries

All queries require an API key via the Authorization header:

```
Authorization: Bearer bql_live_xxxxxxxxxxxxxxxx
```

---

## Get a single translation

Get a single translation by identifier, including nested books and chapters.

```graphql
{
  translation(identifier: "eng-web") {
    identifier
    name
    language
    books {
      bookId
      name
      testament
      chapterCount
      chapters {
        number
        verseCount
      }
    }
  }
}
```

Response:

```json
{
  "data": {
    "translation": {
      "identifier": "eng-web",
      "name": "World English Bible",
      "language": "eng",
      "books": [
        {
          "bookId": "GEN",
          "name": "Genesis",
          "testament": "OT",
          "chapterCount": 50,
          "chapters": [
            { "number": 1, "verseCount": 31 },
            { "number": 2, "verseCount": 25 }
          ]
        }
      ]
    }
  }
}
```

---

## List translations

List all available Bible translations.

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
      { "identifier": "eng-web", "name": "World English Bible", "language": "eng" },
      { "identifier": "spa-bes", "name": "Biblia en Espanol", "language": "spa" }
    ]
  }
}
```

---

## List books

List all 66 canonical books in order.

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
      { "bookId": "GEN", "name": "Genesis", "testament": "OT", "position": 1 },
      { "bookId": "EXO", "name": "Exodus", "testament": "OT", "position": 2 }
    ]
  }
}
```

---

## Look up a passage

Look up a Bible passage by reference (e.g., "John 3:16").

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

---

## Look up a passage in Spanish

Use localized book names with a non-English translation.

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

---

## Get a full chapter

Get all verses in a chapter.

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
      { "bookName": "Genesis", "chapter": 1, "verse": 1, "text": "In the beginning, God created the heavens and the earth." },
      { "bookName": "Genesis", "chapter": 1, "verse": 2, "text": "The earth was formless and empty. Darkness was on the surface of the deep and God's Spirit was hovering over the surface of the waters." }
    ]
  }
}
```

---

## Get a single verse

Get a single verse by book, chapter, and verse number.

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

---

## Search verses

Full-text search across verses.

```graphql
{
  search(translation: "eng-web", query: "love", limit: 5) {
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
      }
    ]
  }
}
```

---

## Semantic search

Search verses by meaning using AI embeddings. Currently available for `spa-rv1909` (Reina Valera 1909).

```graphql
{
  semanticSearch(query: "fe y esperanza", translation: "spa-rv1909", limit: 5) {
    verse {
      bookName
      chapter
      verse
      text
    }
    similarity
  }
}
```

Response:

```json
{
  "data": {
    "semanticSearch": [
      {
        "verse": {
          "bookName": "1 Corintios",
          "chapter": 13,
          "verse": 13,
          "text": "Y ahora permanecen la fe, la esperanza y el amor, estos tres; pero el mayor de ellos es el amor."
        },
        "similarity": 0.8742
      },
      {
        "verse": {
          "bookName": "Hebreos",
          "chapter": 11,
          "verse": 1,
          "text": "Es, pues, la fe la certeza de lo que se espera, la convicción de lo que no se ve."
        },
        "similarity": 0.8315
      }
    ]
  }
}
```

---

## Concordance

Exhaustive, canonically-ordered occurrences of a word across an entire translation, with per-book
and per-testament aggregates and keyword-in-context (KWIC) snippets. Unlike `search`, which returns
only the top-N most relevant matches, `concordance` returns **every** occurrence.

```graphql
{
  concordance(translation: "spa-rv1909", word: "misericordia", first: 3) {
    totalCount
    entry {
      lemma
      surfaceForms
      totalOccurrences
      verseCount
      occurrencesByBook { bookId bookName count }
      occurrencesByTestament { old new }
    }
    edges {
      cursor
      node {
        verse { bookName chapter verse text }
        context
      }
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

Response:

```json
{
  "data": {
    "concordance": {
      "totalCount": 398,
      "entry": {
        "lemma": "misericordi",
        "surfaceForms": ["misericordia", "misericordias", "misericordioso", "misericordiosos"],
        "totalOccurrences": 424,
        "verseCount": 398,
        "occurrencesByBook": [
          { "bookId": "GEN", "bookName": "Génesis", "count": 12 },
          { "bookId": "EXO", "bookName": "Éxodo", "count": 6 },
          { "bookId": "NUM", "bookName": "Números", "count": 3 },
          { "bookId": "DEU", "bookName": "Deuteronomio", "count": 6 },
          { "bookId": "JOS", "bookName": "Josué", "count": 3 },
          { "bookId": "JDG", "bookName": "Jueces", "count": 2 },
          { "bookId": "RUT", "bookName": "Rut", "count": 1 },
          { "bookId": "1SA", "bookName": "1 Samuel", "count": 4 },
          { "bookId": "2SA", "bookName": "2 Samuel", "count": 11 },
          { "bookId": "1KI", "bookName": "1 Reyes", "count": 4 },
          { "bookId": "2KI", "bookName": "2 Reyes", "count": 1 },
          { "bookId": "1CH", "bookName": "1 Crónicas", "count": 5 },
          { "bookId": "2CH", "bookName": "2 Crónicas", "count": 11 },
          { "bookId": "EZR", "bookName": "Esdras", "count": 4 },
          { "bookId": "NEH", "bookName": "Nehemías", "count": 7 },
          { "bookId": "JOB", "bookName": "Job", "count": 3 },
          { "bookId": "PSA", "bookName": "Salmos", "count": 164 },
          { "bookId": "PRO", "bookName": "Proverbios", "count": 11 },
          { "bookId": "ISA", "bookName": "Isaías", "count": 18 },
          { "bookId": "JER", "bookName": "Jeremías", "count": 16 },
          { "bookId": "LAM", "bookName": "Lamentaciones", "count": 2 },
          { "bookId": "EZK", "bookName": "Ezequiel", "count": 9 },
          { "bookId": "DAN", "bookName": "Daniel", "count": 4 },
          { "bookId": "HOS", "bookName": "Oseas", "count": 10 },
          { "bookId": "JOL", "bookName": "Joel", "count": 1 },
          { "bookId": "JON", "bookName": "Jonás", "count": 2 },
          { "bookId": "MIC", "bookName": "Miqueas", "count": 5 },
          { "bookId": "HAB", "bookName": "Habacuc", "count": 1 },
          { "bookId": "ZEC", "bookName": "Zacarías", "count": 1 },
          { "bookId": "MAT", "bookName": "San Mateo", "count": 12 },
          { "bookId": "MRK", "bookName": "Marcos", "count": 5 },
          { "bookId": "LUK", "bookName": "San Lucas", "count": 13 },
          { "bookId": "ACT", "bookName": "Hechos", "count": 1 },
          { "bookId": "ROM", "bookName": "Romanos", "count": 11 },
          { "bookId": "1CO", "bookName": "1 Corintios", "count": 1 },
          { "bookId": "2CO", "bookName": "2 Corintios", "count": 2 },
          { "bookId": "GAL", "bookName": "Gálatas", "count": 1 },
          { "bookId": "EPH", "bookName": "Efesios", "count": 2 },
          { "bookId": "PHP", "bookName": "Filipenses", "count": 2 },
          { "bookId": "COL", "bookName": "Colosenses", "count": 1 },
          { "bookId": "1TI", "bookName": "1 Timoteo", "count": 3 },
          { "bookId": "2TI", "bookName": "2 Timoteo", "count": 3 },
          { "bookId": "TIT", "bookName": "Tito", "count": 2 },
          { "bookId": "HEB", "bookName": "Hebreos", "count": 3 },
          { "bookId": "JAS", "bookName": "Santiago", "count": 3 },
          { "bookId": "1PE", "bookName": "1 Pedro", "count": 3 },
          { "bookId": "2JN", "bookName": "2 Juan", "count": 1 },
          { "bookId": "JUD", "bookName": "Judas", "count": 2 }
        ],
        "occurrencesByTestament": { "old": 327, "new": 71 }
      },
      "edges": [
        {
          "cursor": "MToxOToxNg==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 19,
              "verse": 16,
              "text": "Y deteniéndose él, los varones asieron de su mano, y de la mano de su mujer, y de las manos de sus dos hijas, según la misericordia de Jehová para con él; y le sacaron, y le pusieron fuera de la ciudad."
            },
            "context": "mujer, y de las manos de sus dos hijas, según la <mark>misericordia</mark> de Jehová para con él; y le sacaron, y le pusieron fuera"
          }
        },
        {
          "cursor": "MToxOToxOQ==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 19,
              "verse": 19,
              "text": "He aquí ahora ha hallado tu siervo gracia en tus ojos, y has engrandecido tu misericordia que has hecho conmigo dándome la vida; mas yo no podré escapar al monte, no sea caso que me alcance el mal, y muera."
            },
            "context": "hallado tu siervo gracia en tus ojos, y has engrandecido tu <mark>misericordia</mark> que has hecho conmigo dándome la vida; mas yo no podré escapar"
          }
        },
        {
          "cursor": "MToyNDoxMg==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 24,
              "verse": 12,
              "text": "Y dijo: Jehová, Dios de mi señor Abraham, dame, te ruego, el tener hoy buen encuentro, y haz misericordia con mi señor Abraham."
            },
            "context": "señor Abraham, dame, te ruego, el tener hoy buen encuentro, y haz <mark>misericordia</mark> con mi señor Abraham"
          }
        }
      ],
      "pageInfo": { "hasNextPage": true, "endCursor": "MToyNDoxMg==" }
    }
  }
}
```

`context` contains `<mark>` HTML around the matched term — sanitize it before rendering.

---

## Concordance filtered by book

```graphql
{
  concordance(translation: "spa-rv1909", word: "misericordia", book: "Salmos", first: 3) {
    totalCount
    edges { node { verse { bookName chapter verse text } } }
  }
}
```

Response:

```json
{
  "data": {
    "concordance": {
      "totalCount": 164,
      "edges": [
        {
          "node": {
            "verse": {
              "bookName": "Salmos",
              "chapter": 4,
              "verse": 1,
              "text": "Al Músico principal: sobre Neginoth: Salmo de David. RESPÓNDEME cuando clamo, oh Dios de mi justicia: estando en angustia, tú me hiciste ensanchar: ten misericordia de mí, y oye mi oración."
            }
          }
        },
        {
          "node": {
            "verse": {
              "bookName": "Salmos",
              "chapter": 5,
              "verse": 7,
              "text": "Y yo en la multitud de tu misericordia entraré en tu casa: adoraré hacia el templo de tu santidad en tu temor."
            }
          }
        },
        {
          "node": {
            "verse": {
              "bookName": "Salmos",
              "chapter": 6,
              "verse": 2,
              "text": "Ten misericordia de mí, oh Jehová, porque yo estoy debilitado: sáname, oh Jehová, porque mis huesos están conmovidos."
            }
          }
        }
      ]
    }
  }
}
```

---

## Concordance filtered by testament

```graphql
{
  concordance(translation: "spa-rv1909", word: "misericordia", testament: NEW, first: 3) {
    totalCount
    edges { node { verse { bookName chapter verse text } } }
  }
}
```

Response:

```json
{
  "data": {
    "concordance": {
      "totalCount": 71,
      "edges": [
        {
          "node": {
            "verse": {
              "bookName": "San Mateo",
              "chapter": 5,
              "verse": 7,
              "text": "Bienaventurados los misericordiosos: porque ellos alcanzarán misericordia."
            }
          }
        },
        {
          "node": {
            "verse": {
              "bookName": "San Mateo",
              "chapter": 9,
              "verse": 13,
              "text": "Andad pues, y aprended qué cosa es: Misericordia quiero, y no sacrificio: porque no he venido á llamar justos, sino pecadores á arrepentimiento."
            }
          }
        },
        {
          "node": {
            "verse": {
              "bookName": "San Mateo",
              "chapter": 9,
              "verse": 27,
              "text": "Y pasando Jesús de allí, le siguieron dos ciegos, dando voces y diciendo: Ten misericordia de nosotros, Hijo de David."
            }
          }
        }
      ]
    }
  }
}
```

---

## Concordance pagination

Pass the previous page's `pageInfo.endCursor` as `after` to fetch the next page.

```graphql
{
  concordance(translation: "spa-rv1909", word: "misericordia", first: 3, after: "MToyNDoxMg==") {
    totalCount
    edges {
      cursor
      node { verse { bookName chapter verse text } }
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

Response:

```json
{
  "data": {
    "concordance": {
      "totalCount": 398,
      "edges": [
        {
          "cursor": "MToyNDoxNA==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 24,
              "verse": 14,
              "text": "Sea, pues, que la moza á quien yo dijere: Baja tu cántaro, te ruego, para que yo beba; y ella respondiere: Bebe, y también daré de beber á tus camellos: que sea ésta la que tú has destinado para tu siervo Isaac; y en esto conoceré que habrás hecho misericordia con mi señor."
            }
          }
        },
        {
          "cursor": "MToyNDoyNw==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 24,
              "verse": 27,
              "text": "Y dijo: Bendito sea Jehová, Dios de mi amo Abraham, que no apartó su misericordia y su verdad de mi amo, guiándome Jehová en el camino á casa de los hermanos de mi amo."
            }
          }
        },
        {
          "cursor": "MToyNDo0OQ==",
          "node": {
            "verse": {
              "bookName": "Génesis",
              "chapter": 24,
              "verse": 49,
              "text": "Ahora pues, si vosotros hacéis misericordia y verdad con mi señor, declarádmelo; y si no, declarádmelo; y echaré á la diestra ó á la siniestra."
            }
          }
        }
      ],
      "pageInfo": { "hasNextPage": true, "endCursor": "MToyNDo0OQ==" }
    }
  }
}
```

---

## Concordance word index

Alphabetical word frequency index for a translation, filterable by prefix.

```graphql
{
  concordanceIndex(translation: "spa-rv1909", prefix: "mis", first: 5) {
    lemma
    verseCount
    totalOccurrences
  }
}
```

Response:

```json
{
  "data": {
    "concordanceIndex": [
      { "lemma": "misael", "verseCount": 8, "totalOccurrences": 8 },
      { "lemma": "misam", "verseCount": 2, "totalOccurrences": 2 },
      { "lemma": "miseal", "verseCount": 2, "totalOccurrences": 2 },
      { "lemma": "miser", "verseCount": 15, "totalOccurrences": 15 },
      { "lemma": "miseri", "verseCount": 6, "totalOccurrences": 6 }
    ]
  }
}
```

`lemma` values are dictionary stems, not readable words — this index is for building autocomplete
or word clouds, not for display as-is.

---

## Concordance combined with semantic search

In a single request, get the exhaustive, verifiable list of exact matches for a word alongside
thematically related passages that don't use that word at all.

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

Response:

```json
{
  "data": {
    "exact": {
      "totalCount": 398,
      "entry": {
        "surfaceForms": ["misericordia", "misericordias", "misericordioso", "misericordiosos"],
        "occurrencesByTestament": { "old": 327, "new": 71 }
      },
      "edges": [
        {
          "node": {
            "verse": { "bookName": "Génesis", "chapter": 19, "verse": 16 },
            "context": "mujer, y de las manos de sus dos hijas, según la <mark>misericordia</mark> de Jehová para con él; y le sacaron, y le pusieron fuera"
          }
        },
        {
          "node": {
            "verse": { "bookName": "Génesis", "chapter": 19, "verse": 19 },
            "context": "hallado tu siervo gracia en tus ojos, y has engrandecido tu <mark>misericordia</mark> que has hecho conmigo dándome la vida; mas yo no podré escapar"
          }
        },
        {
          "node": {
            "verse": { "bookName": "Génesis", "chapter": 24, "verse": 12 },
            "context": "señor Abraham, dame, te ruego, el tener hoy buen encuentro, y haz <mark>misericordia</mark> con mi señor Abraham"
          }
        },
        {
          "node": {
            "verse": { "bookName": "Génesis", "chapter": 24, "verse": 14 },
            "context": "destinado para tu siervo Isaac; y en esto conoceré que habrás hecho <mark>misericordia</mark> con mi señor"
          }
        },
        {
          "node": {
            "verse": { "bookName": "Génesis", "chapter": 24, "verse": 27 },
            "context": "Bendito sea Jehová, Dios de mi amo Abraham, que no apartó su <mark>misericordia</mark> y su verdad de mi amo, guiándome Jehová en el camino"
          }
        }
      ]
    },
    "semantic": [
      {
        "verse": {
          "bookName": "Levítico",
          "chapter": 4,
          "verse": 3,
          "text": "Si sacerdote ungido pecare según el pecado del pueblo, ofrecerá á Jehová, por su pecado que habrá cometido, un becerro sin tacha para expiación."
        },
        "similarity": 0.6126
      },
      {
        "verse": {
          "bookName": "Números",
          "chapter": 14,
          "verse": 18,
          "text": "Jehová, tardo de ira y grande en misericordia, que perdona la iniquidad y la rebelión, y absolviendo no absolverá al culpado; que visita la maldad de los padres sobre los hijos hasta los terceros y hasta los cuartos."
        },
        "similarity": 0.612
      },
      {
        "verse": {
          "bookName": "Levítico",
          "chapter": 5,
          "verse": 15,
          "text": "Cuando alguna persona cometiere falta, y pecare por yerro en las cosas santificadas á Jehová, traerá su expiación á Jehová, un carnero sin tacha de los rebaños, conforme á tu estimación, en siclos de plata del siclo del santuario, en ofrenda por el pecado:"
        },
        "similarity": 0.6011
      },
      {
        "verse": {
          "bookName": "Números",
          "chapter": 15,
          "verse": 28,
          "text": "Y el sacerdote hará expiación por la persona que habrá pecado por yerro, cuando pecare por yerro delante de Jehová, la reconciliará, y le será perdonado."
        },
        "similarity": 0.6006
      },
      {
        "verse": {
          "bookName": "Levítico",
          "chapter": 7,
          "verse": 1,
          "text": "ASIMISMO esta es la ley de la expiación de la culpa: es cosa muy santa."
        },
        "similarity": 0.5942
      }
    ]
  }
}
```

Note how `semantic` surfaces thematically related atonement/mercy passages that never use the word
"misericordia" at all — a gap `exact` alone can't fill.

---

## Random verse

Get a random verse from any book.

```graphql
{
  randomVerse(translation: "spa-bes") {
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
    "randomVerse": {
      "bookName": "Salmos",
      "chapter": 23,
      "verse": 1,
      "text": "Jehova es mi pastor; nada me faltara."
    }
  }
}
```

---

## Random verse from the New Testament

Filter random verse by testament (`OT` or `NT`).

```graphql
{
  randomVerse(translation: "eng-web", testament: "NT") {
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
    "randomVerse": {
      "bookName": "Romans",
      "chapter": 8,
      "verse": 28,
      "text": "We know that all things work together for good for those who love God, for those who are called according to his purpose."
    }
  }
}
```

---

## Random verse from specific books

Filter random verse by comma-separated book IDs or localized names.

```graphql
{
  randomVerse(translation: "eng-web", books: "PSA,PRO") {
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
    "randomVerse": {
      "bookName": "Proverbs",
      "chapter": 3,
      "verse": 5,
      "text": "Trust in Yahweh with all your heart, and don't lean on your own understanding."
    }
  }
}
```

---

## Verse of the Day

Get the curated verse of the day. Defaults to today's date and the `eng-web` translation.

```graphql
{
  verseOfTheDay {
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
    "verseOfTheDay": {
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

---

## Verse of the Day for a specific date and translation

Pass a date (ISO 8601) and translation to get the verse of the day in any language.

```graphql
{
  verseOfTheDay(translation: "spa-bes", date: "2026-12-25") {
    reference
    text
    translationName
  }
}
```

Response:

```json
{
  "data": {
    "verseOfTheDay": {
      "reference": "Juan 3:16",
      "text": "Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito...",
      "translationName": "Biblia en Espanol"
    }
  }
}
```

---

## List languages

List all languages that have at least one translation, with translation counts.

```graphql
{
  languages {
    code
    translationCount
    translations {
      identifier
      name
    }
  }
}
```

Response:

```json
{
  "data": {
    "languages": [
      {
        "code": "eng",
        "translationCount": 5,
        "translations": [
          { "identifier": "eng-kjv", "name": "King James Version" },
          { "identifier": "eng-web", "name": "World English Bible" }
        ]
      },
      {
        "code": "spa",
        "translationCount": 2,
        "translations": [
          { "identifier": "spa-bes", "name": "Biblia en Espanol" }
        ]
      }
    ]
  }
}
```

---

## Bible index

Get the full structural hierarchy (books, chapters, verse counts) for a translation. Useful for building navigation UIs.

```graphql
{
  bibleIndex(translation: "eng-web") {
    bookId
    name
    testament
    position
    chapterCount
    chapters {
      number
      verseCount
    }
  }
}
```

Response:

```json
{
  "data": {
    "bibleIndex": [
      {
        "bookId": "GEN",
        "name": "Genesis",
        "testament": "OT",
        "position": 1,
        "chapterCount": 50,
        "chapters": [
          { "number": 1, "verseCount": 31 },
          { "number": 2, "verseCount": 25 },
          { "number": 3, "verseCount": 24 }
        ]
      },
      {
        "bookId": "EXO",
        "name": "Exodus",
        "testament": "OT",
        "position": 2,
        "chapterCount": 40,
        "chapters": [
          { "number": 1, "verseCount": 22 }
        ]
      }
    ]
  }
}
```
