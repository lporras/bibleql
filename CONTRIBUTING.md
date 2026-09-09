# Contributing to BibleQL

Thank you for your interest in contributing to BibleQL! This guide will help you get started.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** with submodules:
   ```bash
   git clone --recurse-submodules https://github.com/YOUR_USERNAME/bibleql.git
   cd bibleql
   ```
3. **Set up the development environment:**
   ```bash
   bundle install
   bin/rails db:create db:migrate
   bundle exec rake bible:import
   ```

## Development Workflow

1. Create a feature branch from `main`:
   ```bash
   git checkout -b my-feature
   ```
2. Make your changes
3. Run the test suite:
   ```bash
   bundle exec rspec
   ```
4. Run the linter:
   ```bash
   bin/rubocop
   ```
5. Run security checks:
   ```bash
   bin/brakeman
   bundle exec bundler-audit
   ```
6. Commit your changes and push to your fork
7. Open a Pull Request against `main`

## Code Style

This project follows the [rubocop-rails-omakase](https://github.com/rails/rubocop-rails-omakase) style guide. Run `bin/rubocop` before submitting your PR to ensure your code conforms.

## Testing

- We use **RSpec** (not Minitest) for all tests
- Write tests for new features and bug fixes
- Run the full suite with `bundle exec rspec`
- Run a specific file with `bundle exec rspec spec/path/to/file_spec.rb`

### Test Structure

- `spec/models/` — Model specs
- `spec/requests/` — Request/integration specs
- `spec/services/` — Service object specs
- `spec/graphql/` — GraphQL query specs
- `spec/system/` — System/browser specs (Capybara + Selenium)

## Project Structure

Key directories to be aware of:

| Directory | Description |
|-----------|-------------|
| `app/graphql/` | GraphQL schema, types, and queries |
| `app/services/` | Service objects (BibleImporter, PassageLookup) |
| `app/models/` | ActiveRecord models |
| `db/open-bibles/` | Bible translation data (git submodule) |
| `config/initializers/` | Rack::Attack, ActiveAdmin, Resend config |

## Adding a New GraphQL Query

1. Define the field in `app/graphql/types/query_type.rb`
2. Create any new types in `app/graphql/types/`
3. **Describe everything.** Every type, field and argument needs a `description:`.
   `spec/graphql/schema_documentation_spec.rb` fails otherwise, because these descriptions
   are what the published API reference is built from.
4. Regenerate the schema and commit it:
   ```bash
   bundle exec rake docs:schema
   ```
   CI fails if `docs/generated/schema.graphql` does not match `app/graphql/`.
5. Add tests in `spec/graphql/` or `spec/requests/`
6. Update the playground default query if useful (`app/views/playground/show.html.erb`)
7. Consider adding the query to `docs/website/src/examples/index.ts` so it gets
   GraphQL/cURL/Ruby/Node example tabs in the docs

## Documentation site

The public documentation at [docs.bibleql.org](https://docs.bibleql.org) is a Docusaurus site
in `docs/website`. Rails does not serve it.

Requires Node.js 22.12 or newer. It runs as part of `bin/dev` (the `docs` process in
`Procfile.dev`), or on its own:

```bash
bin/docs          # both locales: http://localhost:3001/ and /es/
```

Dependencies install themselves on first run. Rails owns port 3000, so the docs use 3001
(`DOCS_PORT` to change it).

If you only want Rails, skip the docs process:

```bash
foreman start -f Procfile.dev -m docs=0
```

### Checking both languages

`bin/docs` builds **both** locales and serves them from one origin, which is what makes the
navbar language dropdown work — clicking Español on any page takes you to the same page under
`/es/`.

For hot reload while writing, use watch mode. `docusaurus start` serves only **one** locale per
process, so choose it:

```bash
bin/docs --watch                  # English
DOCS_LOCALE=es bin/docs --watch   # Spanish, served at /es/
```

Two caveats in watch mode:

- The language dropdown links to the locale that is not running, so it 404s. Use `bin/docs` to
  test switching.
- Never run two watch processes against `docs/website` at once. They share the `.docusaurus`
  cache and overwrite each other, which fails the webpack build with JSON parse errors. If that
  happens, `rm -rf docs/website/.docusaurus`.

`bin/docs` fails on broken links and broken anchors, so run it before opening a docs PR.

### How the API reference is generated

```text
app/graphql/**  ──rake docs:schema──▶  docs/generated/schema.graphql  (committed)
                                                    │
                                     graphql-to-doc │
                                                    ▼
                                  docs/website/docs/api-reference/  (generated, gitignored)
```

Never edit anything under `docs/website/docs/api-reference/` — it is regenerated on every
build. To change the reference, change the `description:` in the Ruby schema and rerun
`bundle exec rake docs:schema`.

### Writing docs

- Hand-written pages live in `docs/website/docs/`; Spanish translations mirror them under
  `docs/website/i18n/es/docusaurus-plugin-content-docs/current/`.
- Shared values (URLs, rate limits, per-locale example translations) belong in
  `docs/website/src/constants.ts` — do not hard-code them on a page.
- Code examples belong in `docs/website/src/examples/index.ts`, rendered with
  `<ApiExample op="..." />`. The cURL tab is derived from the GraphQL document, so you never
  write the JSON escaping by hand. Set `ruby` or `node` to `null` where an SDK has no method
  rather than inventing one.
- After adding a UI string in a component, run `npm run write-translations -- --locale es` and
  translate the new key in `docs/website/i18n/es/code.json`.

## Reporting Issues

- Use [GitHub Issues](https://github.com/lporras/bibleql/issues) to report bugs or request features
- Include steps to reproduce for bug reports
- Check existing issues before opening a new one

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Include tests for new functionality
- Ensure all CI checks pass (linting, security, tests)
- Write a clear PR description explaining the "why" behind the change
- Reference any related issues (e.g., "Fixes #123")

## License

By contributing to BibleQL, you agree that your contributions will be licensed under the same terms as the project.
