module ApplicationHelper
  DEFAULT_DOCS_URL = "https://docs.bibleql.org"

  # Public documentation site. It is a static Docusaurus build deployed to GitHub
  # Pages (see .github/workflows/docs.yml) — Rails only links to it, never serves
  # it.
  #
  # Set DOCS_URL (in .env, say) to point the links at a local `bin/docs` server.
  # Read per call rather than frozen into a constant at boot, so a .env change
  # takes effect on reload and specs can stub it.
  def docs_url(path = nil)
    # presence, not fetch's default: an empty DOCS_URL (as `DOCS_URL= rails s`
    # leaves it) should fall back rather than produce a root-relative link.
    root = ENV["DOCS_URL"].presence&.delete_suffix("/") || DEFAULT_DOCS_URL

    path.present? ? "#{root}/#{path.delete_prefix("/")}" : root
  end

  # Corpus size as shown on the landing page.
  #
  # Deliberately static: the page renders these through approximate_count as
  # "40+" / "30+" / "1.3M+", so querying for them bought no accuracy — and
  # COUNT(*) over 1.3M+ verses was slow enough in production to take the page
  # down. A landing page should not touch the database.
  #
  # To refresh, read the real figures and paste them in — rounding is automatic,
  # so 52 becomes "50+" with no other change:
  #
  #   bin/rails runner 'puts Translation.count, Translation.distinct.count(:language), Verse.count'
  #
  # Or, without a console, query the live API:
  #
  #   { translations { identifier } languages { code } }
  SITE_METRICS = {
    translations: 49,
    languages: 31,
    verses: 1_360_301
  }.freeze

  def site_metric(key)
    approximate_count(SITE_METRICS.fetch(key))
  end

  # Round a count down to a friendly approximation for marketing copy: 49 => "40+".
  #
  # Always rounds DOWN so the claim stays true as the corpus grows — a stale
  # "40+" is still accurate at 49 translations, whereas rounding up would
  # overstate. Exact figures belong in the API (`translations`, `languages`), not
  # in prose that nobody remembers to update.
  def approximate_count(count)
    count = count.to_i

    case count
    when ...0     then "0"
    when 0...10   then count.to_s
    when 10...1_000 then "#{count / 10 * 10}+"
    when 1_000...1_000_000 then "#{count / 1_000}K+"
    else
      # Floor to one decimal place of millions, then drop a trailing ".0".
      millions = (count / 100_000) / 10.0
      "#{millions == millions.floor ? millions.to_i : millions}M+"
    end
  end
end
