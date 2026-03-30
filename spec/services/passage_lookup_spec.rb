require "rails_helper"

RSpec.describe PassageLookup do
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:book) { create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40) }

  before do
    create(:book_name, translation: translation, book: book, name: "Matthew")
    create(:verse, translation: translation, book: book, chapter: 28, verse_number: 18,
      text: "Jesus came to them and spoke to them, saying, \"All authority has been given to me in heaven and on earth.")
    create(:verse, translation: translation, book: book, chapter: 28, verse_number: 19,
      text: "Go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit,")
    create(:verse, translation: translation, book: book, chapter: 28, verse_number: 20,
      text: "teaching them to observe all things that I commanded you. Behold, I am with you always, even to the end of the age.\" Amen.")
  end

  describe "#call" do
    it "looks up a single verse via bible_ref" do
      result = described_class.new(translation_identifier: "eng-web", reference: "Matthew 28:18").call

      expect(result[:verses].size).to eq(1)
      expect(result[:translation_id]).to eq("eng-web")
      expect(result[:translation_name]).to eq("World English Bible")
    end

    it "looks up a verse range" do
      result = described_class.new(translation_identifier: "eng-web", reference: "Matthew 28:18-20").call

      expect(result[:verses].size).to eq(3)
      expect(result[:reference]).to eq("Matthew 28:18-20")
    end

    it "concatenates text from all verses" do
      result = described_class.new(translation_identifier: "eng-web", reference: "Matthew 28:18-20").call

      expect(result[:text]).to include("All authority")
      expect(result[:text]).to include("Go and make disciples")
      expect(result[:text]).to include("end of the age")
    end

    it "looks up a full chapter" do
      result = described_class.new(translation_identifier: "eng-web", reference: "Matthew 28").call

      expect(result[:verses].size).to eq(3)
    end

    context "with localized book names" do
      let(:spa_translation) { create(:translation, identifier: "spa-bes", name: "Biblia en Español", language: "spa") }

      before do
        create(:book_name, translation: spa_translation, book: book, name: "Mateo")
        create(:verse, translation: spa_translation, book: book, chapter: 28, verse_number: 18,
          text: "Jesús se acercó y les habló diciendo: «Toda autoridad me ha sido dada en el cielo y en la tierra.")
        create(:verse, translation: spa_translation, book: book, chapter: 28, verse_number: 19,
          text: "Id y haced discípulos a todas las naciones, bautizándolos en el nombre del Padre, del Hijo y del Espíritu Santo,")
        create(:verse, translation: spa_translation, book: book, chapter: 28, verse_number: 20,
          text: "enseñándoles a guardar todo lo que os he mandado. Y he aquí, yo estoy con vosotros todos los días, hasta el fin del mundo.» Amén.")
      end

      it "resolves Spanish book names" do
        result = described_class.new(translation_identifier: "spa-bes", reference: "Mateo 28:18-20").call

        expect(result[:verses].size).to eq(3)
        expect(result[:reference]).to include("Mateo")
        expect(result[:translation_id]).to eq("spa-bes")
        expect(result[:text]).to include("Toda autoridad")
      end
    end

    it "raises an error for unknown translations" do
      expect {
        described_class.new(translation_identifier: "unknown", reference: "John 3:16").call
      }.to raise_error(PassageLookup::NotFoundError, /Translation/)
    end

    it "raises an error for unknown book names" do
      expect {
        described_class.new(translation_identifier: "eng-web", reference: "FakeBook 1:1").call
      }.to raise_error(PassageLookup::NotFoundError, /Book/)
    end
  end
end
