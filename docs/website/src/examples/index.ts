/**
 * One definition per operation, rendered into GraphQL / cURL / Ruby / Node tabs by
 * <ApiExample>. The cURL command is *derived* from `graphql` at render time, so the
 * four tabs cannot drift apart and the JSON escaping is never written by hand.
 *
 * `{{translation}}` and `{{reference}}` are substituted with locale-appropriate values
 * from EXAMPLES in ../constants.ts.
 *
 * Where an SDK has no method for an operation, set `ruby` or `node` to `null` and
 * <ApiExample> renders an honest "not available" notice instead of inventing an API.
 * Method names below are transcribed from the published SDK READMEs.
 */

import type { DocsLocale } from "../constants";

export interface Example {
  /** The GraphQL document. Source of truth for the cURL tab too. */
  graphql: string;
  /** Ruby snippet using bibleql-ruby, or null when the gem has no such method. */
  ruby: string | null;
  /** Node snippet using bibleql-js, or null when the package has no such method. */
  node: string | null;
  /**
   * Real response per documentation locale, because the verse text differs by
   * translation — an English example cannot show Spanish output.
   *
   * These were produced by executing the query above against the API, not written
   * by hand. Long arrays are truncated with a `// ...` marker. A locale is omitted
   * where the response has not been captured, and the Response tab is then hidden
   * rather than showing invented text.
   */
  response?: Partial<Record<DocsLocale, string>>;
}

