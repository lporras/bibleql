# BibleQL Documentation — Implementation Proposal

## Goal

Build a new public documentation website for BibleQL using **Docusaurus**, hosted on **GitHub Pages**, and maintained inside the existing BibleQL repository.

The documentation must:

- be open source;
- be self-contained in the BibleQL repository;
- not require changes to the Rails application for serving documentation;
- be deployable as a static website;
- support **English and Spanish** initially;
- document the GraphQL API in detail;
- explain authentication and API keys;
- document all supported queries, types, enums and relevant GraphQL structures;
- provide practical examples;
- provide cURL examples;
- provide Ruby SDK examples;
- provide Node.js / TypeScript SDK examples;
- explain BibleQL concepts such as translations, localized book names and references;
- keep the GraphQL schema as the source of truth for the API reference;
- avoid duplicating API definitions manually;
- integrate with GitHub Actions and GitHub Pages.

The existing Rails application should remain responsible only for the API itself.

---

# 1. Current BibleQL Context

BibleQL is a Ruby on Rails GraphQL API.

The current repository already contains:

- GraphQL API;
- `/graphql` endpoint;
- `/playground`;
- GraphiQL for development;
- API key authentication;
- multiple Bible translations;
- localized Bible book names;
- translation/language discovery;
- multiple GraphQL queries;
- existing example queries;
- Ruby SDK;
- Node.js SDK.

The repository currently advertises 47 Bible translations across 31 languages.

The current API uses:

```http
Authorization: Bearer bql_live_xxxxxxxxxxxxxxxx
```

Production keys use:

```text
bql_live_
```

Development/test keys use:

```text
bql_test_
```

The existing README documents the main GraphQL queries and points to `docs/example_queries.md`.

The documentation project should reuse this existing knowledge instead of creating a parallel API definition.

---

# 2. Technology Decision

Use:

## Docusaurus

Docusaurus will be the documentation framework.

Reasons:

- open source;
- static site generation;
- excellent Markdown/MDX support;
- built-in internationalization;
- suitable for GitHub Pages;
- React-based customization;
- supports custom documentation components;
- can coexist with the Rails application without modifying Rails.

Do NOT add a Rails documentation engine.

Do NOT serve the documentation through Rails.

Do NOT add documentation routes such as `/docs` to the Rails application.

The documentation should be a static site.

---

# 3. Repository Structure

Create a dedicated documentation website inside the existing repository.

Recommended structure:

```text
bibleql/
├── app/
├── config/
├── db/
├── lib/
├── spec/
├── docs/
│   ├── website/
│   │   ├── docs/
│   │   ├── src/
│   │   ├── static/
│   │   ├── docusaurus.config.ts
│   │   ├── sidebars.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── generated/
│   │   └── graphql/
│   │
│   └── scripts/
│       └── ...
│
├── .github/
│   └── workflows/
│       └── docs.yml
│
└── ...
```

If the existing `docs/` directory contains useful documentation, preserve it and migrate/reuse its contents rather than deleting it.

In particular, inspect and reuse:

```text
docs/example_queries.md
```

before creating duplicate examples.

---

# 4. Public Documentation URL

The initial deployment should target GitHub Pages.

Expected URL:

```text
https://lporras.github.io/bibleql/
```

If a custom domain is configured later, Docusaurus should allow changing the deployment configuration without restructuring the documentation.

The site should use:

```text
baseUrl: "/bibleql/"
```

for GitHub Project Pages.

Do not hard-code `/bibleql/` throughout the documentation.

---

# 5. Languages

Initial documentation locales:

```text
en
es
```

English is the default locale.

Spanish is the secondary locale.

Docusaurus configuration should conceptually use:

```ts
i18n: {
  defaultLocale: "en",
  locales: ["en", "es"],
}
```

The documentation language is independent from the Bible translation identifier.

For example:

```text
spa-bes
spa-rvr1960
spa-ntv
```

are Bible translation identifiers.

They are not documentation locales.

The documentation locale is:

```text
es
```

Similarly:

