require "rails_helper"

RSpec.describe TranslationMetadataSync do
  # How translations looked before config/translations.yml existed: identifier as
  # the display name, hardcoded Public Domain note, no abbrev or language name.
  def legacy_translation(identifier)
    Translation.create!(identifier: identifier, name: identifier, language: identifier.split("-").first, note: "Public Domain")
  end

  describe ".call" do
    it "assigns the curated name, abbreviation, language name and license" do
      translation = legacy_translation("eng-web")

      described_class.call

      expect(translation.reload).to have_attributes(
        name: "World English Bible",
        abbrev: "WEB",
        language_name: "English",
        note: "Public Domain"
      )
    end

    it "corrects a license that was wrongly recorded as public domain" do
      translation = legacy_translation("spa-bes")

      described_class.call

      expect(translation.reload.note).to eq("CC BY 4.0")
    end

    it "leaves the language code untouched" do
      translation = legacy_translation("eng-gb-webbe")

      described_class.call

      expect(translation.reload).to have_attributes(language: "eng", language_name: "English (UK)")
    end

    it "reports what changed" do
      legacy_translation("eng-web")

      result = described_class.call

      expect(result.updated.size).to eq(1)
      expect(result.updated.first.changes["name"]).to eq([ "eng-web", "World English Bible" ])
    end

    it "is a no-op on a second run" do
      legacy_translation("eng-web")
      described_class.call

      result = described_class.call

      expect(result.updated).to be_empty
      expect(result.unchanged.map(&:identifier)).to eq([ "eng-web" ])
    end

    it "reports translations with no metadata and leaves them untouched" do
      translation = legacy_translation("xxx-unknown")

      result = described_class.call

      expect(result.missing.map(&:identifier)).to eq([ "xxx-unknown" ])
      expect(translation.reload.name).to eq("xxx-unknown")
    end

    it "only touches the given identifier when one is passed" do
      eng = legacy_translation("eng-web")
      spa = legacy_translation("spa-bes")

      described_class.call(identifier: "eng-web")

      expect(eng.reload.name).to eq("World English Bible")
      expect(spa.reload.name).to eq("spa-bes")
    end

    it "persists nothing on a dry run" do
      translation = legacy_translation("eng-web")

      result = described_class.call(dry_run: true)

      expect(result.updated.size).to eq(1)
      expect(translation.reload.name).to eq("eng-web")
    end
  end
end
