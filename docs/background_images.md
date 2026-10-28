# Background images (Unsplash proxy)

Internal: not published on docs.bibleql.org. The Verse Image Creator in bibleql-reader searches
Unsplash for backgrounds through BibleQL, so the Unsplash access key lives only on this server
and is never compiled into a client build.

Only **installation keys** (the BibleQL client apps, see
[installation keys](website/docs/getting-started/api-keys.mdx)) can use it.
`backgroundImages` and `trackImageDownload` are declared with `installation_only: true`
(`Types::BaseField`), so for any other key, and for the exported SDL in
`docs/generated/schema.graphql` that feeds the public API reference, they don't exist:

- introspection doesn't list them;
- querying them is a validation error: `Field 'backgroundImages' doesn't exist on type 'Query'`;
- the `BackgroundImage*` types don't appear in the public schema.

To see them in GraphiQL, authenticate with an installation token (register one with
`registerInstallation`, below).

## Searching

```graphql
query Backgrounds($query: String!, $page: Int) {
  backgroundImages(query: $query, page: $page, perPage: 24) {
    page totalPages hasMore errorCode
    images {
      id width height color blurHash altDescription
      urls { raw full regular small thumb }
      photographer { name username profileUrl }
      unsplashUrl
      downloadLocation
    }
  }
}
```

| Argument | Default | Server behaviour |
|---|---|---|
| `query` | required | Trimmed, lower-cased, spaces squeezed, max 100 chars. Blank → `INVALID_INPUT` error |
| `page` | `1` | Clamped to 1..100 |
| `perPage` | `24` | Clamped to 1..30 (Unsplash's max) |

Unsplash is always called with `content_filter=high`, matching what the reader did before.

### Caching

`BackgroundImageSearch` caches each result for **12 hours**, keyed by
SHA-256(normalized query) + page + perPage, in `Rails.cache` (Solid Cache in production).
"Sunrise" and "  sunrise " share an entry, so popular words cost one Unsplash call per 12h
for all users. Each photo's `download_location` is cached separately for **24 hours**, longer
than the search, so `trackImageDownload` always finds it for a cached search.

### Errors

Unsplash failures come back as data, not GraphQL errors, because the reader's `gqlRequest`
throws on any top-level error:

| `errorCode` | Cause | Notes |
|---|---|---|
| `RATE_LIMITED` | Unsplash 429, or a 403 "Rate Limit Exceeded" | Sets a 5-minute backoff (`unsplash/backoff`); searches during it return `RATE_LIMITED` without calling Unsplash |
| `NOT_CONFIGURED` | No `UNSPLASH_ACCESS_KEY`, or Unsplash answered 401 | |
| `UNAVAILABLE` | Timeout (5s), network error, 5xx, non-JSON body | |

`images` is `[]` and `totalPages` is `0` in every error case. Failures are never cached.

## Attribution and hotlinking

The values come from the unsplash gem. It adds `utm_source=<UNSPLASH_UTM_SOURCE>`,
`utm_medium=referral` and `utm_campaign=api-credit` to `photographer.profileUrl`,
`unsplashUrl`, `downloadLocation` and the image URLs. The client must:

- render `urls.*` directly from Unsplash's CDN (hotlinking is required; never rehost or cache
  the bytes);
- show "Photo by *name* on Unsplash", linking the name to `photographer.profileUrl` and
  "Unsplash" to `unsplashUrl`, unmodified.

`UNSPLASH_UTM_SOURCE` defaults to `bibleql-reader`. That is the app name registered with Unsplash
and the reader's old `APP_SLUG`, so the referral tracking doesn't change.

## Download tracking

Unsplash requires a ping to the photo's `links.download_location` when a user *uses* a photo
(sets it as a background or exports with it), not when it's merely shown in results:

```graphql
mutation Used($id: ID!) {
  trackImageDownload(input: { imageId: $id }) { queued }
}
```

- `imageId` must match `/\A[\w-]{1,32}\z/`, otherwise `INVALID_INPUT`.
- The server uses the cached `download_location` from the search, which carries the signed
  `ixid`. If none is cached, it falls back to `https://api.unsplash.com/photos/:id/download`.
  The client never supplies a URL, so the endpoint can't be used to make the server fetch
  arbitrary hosts.
- The ping is sent from `TrackUnsplashDownloadJob` (Solid Queue). The mutation returns at once.
  Failures are logged as `[unsplash] download tracking failed` and discarded, not retried.
- `UnsplashClient#track_download` refuses any URL other than
  `https://api.unsplash.com/photos/:id/download` before attaching the key. HTTParty's own
  same-host check is a second guard.

`downloadLocation` is returned on each image for reference only. Clients must not call it: it
needs the access key.

## Configuration

| Env var | Purpose |
|---|---|
| `UNSPLASH_ACCESS_KEY` | Unsplash Client-ID. Falls back to `credentials.unsplash.access_key`. Server-only; never appears in a response (spec-enforced) |
| `UNSPLASH_UTM_SOURCE` | Referral `utm_source`, default `bibleql-reader` |

No Unsplash secret key is needed: only public Client-ID auth is used.

Configured in `config/initializers/unsplash.rb`, which also sets a 5s HTTParty timeout.

### The unsplash gem fork

The Gemfile uses `unsplash` from `github: "lporras/unsplash_rb", branch: "master"`. The released
3.x gem can't be used:

- its `faraday-multipart ~> 1.0.4` pin resolves only to versions declaring Ruby `< 4`;
- it uses `OpenStruct` without requiring `ostruct`, which Ruby 4 no longer loads by default.

The fork fixes both. It also sends `Accept-Version: v1` on public requests and no longer raises
`NoMethodError` for JSON error bodies without an `errors` array. Run its specs with Ruby 4.0.9
(`.tool-versions`).

## Code map

| File | Role |
|---|---|
| `app/services/unsplash_client.rb` | Gem wrapper; maps every failure to `UnsplashClient::{NotConfigured,RateLimited,Unavailable}` |
| `app/services/background_image_search.rb` | Normalization, caching, backoff, photo mapping |
| `app/graphql/types/background_image*_type.rb` | Result types |
| `app/graphql/mutations/track_image_download.rb` | Download ping mutation |
| `app/jobs/track_unsplash_download_job.rb` | Sends the ping |
| `app/graphql/types/base_field.rb` | `installation_only:` visibility |

## Tests

WebMock blocks all real HTTP in specs (`spec/support/webmock.rb`). Unsplash responses come from
`spec/fixtures/files/unsplash_search.json` via `stub_unsplash_search`
(`spec/support/unsplash_helpers.rb`), which also sets a fake access key. Never use a real key
from `.env`. Specs needing a working cache are tagged `:with_cache`.
