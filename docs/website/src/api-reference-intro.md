---
title: API Reference
slug: /api-reference
description: Complete reference for the BibleQL GraphQL schema, generated from the schema itself.
---

# API Reference

Everything on the pages below is generated directly from the BibleQL GraphQL schema, so it
always matches what the API actually accepts and returns. Nothing here is written by hand.

The schema is exported from the Rails application with `bundle exec rake docs:schema` and
committed to the repository as `docs/generated/schema.graphql`; CI fails if it drifts out of
date. If a field appears here, it exists in production.

## How to read these pages

- **Queries** — the 14 entry points. Each lists its arguments, defaults and return type.
- **Objects** — the shapes that come back. `Verse` and `Passage` cover most responses.
- **Enums** and **Scalars** — the small set of constrained values, such as `Testament`.

Every request needs an API key. If you have not set one up yet, start with
[Authentication](/getting-started/authentication).

:::tip Looking for explanations rather than signatures?
The reference tells you *what* each field is. The [Guides](/guides/translations) explain *why*
and *when* to use them, with runnable examples in GraphQL, cURL, Ruby and Node.js.
:::

:::note One known placeholder
`Mutation.testField` is scaffolding left over from the original Rails generator. BibleQL is a
read-only API — there are no supported mutations. See
[API Behavior](/reference/api-behavior) for the full list of quirks worth knowing.
:::