```text
eng-web
eng-kjv
```

belong to:

```text
en
```

---

# 6. Translation-Aware Documentation

BibleQL's Bible translations should influence the examples shown in the documentation.

English examples should prefer an English Bible translation.

Spanish examples should prefer a Spanish Bible translation.

Do not hard-code one arbitrary translation everywhere.

Create a small documentation configuration that defines preferred examples.

For example:

```ts
const documentationExamples = {
  en: {
    translation: "eng-web",
    reference: "John 3:16",
  },
  es: {
    translation: "spa-bes",
    reference: "Juan 3:16",
  },
};
```

However, this should be configurable and should not be mixed with Docusaurus i18n configuration.

The BibleQL translation registry remains the source of truth for available translations.

---

# 7. Documentation Information Architecture

The navigation should be approximately:

```text
Getting Started
├── Introduction
├── Quickstart
├── Authentication
├── API Keys
└── Your First Query

Guides
├── Bible Translations
├── Languages
├── Bible References
├── Localized Book Names
├── Searching the Bible
├── Semantic Search
├── Concordance
├── Verse of the Day
└── Bible Index

API Reference
├── Overview
├── Queries
│   ├── translations
│   ├── translation
│   ├── languages
│   ├── books
│   ├── passage
│   ├── chapter
│   ├── verse
│   ├── search
│   ├── semanticSearch
│   ├── randomVerse
│   ├── verseOfTheDay
│   ├── bibleIndex
│   ├── concordance
│   └── concordanceIndex
│
├── Types
├── Enums
├── Inputs
└── Scalars

SDKs
├── Ruby
└── Node.js

Reference
├── Errors
├── Rate Limits
└── API Behavior
```

The exact list must be generated/verified against the current GraphQL schema instead of blindly copying this proposal.

---

# 8. Getting Started

Create a concise quickstart.

The first example should demonstrate:

1. obtaining an API key;
2. setting it as an environment variable;
3. making a cURL request;
4. receiving a Bible passage;
5. understanding the response.

Example:

```bash
export BIBLEQL_API_KEY="bql_live_..."
```

Then:

```bash
curl https://bibleql.org/graphql \
  -H "Authorization: Bearer $BIBLEQL_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "query": "query { passage(translation: \"eng-web\", reference: \"John 3:16\") { reference text translationName } }"
  }'
```

Do not invent the production API URL.

Read it from the existing BibleQL configuration/repository and use the real production endpoint.

---

# 9. Authentication Documentation

Create a dedicated Authentication page.

Explain:

- all GraphQL requests require an API key;
- `Authorization` header;
- Bearer authentication;
- `bql_live_` production keys;
- `bql_test_` development/test keys;
- how users obtain a key;
- how keys should be stored;
- environment variables;
- how to avoid exposing API keys in browser/client-side applications;
- what happens when a key is invalid;
- rate limits;
- key revocation if applicable.

The canonical example should be:

```http
Authorization: Bearer $BIBLEQL_API_KEY
```

Never put a real API key in documentation.

---

# 10. Query Documentation

Every public Query should have a useful documentation page.

A query page should contain:

## Description

Explain what the query does in plain language.

## GraphQL signature

Example:

```graphql
passage(
  translation: String!
  reference: String!
): Passage
```

The signature must be generated from the real schema whenever possible.

## Arguments

Document:

- argument name;
- type;
- required/optional;
- description;
- accepted values where relevant;
- examples.

## Basic example

```graphql
query {
  passage(
    translation: "eng-web"
    reference: "John 3:16"
  ) {
    reference
    text
    translationName
  }
}
```

## cURL

Provide an immediately executable cURL request.

## Ruby

Use the official `bibleql-ruby` client.

## Node.js / TypeScript

Use the official `bibleql-js` client.

## Response

Show a representative response.

Do not unnecessarily duplicate large Bible passages.

Use short examples where possible.

---

# 11. Code Examples

The documentation should use tabs for code examples:

```text
GraphQL | cURL | Ruby | Node.js
```

Example:

