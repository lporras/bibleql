require "rails_helper"

RSpec.describe ConcordanceWordIndexLookup do
  let(:book) { create(:book) }
  let(:translation) { create(:translation) }

  before do
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 1,
      text: "grace and mercy and truth")
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 2,
      text: "mercy triumphs over judgment")
    ConcordanceIndexer.new(translation).call
  end

  describe "#call" do
    it "returns words in alphabetical order" do
      lemmas = described_class.new(translation: translation).call.map(&:lemma)

      expect(lemmas).to eq(lemmas.sort)
    end

    it "filters by prefix case-insensitively" do
      lemmas = described_class.new(translation: translation, prefix: "MER").call.map(&:lemma)

      expect(lemmas).to all(start_with("mer"))
      expect(lemmas).not_to be_empty
    end

    it "excludes words below min_occurrences" do
      lemmas = described_class.new(translation: translation, min_occurrences: 2).call.map(&:lemma)

      expect(lemmas).to eq([ "merci" ])
    end

    it "clamps first to MAX_PAGE_SIZE" do
      result = described_class.new(translation: translation).call(first: 10_000)

      expect(result.size).to be <= described_class::MAX_PAGE_SIZE
    end

    it "scopes to the requested translation only" do
      other_translation = create(:translation, identifier: "spa-rv1909", language: "spa")
      create(:verse, translation: other_translation, book: book, text: "misericordia")
      ConcordanceIndexer.new(other_translation).call

      lemmas = described_class.new(translation: translation).call.map(&:lemma)

      expect(lemmas).not_to include("misericordi")
    end
  end
end
