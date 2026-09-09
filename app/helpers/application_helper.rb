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
    root = ENV.fetch("DOCS_URL", DEFAULT_DOCS_URL).delete_suffix("/")

    path.present? ? "#{root}/#{path.delete_prefix("/")}" : root
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
