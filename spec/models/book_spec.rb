require "rails_helper"

RSpec.describe Book, type: :model do
  describe "validations" do
    subject { build(:book) }

    it { is_expected.to be_valid }

    it "requires book_id" do
      subject.book_id = nil
      expect(subject).not_to be_valid
    end

    it "requires unique book_id" do
      create(:book, book_id: "GEN", position: 1)
      subject.position = 2
      expect(subject).not_to be_valid
    end

    it "requires name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires testament" do
      subject.testament = nil
      expect(subject).not_to be_valid
    end

    it "requires testament to be OT or NT" do
      subject.testament = "INVALID"
      expect(subject).not_to be_valid
    end

    it "requires position" do
      subject.position = nil
      expect(subject).not_to be_valid
    end

    it "requires unique position" do
      create(:book, book_id: "GEN", position: 1)
      expect(subject).not_to be_valid
    end
  end
end
