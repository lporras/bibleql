import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";
import { themes as prismThemes } from "prism-react-renderer";

/**
 * Every deployment-specific value lives here, so moving the site (for example back to
 * GitHub project pages at https://lporras.github.io/bibleql/) is a single edit:
 * set url to "https://lporras.github.io" and baseUrl to "/bibleql/".
 */
const SITE = {
  title: "BibleQL",
  tagline: "A GraphQL API for querying Bible verses across translations",
  url: "https://docs.bibleql.org",
  baseUrl: "/",
  organizationName: "lporras",
  projectName: "bibleql",
} as const;

const REPO_URL = `https://github.com/${SITE.organizationName}/${SITE.projectName}`;
const API_URL = "https://bibleql.org";

/**
 * Note on locales and local development:
 *
 * `docusaurus start` (the hot-reload dev server) serves exactly ONE locale per
 * process, and two processes cannot share this site directory — they corrupt
 * each other's `.docusaurus` cache. So `bin/docs` builds both locales and serves
 * them from a single origin, which is also what production does, and is what
 * makes this locale dropdown work. `bin/docs --watch` gives hot reload for one
 * locale at a time.
 */

const config: Config = {
  title: SITE.title,
  tagline: SITE.tagline,
  favicon: "img/favicon.svg",
  url: SITE.url,
  baseUrl: SITE.baseUrl,
  organizationName: SITE.organizationName,
  projectName: SITE.projectName,
  trailingSlash: false,

  // The docs are a reference: a dead link is a bug, so fail the build rather than ship one.
  onBrokenLinks: "throw",
  onBrokenAnchors: "throw",

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: "throw",
    },
  },

  i18n: {
    defaultLocale: "en",
    locales: ["en", "es"],
    localeConfigs: {
      en: { label: "English", htmlLang: "en" },
      es: { label: "Español", htmlLang: "es" },
    },
  },

  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
          routeBasePath: "/",
          // No editUrl: half the pages under api-reference/ are generated and
          // gitignored, so an "Edit this page" link would point at files that do
          // not exist in the repository. Contributions go through the GitHub link
          // in the navbar instead.
          showLastUpdateTime: false,
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  plugins: [
    [
      "@graphql-markdown/docusaurus",
      {
        // Reads the SDL committed by `bundle exec rake docs:schema`, so this build
        // needs no Ruby, no database and no network access.
        schema: "../generated/schema.graphql",
        rootPath: "./docs",
        baseURL: "api-reference",
        linkRoot: "/",
        homepage: "src/api-reference-intro.md",
        loaders: {
          GraphQLFileLoader: "@graphql-tools/graphql-file-loader",
        },
        // Generated output is gitignored and every build regenerates it from the committed
        // SDL via `graphql-to-doc --force`, so schema diffing is unnecessary. Leaving
        // diffMethod unset avoids pulling in the optional @graphql-markdown/diff package.
        printTypeOptions: {
          deprecated: "group",
          typeBadges: true,
          // "api" (the default) nests Directives under both Operations and Types, which
          // collides on sidebar translation keys. "entity" groups by kind instead, giving
          // one category per kind and a flatter, easier-to-scan sidebar.
          hierarchy: "entity",
        },
        docOptions: {
          index: true,
          frontMatter: {
            // Generated pages must not offer an "edit this page" link to a file that
            // is gitignored and regenerated on every build.
            custom_edit_url: null,
          },
        },
      },
    ],
  ],

  themeConfig: {
    image: "img/social-card.png",
    navbar: {
      title: SITE.title,
      logo: { alt: "BibleQL", src: "img/logo.svg" },
      items: [
        { type: "docSidebar", sidebarId: "docsSidebar", position: "left", label: "Docs" },
        { type: "docSidebar", sidebarId: "apiSidebar", position: "left", label: "API Reference" },
        { type: "docSidebar", sidebarId: "sdkSidebar", position: "left", label: "SDKs" },
        { href: `${API_URL}/playground`, label: "Playground", position: "right" },
        { type: "localeDropdown", position: "right" },
        { href: REPO_URL, label: "GitHub", position: "right" },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Documentation",
          items: [
            { label: "Quickstart", to: "/getting-started/quickstart" },
            { label: "Authentication", to: "/getting-started/authentication" },
            { label: "API Reference", to: "/api-reference" },
          ],
        },
        {
          title: "Tools",
          items: [
            { label: "Playground", href: `${API_URL}/playground` },
            { label: "Request an API key", href: `${API_URL}/api-keys/request/new` },
          ],
        },
        {
          title: "Open source",
          items: [
            { label: "bibleql on GitHub", href: REPO_URL },
            { label: "bibleql-ruby (GitHub)", href: "https://github.com/lporras/bibleql-ruby" },
            { label: "bibleql-ruby (RubyGems)", href: "https://rubygems.org/gems/bibleql-ruby" },
            { label: "bibleql-js (GitHub)", href: "https://github.com/lporras/bibleql-js" },
            { label: "bibleql-js (npm)", href: "https://www.npmjs.com/package/bibleql-js" },
          ],
        },
      ],
      copyright: `BibleQL is open source under the MIT License. Bible texts remain under their own licenses.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ["graphql", "ruby", "bash", "json"],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
