# BibleQL — Example GraphQL Queries

All queries require an API key via the Authorization header:

```
Authorization: Bearer bql_live_xxxxxxxxxxxxxxxx
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