### GraphQL

```graphql
query {
  passage(
    translation: "eng-web"
    reference: "John 3:16"
  ) {
    reference
    text
  }
}
```

### cURL

```bash
curl https://bibleql.org/graphql \
  -H "Authorization: Bearer $BIBLEQL_API_KEY" \
  -H "Content-Type: application/json" \
  --data '{
    "query": "query { passage(translation: \"eng-web\", reference: \"John 3:16\") { reference text } }"
  }'
```

### Ruby

Use the actual public API of the `bibleql-ruby` package.

Example style:

```ruby
require "bibleql"

BibleQL.configure do |config|
  config.api_key = ENV["BIBLEQL_API_KEY"]
end

client = BibleQL.client

passage = client.passage(
  "John 3:16",
  translation: "eng-web"
)

puts passage.text
```

### Node.js

Use the actual public API of `bibleql-js`.

Do not invent SDK methods.

Before writing SDK examples, inspect the actual SDK repositories/packages.

---

# 12. Example Generation

Avoid maintaining the same API example manually in four places.

Introduce a concept of documentation examples.

For example:

```text
docs/examples/
├── passage/
│   ├── example.graphql
│   ├── example.json
│   ├── curl.sh
│   ├── ruby.rb
│   └── node.ts
│
├── verse/
│   ├── ...
│
└── search/
    ├── ...
```

Alternatively, if a simpler structure is more appropriate after inspecting the repository, use Markdown/MDX files with shared example components.

The important requirement is:

> GraphQL, cURL, Ruby and Node examples for the same operation must represent the same request.

Avoid situations where the GraphQL example uses `John 3:16` but the Ruby example uses another query.

---

# 13. GraphQL Schema as Source of Truth

The API reference must be derived from the real GraphQL schema.

Do not manually recreate:

```text
Query
Type
Enum
Input
Scalar
```

definitions in documentation.

Use the current GraphQL schema/introspection output.

Investigate whether `graphql-ruby` can export the schema directly during the documentation build.

Preferred flow:

```text
Rails GraphQL Schema
        ↓
Schema export
        ↓
schema.graphql
        ↓
Docusaurus GraphQL documentation generation
        ↓
API Reference
```

The generated schema should not be edited manually.

---

# 14. GraphQL Documentation Generator

Evaluate and use:

```text
docusaurus-graphql-plugin
```

if it works cleanly with BibleQL's current GraphQL schema.

The plugin is specifically designed to generate Markdown documentation from a GraphQL schema.

Use it for:

- Query documentation;
- Types;
- Enums;
- Interfaces;
- Input objects;
- Scalars;
- field descriptions;
- argument information.

Do not force the plugin to handle conceptual guides.

Conceptual documentation remains handwritten MDX.

If the plugin is abandoned, incompatible, or creates unacceptable output, create a small BibleQL-specific schema-to-MDX generator instead.

Do not introduce a SaaS dependency.

---

# 15. Schema Generation

Create a reproducible command from the BibleQL repository.

Possible command:

```bash
bin/docs schema
```

or:

```bash
bundle exec rake docs:schema
```

The command should:

1. load the Rails environment;
2. load the GraphQL schema;
3. export the schema;
4. write the generated schema to the documentation build directory;
5. avoid modifying application data;
6. work in CI.

Prefer using the Ruby GraphQL schema directly instead of making a network request against production.

---

# 16. Translation Documentation

Create a dedicated guide explaining the BibleQL translation model.

Explain the difference between:

```text
Language
Translation
Translation identifier
Localized book names
```

For example:

```text
Language: Spanish

Translations:
- spa-bes
- spa-rvr1960
- spa-ntv
...
```

Explain that the `translation` argument uses the translation identifier.

Example:

```graphql
query {
  passage(
    translation: "spa-bes"
    reference: "Juan 3:16"
  ) {
    reference
    text
    translationName
  }
}
```

The Spanish documentation should use a Spanish Bible example.

The English documentation should use an English Bible example.

---

# 17. Bible References

