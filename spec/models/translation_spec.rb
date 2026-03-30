require "rails_helper"

RSpec.describe Translation, type: :model do
  describe "validations" do
    subject { build(:translation) }

    it { is_expected.to be_valid }

    it "requires identifier" do
      subject.identifier = nil
      expect(subject).not_to be_valid
    end

    it "requires unique identifier" do
      create(:translation, identifier: "eng-web")
      expect(subject).not_to be_valid
    end

    it "requires name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires language" do
      subject.language = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "has many verses" do
      translation = create(:translation)
      book = create(:book)
      create(:verse, translation: translation, book: book)

      expect(translation.verses.count).to eq(1)
    end

    it "has many book_names" do
      translation = create(:translation)
      book = create(:book)
      create(:book_name, translation: translation, book: book)

      expect(translation.book_names.count).to eq(1)
    end
  end
end
