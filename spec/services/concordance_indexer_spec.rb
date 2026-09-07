require "rails_helper"

RSpec.describe ConcordanceIndexer do
  let(:book) { create(:book) }

  def word_index_row(translation, lemma)
    ConcordanceWordIndex.find_by(translation: translation, lemma: lemma)
  end

  describe "#call" do
    it "assigns the spanish config and enables stemming for a spa-* translation" do
      translation = create(:translation, identifier: "spa-rv1909", language: "spa")
      create(:verse, translation: translation, book: book, text: "amor y misericordia")

      described_class.new(translation).call

      expect(translation.reload.text_search_config).to eq("spanish")
      expect(translation.has_stemming).to be true
    end

    it "assigns the english config and enables stemming for an eng-* translation" do
      translation = create(:translation, identifier: "eng-web", language: "eng")
      create(:verse, translation: translation, book: book, text: "love and mercy")

      described_class.new(translation).call

      expect(translation.reload.text_search_config).to eq("english")
      expect(translation.has_stemming).to be true
    end

    it "falls back to simple with stemming disabled for a language without a dictionary" do
      translation = create(:translation, identifier: "xyz-test", language: "xyz")
      create(:verse, translation: translation, book: book, text: "some words")

      described_class.new(translation).call

      expect(translation.reload.text_search_config).to eq("simple")
      expect(translation.has_stemming).to be false
    end

    it "sets concordance_indexed_at" do
      translation = create(:translation)
      create(:verse, translation: translation, book: book)

      expect { described_class.new(translation).call }
        .to change { translation.reload.concordance_indexed_at }.from(nil)
    end

    it "populates verses.text_search using to_tsvector" do
      translation = create(:translation)
      verse = create(:verse, translation: translation, book: book, text: "grace and mercy")

      described_class.new(translation).call

      expect(verse.reload.text_search).to be_present
    end

    it "populates concordance_word_index with verse and occurrence counts" do
      translation = create(:translation)
      create(:verse, translation: translation, book: book, chapter: 1, verse_number: 1,
        text: "mercy is mercy")
      create(:verse, translation: translation, book: book, chapter: 1, verse_number: 2,
        text: "grace and truth")

      described_class.new(translation).call

      row = word_index_row(translation, "merci")
      expect(row).not_to be_nil
      expect(row.verse_count).to eq(1)
      expect(row.total_occurrences).to eq(2)
    end

    it "is idempotent" do
      translation = create(:translation)
      create(:verse, translation: translation, book: book, text: "mercy is mercy")

      described_class.new(translation).call
      first_count = ConcordanceWordIndex.where(translation: translation).count
      described_class.new(translation).call
      second_count = ConcordanceWordIndex.where(translation: translation).count

      expect(second_count).to eq(first_count)
      expect(ConcordanceWordIndex.where(translation: translation, lemma: "merci").count).to eq(1)
    end

    it "scopes the word index to the indexed translation only" do
      other_translation = create(:translation, identifier: "spa-rv1909", language: "spa")
      translation = create(:translation)
      create(:verse, translation: other_translation, book: book, text: "misericordia")
      create(:verse, translation: translation, book: book, text: "mercy")

      described_class.new(translation).call

      expect(ConcordanceWordIndex.where(translation: other_translation)).to be_empty
    end
  end
end