Create a dedicated guide explaining the reference formats currently supported.

Document at least:

```text
Single verse
John 3:16

Verse range
John 3:16-18

Multiple ranges
Matthew 25:31-33,46

Full chapter
Genesis 1

Cross-chapter
Romans 12:1,3-4 & 13:2-4

Localized names
Mateo 28:18-20
Lucas 3:1-10
```

Verify all examples against the actual implementation/tests.

Do not assume that every language uses English book names.

---

# 18. Search Documentation

Document the difference between:

```text
search
semanticSearch
concordance
concordanceIndex
```

Especially explain:

- normal text search;
- semantic search;
- exact/exhaustive concordance;
- stemming behavior;
- language-dependent search behavior;
- indexing requirements where relevant.

The current BibleQL README already documents important concordance behavior and rate limits; migrate this information into proper documentation rather than leaving it only in README.

---

# 19. Rate Limits

Create a dedicated page.

Document the currently configured limits.

At present, the project documents:

```text
GraphQL requests per IP:
100/minute

GraphQL requests per API key:
1,000/day

API key request form:
5/hour/IP
```

Verify these values against the actual Rails configuration before publishing.

Document:

```http
429 Too Many Requests
```

and the `Retry-After` header.

Do not hard-code values in multiple documentation pages.

---

# 20. Error Documentation

Document common error scenarios:

- missing API key;
- invalid API key;
- invalid GraphQL query;
- invalid translation;
- invalid Bible reference;
- missing concordance index;
- rate limiting;
- server errors.

Show representative GraphQL/HTTP responses where useful.

Do not expose internal stack traces or implementation details.

---

# 21. Spanish Documentation

Spanish documentation should be a real translation, not a machine-translated copy left unreviewed.

Use natural technical Spanish.

Keep technical identifiers unchanged:

```text
GraphQL
Query
Mutation
API
API key
Bearer
cURL
Ruby
Node.js
TypeScript
```

Do not translate GraphQL field names.

For example:

```graphql
passage
translation
reference
translationName
```

remain exactly the same.

Only explanatory prose is translated.

---

# 22. English Documentation

English is the canonical documentation language.

All new documentation should first be written in English.

Spanish documentation should then be synchronized with the English source.

If a page exists in English but not Spanish, Docusaurus should not silently make the missing translation look complete.

Prefer clearly marking untranslated pages where necessary.

---

# 23. Documentation Navigation

The header should contain:

```text
BibleQL

Docs
API Reference
SDKs
GitHub

[English / Español]
```

The locale selector should be provided by Docusaurus.

The GitHub link should point to:

```text
https://github.com/lporras/bibleql
```

Use the real repository URL from project configuration.

---

# 24. Playground

The Playground remains available.

It should NOT be removed.

The relationship should be:

```text
Documentation
     │
     ├── Learn
     ├── API Reference
     └── Try it
            ↓
       Playground
```

Documentation is for learning and reference.

Playground is for experimentation.

The Playground should not be expected to replace the documentation.

---

# 25. GitHub Actions

Create:

```text
.github/workflows/docs.yml
```

The workflow should:

1. run when documentation changes;
2. run when GraphQL schema/API code changes;
3. install Node dependencies;
4. install Ruby dependencies if schema generation requires Rails;
5. generate the GraphQL schema;
6. generate API reference documentation;
7. build Docusaurus;
8. fail if the build fails;
9. deploy to GitHub Pages on pushes to the default branch.

Prefer GitHub's current Pages deployment actions rather than manually pushing to a `gh-pages` branch.

---

# 26. Pull Request Validation

Documentation changes should be testable locally.

Add documentation commands to the README or CONTRIBUTING documentation:

```bash
cd docs/website

npm install
npm start
```

and:

```bash
npm run build
```

If schema generation is required:

```bash
bin/docs schema
npm run build
```

The exact commands should be finalized after implementation.

---

# 27. CI Safety

The documentation build must not require:

- production database credentials;
- production API keys;
- access to the admin panel;
- private credentials;
- external SaaS documentation services.

