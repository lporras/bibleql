/**
 * Shared values referenced from both docusaurus.config.ts and MDX pages, so a URL or a
 * rate limit is written down exactly once.
 *
 * Rate limits mirror config/initializers/rack_attack.rb. If you change them there,
 * change them here.
 */

export const REPO_URL = "https://github.com/lporras/bibleql";
export const API_URL = "https://bibleql.org";
export const GRAPHQL_ENDPOINT = `${API_URL}/graphql`;
export const PLAYGROUND_URL = `${API_URL}/playground`;
export const API_KEY_REQUEST_URL = `${API_URL}/api-keys/request/new`;

export const SDK = {
  ruby: {
    name: "bibleql-ruby",
    language: "Ruby",
    repo: "https://github.com/lporras/bibleql-ruby",
    registry: "https://rubygems.org/gems/bibleql-ruby",
    registryName: "RubyGems",
    install: 'gem "bibleql-ruby"',
  },
  node: {
    name: "bibleql-js",
    language: "Node.js / TypeScript",
    repo: "https://github.com/lporras/bibleql-js",
    registry: "https://www.npmjs.com/package/bibleql-js",
    registryName: "npm",
    install: "npm install bibleql-js",
  },
} as const;

export const SDK_EXAMPLES_REPO = "https://github.com/lporras/bibleql-example";

/**
 * Client setup prepended to every rendered Ruby and Node example, so each snippet
 * is runnable as pasted instead of assuming a `client` from nowhere.
 *
 * `apiUrl` is set explicitly because both SDKs currently default to a
 * Render-hosted host rather than bibleql.org. See sdks/configuration.
 */
export const SDK_SETUP = {
  ruby: `require "bibleql"

client = BibleQL::Client.new(
  api_key: ENV.fetch("BIBLEQL_API_KEY"),
  api_url: "${GRAPHQL_ENDPOINT}"
)`,
  node: `import { BibleQLClient } from "bibleql-js";

const client = new BibleQLClient({
  apiKey: process.env.BIBLEQL_API_KEY!,
  apiUrl: "${GRAPHQL_ENDPOINT}",
});`,
} as const;

/** Verified against config/initializers/rack_attack.rb. */
export const RATE_LIMITS = {
  graphqlPerIp: { limit: 100, period: "minute" },
  graphqlPerKey: { limit: 1000, period: "day" },
  apiKeyRequestPerIp: { limit: 5, period: "hour" },
} as const;

/**
 * Locale-appropriate example values. English prose uses an English Bible; Spanish prose
 * uses a Spanish one. See guides/semantic-search for the one query that must pin
 * spa-rv1909 in both locales, because it is the only translation with embeddings.
 */
export const EXAMPLES = {
  en: {
    translation: "eng-web",
    translationName: "World English Bible",
    reference: "John 3:16",
    rangeReference: "John 3:16-18",
    book: "JHN",
    searchTerm: "love",
    concordanceWord: "love",
  },
  es: {
    translation: "spa-rv1909",
    translationName: "Reina Valera 1909",
    reference: "Juan 3:16",
    rangeReference: "Juan 3:16-18",
    book: "JHN",
    searchTerm: "amor",
    concordanceWord: "amor",
  },
} as const;

export type DocsLocale = keyof typeof EXAMPLES;

export const SEMANTIC_SEARCH_TRANSLATION = "spa-rv1909";
