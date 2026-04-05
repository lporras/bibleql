# frozen_string_literal: true

class VerseOfTheDayLookup
  VERSES = YAML.load_file(Rails.root.join("config", "verse_of_the_day.yml")).freeze

  def initialize(translation_identifier:, date:)
    @translation_identifier = translation_identifier
    @date = date
  end

  def call
    index = @date.yday % VERSES.size
    reference = VERSES[index]
    PassageLookup.new(translation_identifier: @translation_identifier, reference: reference).call
  end
end
