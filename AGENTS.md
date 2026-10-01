# AGENTS.md for BibleQL Repository

## Setup and Initialization
- Clone repo with submodules: `git clone --recurse-submodules https://github.com/lporras/bibleql.git`
- If submodules missing after clone: `git submodule update --init`
- Install Ruby gems: `bundle install`
- Create and migrate the database: `bin/rails db:create db:migrate`
- Import Bible translations *after* migration:
  - All open-bibles: `bundle exec rake bible:import`
  - Single translation: `bundle exec rake "bible:import_one[eng-web]"
- Import Bible List translations *only after* `bible:import` run for localized book names:
  - List status: `bundle exec rake biblelist:list`
  - Import all: `bundle exec rake biblelist:import`
  - Import single: `bundle exec rake "biblelist:import_one[eng-niv]"`
- Holy-Bible-XML-Format translations are not submodules; download files individually into `db/holy-bible-xml/` (gitignored)
  - Import single by identifier: `bundle exec rake "holy_bible_xml:import_one[ara-svd]"`
  - Import all downloaded files: `bundle exec rake holy_bible_xml:import`

## Environment & Jobs
- `.env` controls optional environment variables. Use `.env.example` as a template.
- Background jobs run on Solid Queue.
  - In development: start with `bin/jobs` or via `bin/dev` which also runs server and watcher.
  - In production: set `SOLID_QUEUE_IN_PUMA=true` for worker in Puma.

## Running
- Serve API alone: `bin/rails server`
- Start full dev stack (server, Tailwind watcher, jobs, docs site): `bin/dev`

## API Authentication
- All GraphQL POST requests require API key in `Authorization: Bearer <token>` header.
- API keys have environment-aware prefixes: `bql_live_` (prod), `bql_test_` (dev/test).
- Manage API keys with rake tasks or via admin panel:
  - Create: `bundle exec rake "api_keys:create[name,email,environment]"`
  - List: `bundle exec rake api_keys:list`
  - Revoke: `bundle exec rake "api_keys:revoke[prefix]"`

## Rate Limits
- 100 GraphQL requests per minute per IP
- 1,000 GraphQL requests per day per API key
- 5 API key requests per hour per IP

## Testing
- Run full test suite: `bundle exec rspec`
- Run single test file: `bundle exec rspec spec/path/to/file_spec.rb`
- Run specific test line: `bundle exec rspec spec/path/to/file_spec.rb:42`

## Lint & Security
- Run RuboCop lint: `bin/rubocop`
- Run security audits:
  - Brakeman: `bin/brakeman`
  - Bundler Audit: `bundle exec bundler-audit`

## Concordance Index
- Build concordance index (required for concordance queries): `bundle exec rake concordance:index`
- Can build index for a single translation: `bundle exec rake "concordance:index[identifier]"`

## Offline Packages
- Only redistributable translations (flagged true in licensing gate) export offline packages.
- Requires Cloudflare R2 credentials and `OFFLINE_*` env vars.
- Export offline packages asynchronously via background jobs.

## Deployment
- Uses Docker + Kamal
- Production requires `SOLID_QUEUE_IN_PUMA=true` in environment
- `OFFLINE_R2_*` variables must be set for offline package export in prod

## Key Quirks
- Always import `bible:import` before `biblelist:import` or `holy_bible_xml:import` for book names fallback.
- Holy-Bible-XML-Format files are large, not submodules, must be downloaded individually.
- Concordance and offline package exports are asynchronous; run workers.
- GraphQL API has max complexity 300 and max depth 15.
- Admin panel is at `/admin` (Devise authentication).
- Client SDKs exist for Ruby and Node.js; check README links for usage.

## Important Files & Configs
- Main migration and database config: `bin/rails db:migrate`
- COntinuous Integration runs Brakeman, Bundler Audit, RuboCop, and RSpec.
- Open-bibles submodule at `db/open-bibles/`
- Bible List XML files at `db/biblelist/`
- Holy Bible XML files in `.gitignore` folder `db/holy-bible-xml/`
- Translation metadata in `config/translations.yml`

## References
- `README.md` contains detailed lists of commands and architectural overview.
- `CLAUDE.md` includes expanded command references and architecture summary.
- Documentation site: https://docs.bibleql.org
