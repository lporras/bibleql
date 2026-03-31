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
3. Add tests in `spec/graphql/` or `spec/requests/`
4. Update the playground default query if useful (`app/views/playground/show.html.erb`)

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
