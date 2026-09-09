# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @translations_count = Translation.count
    @verses_count = Verse.count
    @languages_count = Translation.distinct.count(:language)

    # Approximated so the copy does not go stale every time a translation is
    # added. See ApplicationHelper#approximate_count.
    translations = helpers.approximate_count(@translations_count)
    languages = helpers.approximate_count(@languages_count)

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