The build should work using the repository and its public/open-source dependencies.

If the Rails schema requires booting Rails, use a test/development environment with the minimum required configuration.

---

# 28. Generated Files

Clearly separate:

```text
hand-written documentation
```

from:

```text
generated API documentation
```

Generated files should have a warning at the top where appropriate:

```text
This file is generated from the BibleQL GraphQL schema.
Do not edit manually.
```

Do not make generated files the primary authoring interface.

---

# 29. README Integration

Update the main BibleQL README with a prominent documentation link.

Add something like:

```text
## Documentation

Full API documentation:

https://lporras.github.io/bibleql/
```

Keep the README useful as a repository/project overview.

Move detailed API documentation into the documentation website.

---

# 30. What NOT to Build

Do not:

- add a SaaS documentation platform;
- require Fern/Mintlify/ReadMe/etc.;
- create a second API schema;
- duplicate GraphQL type definitions manually;
- move documentation into Rails views;
- expose API keys in examples;
- create one documentation site per Bible translation;
- create one documentation locale per Bible translation;
- translate GraphQL field names;
- remove the Playground;
- require production access during documentation builds.

---

# 31. Implementation Phases

## Phase 1 — Foundation

Implement:

- Docusaurus;
- `docs/website`;
- English locale;
- Spanish locale;
- GitHub Pages;
- GitHub Actions;
- base navigation;
- homepage;
- README documentation link.

## Phase 2 — Guides

Create:

- Introduction;
- Quickstart;
- Authentication;
- API Keys;
- Translations;
- Languages;
- Bible References;
- Searching;
- Rate Limits;
- Errors.

## Phase 3 — GraphQL API Reference

Generate:

- Query reference;
- Types;
- Enums;
- Inputs;
- Scalars.

Use the actual BibleQL schema.

## Phase 4 — Code Examples

Add synchronized:

- GraphQL;
- cURL;
- Ruby;
- Node.js/TypeScript.

Use the real public APIs of:

- `bibleql-ruby`;
- `bibleql-js`.

## Phase 5 — Spanish

Translate the complete documentation.

Ensure examples use Spanish Bible references and an appropriate Spanish translation.

## Phase 6 — Quality

Add:

- documentation build validation;
- schema generation validation;
- broken-link checking;
- consistent examples;
- README integration.

---

# 32. Definition of Done

The implementation is complete when:

- [ ] `docs/website` contains a working Docusaurus site.
- [ ] English is the default locale.
- [ ] Spanish is available through the locale selector.
- [ ] The site works under `/bibleql/`.
- [ ] GitHub Pages deploys automatically.
- [ ] Rails does not serve the documentation.
- [ ] The GraphQL schema is generated from the actual Rails GraphQL schema.
- [ ] API reference is generated from the schema.
- [ ] All public queries are documented.
- [ ] Important GraphQL types are documented.
- [ ] Authentication is documented.
- [ ] API key usage is documented.
- [ ] Rate limits are documented.
- [ ] Bible translations are documented.
- [ ] Bible reference formats are documented.
- [ ] cURL examples exist for the main queries.
- [ ] Ruby examples use the actual `bibleql-ruby` API.
- [ ] Node examples use the actual `bibleql-js` API.
- [ ] English examples use English Bible references.
- [ ] Spanish examples use Spanish Bible references.
- [ ] No real credentials exist in documentation.
- [ ] Documentation builds successfully in CI.
- [ ] README links to the public documentation.
- [ ] The Playground remains available.

---

# 33. Important Implementation Principle

The most important architectural rule is:

```text
BibleQL Rails
    ↓
GraphQL Schema
    ↓
Generated API Reference
```

while:

```text
Documentation writers
    ↓
Guides / explanations / tutorials
```

remain separate.

The schema is the source of truth for API structure.

The documentation is the source of truth for explaining how to use BibleQL.

Do not mix those responsibilities.

The final result should feel like a professional public developer portal while remaining entirely open source, static, GitHub-hosted, and versioned together with BibleQL.