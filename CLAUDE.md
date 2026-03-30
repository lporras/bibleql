# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BibleQL is a GraphQL API for querying Bible verses and passages across multiple translations. Built with Rails 8.1, Ruby 4.0, PostgreSQL, and RSpec for testing. The project is in its early stages (initial scaffold).

### Goals

- Provide a GraphQL endpoint to query Bible verses and passages
- Support multiple Bible translations
- Enable flexible queries by book, chapter, verse, and passage ranges

## Common Commands

```bash
# Setup
bin/rails db:create db:migrate

# Run the server
bin/rails server

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/path/to/file_spec.rb

# Run a specific test by line number
bundle exec rspec spec/path/to/file_spec.rb:42

# Linting
bin/rubocop

# Security audit
bin/brakeman
bundle exec bundler-audit

# Rails console
bin/rails console

# Database
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:test:prepare
```

## Architecture

- **Framework**: Rails 8.1 (API + standard views via Hotwire/Turbo/Stimulus)
- **Database**: PostgreSQL with Solid Cache, Solid Queue, and Solid Cable for production
- **Asset Pipeline**: Propshaft with import maps (no Node.js bundler)
- **Testing**: RSpec (not Minitest) with Capybara/Selenium for system tests
- **Deployment**: Docker + Kamal
- **Linting**: rubocop-rails-omakase style guide
