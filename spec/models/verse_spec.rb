require "rails_helper"

RSpec.describe Verse, type: :model do
  describe "validations" do
    subject { build(:verse) }

    it { is_expected.to be_valid }

    it "requires chapter" do
      subject.chapter = nil
      expect(subject).not_to be_valid
    end

    it "requires verse_number" do
      subject.verse_number = nil
      expect(subject).not_to be_valid
    end

    it "requires text" do
      subject.text = nil
      expect(subject).not_to be_valid
    end

    it "requires unique verse_number scoped to translation, book, and chapter" do
      existing = create(:verse)
      subject.translation = existing.translation
      subject.book = existing.book
      subject.chapter = existing.chapter
      subject.verse_number = existing.verse_number

      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to translation" do
      verse = create(:verse)
      expect(verse.translation).to be_a(Translation)
    end

    it "belongs to book" do
      verse = create(:verse)
      expect(verse.book).to be_a(Book)
    end
  end
end
