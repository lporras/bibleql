# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @translations_count = Translation.count
    @verses_count = Verse.count
    @languages_count = Translation.distinct.count(:language)
  end
end
