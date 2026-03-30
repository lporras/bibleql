require "rails_helper"

RSpec.describe BookName, type: :model do
  describe "validations" do
    subject { build(:book_name) }

    it { is_expected.to be_valid }

    it "requires name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires unique book per translation" do
      existing = create(:book_name)
      subject.translation = existing.translation
      subject.book = existing.book

      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to translation" do
      book_name = create(:book_name)
      expect(book_name.translation).to be_a(Translation)
    end

    it "belongs to book" do
      book_name = create(:book_name)
      expect(book_name.book).to be_a(Book)
    end
  end
end
