require "rails_helper"

RSpec.describe ConcordanceLookup do
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:psalms) { create(:book, book_id: "PSA", name: "Psalms", testament: "OT", position: 19) }
  let(:matthew) { create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40) }

  def index!(translation)
    ConcordanceIndexer.new(translation).call
  end

  describe "canonical ordering and aggregates" do
    let(:translation) { create(:translation) }

    before do
      # Inserted out of canonical order on purpose: Psalms, then Matthew, then Genesis.
      create(:verse, translation: translation, book: psalms, chapter: 23, verse_number: 1,
        text: "The Lord is my shepherd, I shall not want.")
      create(:verse, translation: translation, book: matthew, chapter: 5, verse_number: 3,
        text: "Blessed are the poor in spirit, for theirs is the shepherd's kingdom.")
      create(:verse, translation: translation, book: genesis, chapter: 48, verse_number: 15,
        text: "The God who has been my shepherd all my life to this day.")
      index!(translation)
    end

    it "returns results in canonical order regardless of insertion order" do
      result = described_class.new(translation: translation, word: "shepherd").call

      book_ids = result.edges.map { |edge| edge.node.verse.book.book_id }
      expect(book_ids).to eq(%w[GEN PSA MAT])
    end

    it "reports the correct total_count and per-book/testament aggregates" do
      result = described_class.new(translation: translation, word: "shepherd").call

      expect(result.total_count).to eq(3)
      expect(result.entry.verse_count).to eq(3)
      expect(result.entry.occurrences_by_testament.old).to eq(2)
      expect(result.entry.occurrences_by_testament.new).to eq(1)
      expect(result.entry.occurrences_by_book.map(&:book_id)).to eq(%w[GEN PSA MAT])
    end

    it "includes KWIC context with <mark> highlighting" do
      result = described_class.new(translation: translation, word: "shepherd").call

      expect(result.edges.first.node.context).to include("<mark>")
    end
  end

  describe "word not found" do
    let(:translation) { create(:translation) }

    before do
      create(:verse, translation: translation, book: genesis, text: "In the beginning")
      index!(translation)
    end

    it "returns zero results without raising" do
      result = described_class.new(translation: translation, word: "nonexistentword").call

      expect(result.total_count).to eq(0)
      expect(result.edges).to be_empty
    end
  end

  describe "accents and case" do
    let(:translation) { create(:translation, identifier: "spa-rv1909", language: "spa") }

    before do
      create(:verse, translation: translation, book: genesis, text: "Grande es tu misericordia.")
      index!(translation)
    end

    it "matches regardless of accents or case" do
      %w[Misericordia misericordia MISERICORDIA].each do |word|
        result = described_class.new(translation: translation, word: word).call
        expect(result.total_count).to eq(1)
      end
    end
  end

  describe "stemming" do
    context "when the translation has a stemming dictionary" do
      let(:translation) { create(:translation, identifier: "spa-rv1909", language: "spa") }

      before do
        create(:verse, translation: translation, book: genesis, text: "Dios es misericordioso.")
        index!(translation)
      end

      it "matches other forms of the word via the dictionary" do
        result = described_class.new(translation: translation, word: "misericordia").call
        expect(result.total_count).to eq(1)
      end
    end

    context "when the translation has no stemming dictionary" do
      let(:translation) { create(:translation, identifier: "xyz-test", language: "xyz") }

      before do
        create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1, text: "running fast")
        create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 2, text: "run home")
        index!(translation)
      end

      it "only matches the exact form" do
        result = described_class.new(translation: translation, word: "running").call
        expect(result.total_count).to eq(1)
      end
    end
  end

  describe "filters" do
    let(:translation) { create(:translation) }

    before do
      create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1, text: "grace and truth")
      create(:verse, translation: translation, book: matthew, chapter: 1, verse_number: 14, text: "full of grace")
      index!(translation)
    end

    it "filters by book" do
      result = described_class.new(translation: translation, word: "grace", book: genesis).call
      expect(result.total_count).to eq(1)
      expect(result.edges.first.node.verse.book.book_id).to eq("GEN")
    end

    it "filters by testament" do
      result = described_class.new(translation: translation, word: "grace", testament: "NT").call
      expect(result.total_count).to eq(1)
      expect(result.edges.first.node.verse.book.book_id).to eq("MAT")
    end
  end

  describe "pagination" do
    let(:translation) { create(:translation) }

    before do
      (1..5).each do |n|
        create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: n, text: "faith and hope")
      end
      index!(translation)
    end

    it "covers the full set across pages with no overlap" do
      page1 = described_class.new(translation: translation, word: "faith").call(first: 2)
      expect(page1.edges.size).to eq(2)
      expect(page1.has_next_page).to be true

      page2 = described_class.new(translation: translation, word: "faith").call(first: 2, after: page1.end_cursor)
      expect(page2.edges.size).to eq(2)
      expect(page2.has_next_page).to be true

      page3 = described_class.new(translation: translation, word: "faith").call(first: 2, after: page2.end_cursor)
      expect(page3.edges.size).to eq(1)
      expect(page3.has_next_page).to be false

      all_verse_numbers = (page1.edges + page2.edges + page3.edges).map { |e| e.node.verse.verse_number }
      expect(all_verse_numbers).to eq([ 1, 2, 3, 4, 5 ])
      expect(all_verse_numbers.uniq).to eq(all_verse_numbers)
    end

    it "raises InvalidCursorError for a malformed cursor" do
      expect {
        described_class.new(translation: translation, word: "faith").call(after: "not-a-valid-cursor!!")
      }.to raise_error(ConcordanceLookup::InvalidCursorError)
    end
  end

  describe "malicious input" do
    let(:translation) { create(:translation) }

    before do
      create(:verse, translation: translation, book: genesis, text: "In the beginning")
      index!(translation)
    end

    it "does not execute injected SQL and returns no matches" do
      malicious = "'; DROP TABLE verses; --"

      expect {
        result = described_class.new(translation: translation, word: malicious).call
        expect(result.total_count).to eq(0)
      }.not_to raise_error

      expect(ActiveRecord::Base.connection.table_exists?(:verses)).to be true
    end
  end

  describe "#entry" do
    let(:translation) { create(:translation, identifier: "spa-rv1909", language: "spa") }

    before do
      create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1,
        text: "amor, amores y amoroso")
      index!(translation)
    end

    it "returns real surface forms, not the raw stem" do
      result = described_class.new(translation: translation, word: "amor").call

      expect(result.entry.surface_forms).to include("amor", "amores", "amoroso")
    end

    it "counts total_occurrences separately from verse_count when a word repeats in one verse" do
      result = described_class.new(translation: translation, word: "amor").call

      expect(result.entry.verse_count).to eq(1)
      expect(result.entry.total_occurrences).to eq(3)
    end
  end
end