const examples: Record<string, Example> = {
  passage: {
    graphql: `query {
  passage(translation: "{{translation}}", reference: "{{reference}}") {
    reference
    text
    translationName
  }
}`,
    ruby: `passage = client.passage("{{reference}}", translation: "{{translation}}")

puts passage.reference
puts passage.text`,
    node: `const passage = await client.passage("{{reference}}", {
  translation: "{{translation}}",
});

console.log(passage.reference, passage.text);`,
    response: {
      en: `{
  "data": {
    "passage": {
      "reference": "John 3:16",
      "text": "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.",
      "translationName": "World English Bible"
    }
  }
}`,
      es: `{
  "data": {
    "passage": {
      "reference": "Juan 3:16",
      "text": "Porque de tal manera amó Dios al mundo, que ha dado á su Hijo unigénito, para que todo aquel que en él cree, no se pierda, mas tenga vida eterna.",
      "translationName": "Reina Valera 1909"
    }
  }
}`,
    },
  },

  verse: {
    graphql: `query {
  verse(translation: "{{translation}}", book: "JHN", chapter: 3, verse: 16) {
    bookName
    chapter
    verse
    text
  }
}`,
    ruby: `verse = client.verse("JHN", 3, 16, translation: "{{translation}}")

puts "#{verse.book_name} #{verse.chapter}:#{verse.verse}"
puts verse.text`,
    node: `const verse = await client.verse("JHN", 3, 16, {
  translation: "{{translation}}",
});

console.log(\`\${verse.bookName} \${verse.chapter}:\${verse.verse}\`, verse.text);`,
    response: {
      en: `{
  "data": {
    "verse": {
      "bookName": "John",
      "chapter": 3,
      "verse": 16,
      "text": "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life."
    }
  }
}`,
      es: `{
  "data": {
    "verse": {
      "bookName": "Juan",
      "chapter": 3,
      "verse": 16,
      "text": "Porque de tal manera amó Dios al mundo, que ha dado á su Hijo unigénito, para que todo aquel que en él cree, no se pierda, mas tenga vida eterna."
    }
  }
}`,
    },
  },

  chapter: {
    graphql: `query {
  chapter(translation: "{{translation}}", book: "JHN", chapter: 3) {
    verse
    text
  }
}`,
    ruby: `verses = client.chapter("JHN", 3, translation: "{{translation}}")

verses.each { |v| puts "#{v.verse}. #{v.text}" }`,
    node: `const verses = await client.chapter("JHN", 3, {
  translation: "{{translation}}",
});

verses.forEach((v) => console.log(\`\${v.verse}. \${v.text}\`));`,
    response: {
      en: `{
  "data": {
    "chapter": [
      {
        "verse": 1,
        "text": "Now there was a man of the Pharisees named Nicodemus, a ruler of the Jews."
      },
      {
        "verse": 2,
        "text": "The same came to him by night, and said to him, “Rabbi, we know that you are a teacher come from God, for no one can do these signs that you do, unless God is with him.”"
      },
      {
        "verse": 3,
        "text": "Jesus answered him,\n“Most certainly, I tell you, unless one is born anew,\n\nhe can’t see God’s Kingdom.”"
      },
      // ... 33 more
    ]
  }
}`,
      es: `{
  "data": {
    "chapter": [
      {
        "verse": 1,
        "text": "Y HABÍA un hombre de los Fariseos que se llamaba Nicodemo, príncipe de los Judíos."
      },
      {
        "verse": 2,
        "text": "Este vino á Jesús de noche, y díjole: Rabbí, sabemos que has venido de Dios por maestro; porque nadie puede hacer estas señales que tú haces, si no fuere Dios con él."
      },
      {
        "verse": 3,
        "text": "Respondió Jesús, y díjole: De cierto, de cierto te digo, que el que no naciere otra vez, no puede ver el reino de Dios."
      },
      // ... 33 more
    ]
  }
}`,
    },
  },

  translations: {
    graphql: `query {
  translations {
    identifier
    name
    language
    note
  }
}`,
    ruby: `client.translations.each do |t|
  puts "#{t.identifier} — #{t.name} (#{t.note})"
end`,
    node: `const translations = await client.translations();

translations.forEach((t) => console.log(t.identifier, t.name, t.note));`,
    response: {
      en: `{
  "data": {
    "translations": [
      {
        "identifier": "bul-bulgarian",
        "name": "Bulgarian Bible",
        "language": "bul",
        "note": "Public Domain"
      },
      {
        "identifier": "chi-cuv",
        "name": "Chinese Union Version",
        "language": "chi",
        "note": "Public Domain"
      },
      {
        "identifier": "chi-cuv-simp",
        "name": "Chinese Union Version",
        "language": "chi",
        "note": "Public Domain"
      },
      // ... 44 more
    ]
  }
}`,
      es: `{
  "data": {
    "translations": [
      {
        "identifier": "bul-bulgarian",
        "name": "Bulgarian Bible",
        "language": "bul",
        "note": "Public Domain"
      },
      {
        "identifier": "chi-cuv",
        "name": "Chinese Union Version",
        "language": "chi",
        "note": "Public Domain"
      },
      {
        "identifier": "chi-cuv-simp",
        "name": "Chinese Union Version",
        "language": "chi",
        "note": "Public Domain"
      },
      // ... 44 more
    ]
  }
}`,
    },
  },

  translation: {
    graphql: `query {
  translation(identifier: "{{translation}}") {
    identifier
    name
    language
    languageName
    abbrev
    note
  }
}`,
    ruby: `translation = client.translation("{{translation}}")

puts translation.name`,
    node: `const translation = await client.translation("{{translation}}");

console.log(translation.name);`,
    response: {
      en: `{
  "data": {
    "translation": {
      "identifier": "eng-web",
      "name": "World English Bible",
      "language": "eng",
      "languageName": "English",
      "abbrev": "WEB",
      "note": "Public Domain"
    }
  }
}`,
      es: `{
  "data": {
    "translation": {
      "identifier": "spa-rv1909",
      "name": "Reina Valera 1909",
      "language": "spa",
      "languageName": "Spanish",
      "abbrev": "RV1909",
      "note": "Public Domain"
    }
  }
}`,
    },
  },

  languages: {
    graphql: `query {
  languages {
    code
    translationCount
  }
}`,
    ruby: `client.languages.each do |language|
  puts "#{language.code}: #{language.translation_count} translations"
end`,
    node: `const languages = await client.languages();

languages.forEach((l) => console.log(l.code, l.translationCount));`,
    response: {
      en: `{
  "data": {
    "languages": [
      {
        "code": "swe",
        "translationCount": 1
      },
      {
        "code": "heb",
        "translationCount": 1
      },
      {
        "code": "spa",
        "translationCount": 7
      },
      // ... 28 more
    ]
  }
}`,
      es: `{
  "data": {
    "languages": [
      {
        "code": "swe",
        "translationCount": 1
      },
      {
        "code": "heb",
        "translationCount": 1
      },
      {
        "code": "spa",
        "translationCount": 7
      },
      // ... 28 more
    ]
  }
}`,
    },
  },

  books: {
    graphql: `query {
  books {
    bookId
    name
    testament
    position
  }
}`,
    ruby: `client.books.each { |b| puts "#{b.book_id} — #{b.name}" }`,
    node: `const books = await client.books();

books.forEach((b) => console.log(b.bookId, b.name));`,
    response: {
      en: `{
  "data": {
    "books": [
      {
        "bookId": "GEN",
        "name": "Gen",
        "testament": "OT",
        "position": 1
      },
      {
        "bookId": "EXO",
        "name": "Exod",
        "testament": "OT",
        "position": 2
      },
      {
        "bookId": "LEV",
        "name": "Lev",
        "testament": "OT",
        "position": 3
      },
      // ... 63 more
    ]
  }
}`,
      es: `{
  "data": {
    "books": [
      {
        "bookId": "GEN",
        "name": "Gen",
        "testament": "OT",
        "position": 1
      },
      {
        "bookId": "EXO",
        "name": "Exod",
        "testament": "OT",
        "position": 2
      },
      {
        "bookId": "LEV",
        "name": "Lev",
        "testament": "OT",
        "position": 3
      },
      // ... 63 more
    ]
  }
}`,
    },
  },

  search: {
    graphql: `query {
  search(translation: "{{translation}}", query: "{{searchTerm}}", limit: 5) {
    bookName
    chapter
    verse
    text
  }
}`,
    ruby: `results = client.search("{{searchTerm}}", translation: "{{translation}}", limit: 5)

results.each { |v| puts "#{v.book_name} #{v.chapter}:#{v.verse}" }`,
    node: `const results = await client.search("{{searchTerm}}", {
  translation: "{{translation}}",
  limit: 5,
});

results.forEach((v) => console.log(\`\${v.bookName} \${v.chapter}:\${v.verse}\`));`,
    response: {
      en: `{
  "data": {
    "search": [
      {
        "bookName": "Genesis",
        "chapter": 22,
        "verse": 2,
        "text": "He said, “Now take your son, your only son, whom you love, even Isaac, and go into the land of Moriah. Offer him there as a burnt offering on one of the mountains which I will tell you of.”"
      },
      {
        "bookName": "Genesis",
        "chapter": 24,
        "verse": 67,
        "text": "Isaac brought her into his mother Sarah’s tent, and took Rebekah, and she became his wife. He loved her. Isaac was comforted after his mother’s death."
      },
      {
        "bookName": "Genesis",
        "chapter": 25,
        "verse": 28,
        "text": "Now Isaac loved Esau, because he ate his venison. Rebekah loved Jacob."
      },
      // ... 2 more
    ]
  }
}`,
      es: `{
  "data": {
    "search": [
      {
        "bookName": "Génesis",
        "chapter": 3,
        "verse": 17,
        "text": "Y al hombre dijo: Por cuanto obedeciste á la voz de tu mujer, y comiste del árbol de que te mandé diciendo, No comerás de él; maldita será la tierra por amor de ti; con dolor comerás de ella todos los días de tu vida;"
      },
      {
        "bookName": "Génesis",
        "chapter": 10,
        "verse": 16,
        "text": "Y al Jebuseo, y al Amorrheo, y al Gergeseo,"
      },
      {
        "bookName": "Génesis",
        "chapter": 12,
        "verse": 13,
        "text": "Ahora pues, di que eres mi hermana, para que yo haya bien por causa tuya, y viva mi alma por amor de ti."
      },
      // ... 2 more
    ]
  }
}`,
    },
  },

  // Pinned to spa-rv1909 in both locales: it is the only translation with
  // embeddings, so an English example would return an empty array.
  // Pinned to spa-rv1909 in both locales: it is the only translation with
  // embeddings, so an English example would return an empty array. It is also
  // the argument default, which is why the query below can omit it.
  semanticSearch: {
    graphql: `query SemanticSearch {
  semanticSearch(query: "fe y esperanza", limit: 5) {
    verse {
      bookName
      chapter
      verse
      text
    }
    similarity
  }
}`,
    // bibleql-ruby has no semantic_search method as of the current release.
    ruby: null,
    node: `const results = await client.semanticSearch("fe y esperanza", {
  limit: 5,
});

results.forEach((r) => console.log(r.similarity, r.verse.text));`,
    response: {
      en: `{
  "data": {
    "semanticSearch": [
      {
        "verse": {
          "bookName": "Job",
          "chapter": 17,
          "verse": 15,
          "text": "¿Dónde pues estará ahora mi esperanza? y mi esperanza ¿quién la verá?"
        },
        "similarity": 0.6582
      },
      {
        "verse": {
          "bookName": "Romanos",
          "chapter": 5,
          "verse": 4,
          "text": "Y la paciencia, prueba; y la prueba, esperanza;"
        },
        "similarity": 0.6021
      },
      {
        "verse": {
          "bookName": "Romanos",
          "chapter": 8,
          "verse": 24,
          "text": "Porque en esperanza somos salvos; mas la esperanza que se ve, no es esperanza; porque lo que alguno ve, ¿á qué esperarlo?"
        },
        "similarity": 0.597
      },
      {
        "verse": {
          "bookName": "Job",
          "chapter": 5,
          "verse": 16,
          "text": "Pues es esperanza al menesteroso, y la iniquidad cerrará su boca."
        },
        "similarity": 0.5869
      },
      {
        "verse": {
          "bookName": "Proverbios",
          "chapter": 10,
          "verse": 28,
          "text": "La esperanza de los justos es alegría; mas la esperanza de los impíos perecerá."
        },
        "similarity": 0.5624
      }
    ]
  }
}`,
      es: `{
  "data": {
    "semanticSearch": [
      {
        "verse": {
          "bookName": "Job",
          "chapter": 17,
          "verse": 15,
          "text": "¿Dónde pues estará ahora mi esperanza? y mi esperanza ¿quién la verá?"
        },
        "similarity": 0.6582
      },
      {
        "verse": {
          "bookName": "Romanos",
          "chapter": 5,
          "verse": 4,
          "text": "Y la paciencia, prueba; y la prueba, esperanza;"
        },
        "similarity": 0.6021
      },
      {
        "verse": {
          "bookName": "Romanos",
          "chapter": 8,
          "verse": 24,
          "text": "Porque en esperanza somos salvos; mas la esperanza que se ve, no es esperanza; porque lo que alguno ve, ¿á qué esperarlo?"
        },
        "similarity": 0.597
      },
      {
        "verse": {
          "bookName": "Job",
          "chapter": 5,
          "verse": 16,
          "text": "Pues es esperanza al menesteroso, y la iniquidad cerrará su boca."
        },
        "similarity": 0.5869
      },
      {
        "verse": {
          "bookName": "Proverbios",
          "chapter": 10,
          "verse": 28,
          "text": "La esperanza de los justos es alegría; mas la esperanza de los impíos perecerá."
        },
        "similarity": 0.5624
      }
    ]
  }
}`,
    },
  },

  randomVerse: {
    graphql: `query {
  randomVerse(translation: "{{translation}}", testament: "NT") {
    bookName
    chapter
    verse
    text
  }
}`,
    ruby: `verse = client.random_verse(testament: "NT", translation: "{{translation}}")

puts "#{verse.book_name} #{verse.chapter}:#{verse.verse}"`,
    node: `const verse = await client.randomVerse({
  translation: "{{translation}}",
  testament: "NT",
});

console.log(verse.bookName, verse.chapter, verse.verse);`,
    response: {
      en: `{
  "data": {
    "randomVerse": {
      "bookName": "1 Corinthians",
      "chapter": 11,
      "verse": 23,
      "text": "For I received from the Lord that which also I delivered to you, that the Lord Jesus on the night in which he was betrayed took bread."
    }
  }
}`,
      es: `{
  "data": {
    "randomVerse": {
      "bookName": "Juan",
      "chapter": 9,
      "verse": 26,
      "text": "Y volviéronle á decir: ¿Qué te hizo? ¿Cómo te abrió los ojos?"
    }
  }
}`,
    },
  },

  verseOfTheDay: {
    graphql: `query {
  verseOfTheDay(translation: "{{translation}}") {
    reference
    text
  }
}`,
    ruby: `passage = client.verse_of_the_day(translation: "{{translation}}")

puts passage.reference
puts passage.text`,
    node: `const passage = await client.verseOfTheDay({
  translation: "{{translation}}",
});

console.log(passage.reference, passage.text);`,
    response: {
      en: `{
  "data": {
    "verseOfTheDay": {
      "reference": "Philippians 1:21",
      "text": "For to me to live is Christ, and to die is gain."
    }
  }
}`,
      es: `{
  "data": {
    "verseOfTheDay": {
      "reference": "Philippians 1:21",
      "text": "Porque para mí el vivir es Cristo, y el morir es ganancia."
    }
  }
}`,
    },
  },

  bibleIndex: {
    graphql: `query {
  bibleIndex(translation: "{{translation}}") {
    bookId
    name
    chapterCount
  }
}`,
    ruby: `index = client.bible_index(translation: "{{translation}}")

index.each { |book| puts "#{book.name}: #{book.chapter_count} chapters" }`,
    node: `const index = await client.bibleIndex({
  translation: "{{translation}}",
});

index.forEach((b) => console.log(b.name, b.chapterCount));`,
    response: {
      en: `{
  "data": {
    "bibleIndex": [
      {
        "bookId": "GEN",
        "name": "Genesis",
        "chapterCount": 50
      },
      {
        "bookId": "EXO",
        "name": "Exodus",
        "chapterCount": 40
      },
      {
        "bookId": "LEV",
        "name": "Leviticus",
        "chapterCount": 27
      },
      // ... 63 more
    ]
  }
}`,
      es: `{
  "data": {
    "bibleIndex": [
      {
        "bookId": "GEN",
        "name": "Génesis",
        "chapterCount": 50
      },
      {
        "bookId": "EXO",
        "name": "Éxodo",
        "chapterCount": 40
      },
      {
        "bookId": "LEV",
        "name": "Levítico",
        "chapterCount": 27
      },
      // ... 63 more
    ]
  }
}`,
    },
  },

  // Pinned to spa-rv1909, the translation that is concordance-indexed, so the
  // response below is real output rather than a plausible-looking sample.
  // Pinned to spa-rv1909, a concordance-indexed translation, so the response is
  // real output. `first: 10` was requested; the sample below keeps three edges.
  concordance: {
    graphql: `query ConcordanceBasic {
  concordance(translation: "spa-rv1909", word: "misericordia", first: 10) {
    totalCount
    entry {
      lemma
      surfaceForms
      totalOccurrences
      verseCount
      occurrencesByTestament {
        old
        new
      }
    }
    edges {
      cursor
      node {
        verse {
          bookName
          chapter
          verse
          text
        }
        context
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}`,
    // Neither SDK exposes concordance yet.
    ruby: null,
    node: null,
    response: {
      en: `{
  "data": {
    "concordance": {
      "totalCount": 398,
      "entry": {
        "lemma": "misericordi",
        "surfaceForms": [
          "misericordia",
          "misericordias",
          "misericordioso",
          "misericordiosos"
        ],
        "totalOccurrences": 424,
        "verseCount": 398,
        "occurrencesByTestament": {
          "old": 327,
          "new": 71
        }
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
        },
        // ... 7 more
      ],
      "pageInfo": {
        "hasNextPage": true,
        "endCursor": "MTo0MzoxNA=="
      }
    }
  }
}`,
      es: `{
  "data": {
    "concordance": {
      "totalCount": 398,
      "entry": {
        "lemma": "misericordi",
        "surfaceForms": [
          "misericordia",
          "misericordias",
          "misericordioso",
          "misericordiosos"
        ],
        "totalOccurrences": 424,
        "verseCount": 398,
        "occurrencesByTestament": {
          "old": 327,
          "new": 71
        }
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
        },
        // ... 7 more
      ],
      "pageInfo": {
        "hasNextPage": true,
        "endCursor": "MTo0MzoxNA=="
      }
    }
  }
}`,
    },
  },
  // Filtering narrows edges and totalCount but never `entry`, which stays
  // translation-wide. Note `book` accepts the localized name "Salmos".
  concordanceByBook: {
    graphql: `query ConcordanceByBook {
  concordance(
    translation: "spa-rv1909"
    word: "misericordia"
    book: "Salmos"
    first: 10
  ) {
    totalCount
    edges {
      node {
        verse {
          bookName
          chapter
          verse
          text
        }
      }
    }
  }
}`,
    ruby: null,
    node: null,
    response: {
      en: `{
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
        },
        // ... 7 more
      ]
    }
  }
}`,
      es: `{
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
        },
        // ... 7 more
      ]
    }
  }
}`,
    },
  },

  concordanceIndex: {
    graphql: `query {
  concordanceIndex(translation: "spa-rv1909", prefix: "mis", first: 5) {
    lemma
    verseCount
    totalOccurrences
  }
}`,
    ruby: null,
    node: null,
    response: {
      en: `{
  "data": {
    "concordanceIndex": [
      {
        "lemma": "misael",
        "verseCount": 8,
        "totalOccurrences": 8
      },
      {
        "lemma": "misam",
        "verseCount": 2,
        "totalOccurrences": 2
      },
      {
        "lemma": "miseal",
        "verseCount": 2,
        "totalOccurrences": 2
      },
      // ... 2 more
    ]
  }
}`,
      es: `{
  "data": {
    "concordanceIndex": [
      {
        "lemma": "misael",
        "verseCount": 8,
        "totalOccurrences": 8
      },
      {
        "lemma": "misam",
        "verseCount": 2,
        "totalOccurrences": 2
      },
      {
        "lemma": "miseal",
        "verseCount": 2,
        "totalOccurrences": 2
      },
      // ... 2 more
    ]
  }
}`,
    },
  },
};

export default examples;
