# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @translations_count = Translation.count
    @verses_count = Verse.count
    @languages_count = Translation.distinct.count(:language)

    set_meta_tags(
      title: "Free GraphQL Bible API",
      description: "BibleQL is a free, open-source Bible API built with GraphQL. " \
                   "Query verses, passages, and chapters across #{@translations_count} " \
                   "translations in #{@languages_count} languages.",
      og: {
        title: "BibleQL — Free GraphQL Bible API",
        description: "Query Bible verses and passages across #{@translations_count} " \
                     "translations in #{@languages_count} languages. Free and open source."
      }
    )
  end
end
