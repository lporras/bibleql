# frozen_string_literal: true

class HomeController < ApplicationController
  # No database access on purpose. The corpus figures shown here are static and
  # approximate — see ApplicationHelper::SITE_METRICS. Counting 1.3M+ verses on
  # every request made this page take 9-46 seconds in production.
  def index
    translations = helpers.site_metric(:translations)
    languages = helpers.site_metric(:languages)

    set_meta_tags(
      title: "Free GraphQL Bible API",
      description: "BibleQL is a free, open-source Bible API built with GraphQL. " \
                   "Query verses, passages, and chapters across #{translations} " \
                   "translations in #{languages} languages.",
      og: {
        title: "BibleQL — Free GraphQL Bible API",
        description: "Query Bible verses and passages across #{translations} " \
                     "translations in #{languages} languages. Free and open source."
      }
    )
  end
end
