require "rails_helper"

RSpec.describe TranslationMetadataGenerator do
  let(:readme_path) { Rails.root.join("spec/fixtures/open_bibles_readme.md") }
  let(:output_path) { Rails.root.join("tmp/translations_spec.yml") }

  subject(:generator) { described_class.new(readme_path: readme_path, output_path: output_path) }

  after { FileUtils.rm_f(output_path) }

  describe "#parse" do
    subject(:metadata) { generator.parse }

    it "keys each row by the identifier, dropping the format suffix" do
      expect(metadata.keys).to contain_exactly(
        "bul-bulgarian", "cze-bkr", "eng-gb-webbe", "eng-web", "heb-leningrad", "spa-bes", "xxx-mystery"
      )
    end

    it "sorts entries by identifier so regenerating produces a stable diff" do
      expect(metadata.keys).to eq(metadata.keys.sort)
    end

    it "maps the Version, Abbrev and Language columns" do
      expect(metadata["eng-gb-webbe"]).to eq(
        "name" => "World English Bible, British Edition",
        "abbrev" => "WEBBE",
        "language_name" => "English (UK)",
        "note" => "Public Domain"
      )
    end

    it "records a blank abbreviation as nil rather than an empty string" do
      expect(metadata["bul-bulgarian"]["abbrev"]).to be_nil
    end

    it "preserves non-ASCII names" do
      expect(metadata["cze-bkr"]["name"]).to eq("Bible kralická")
    end

    it "strips markdown reference-link syntax from licenses" do
      expect(metadata["spa-bes"]["note"]).to eq("CC BY 4.0")
    end

    it "resolves a deferred license through CUSTOM_LICENSES" do
      expect(metadata["heb-leningrad"]["note"]).to eq(described_class::CUSTOM_LICENSES["heb-leningrad"])
    end

    it "flags a deferred license it has no entry for instead of inventing one" do
      expect(metadata["xxx-mystery"]["note"]).to start_with("TODO")
    end

    it "ignores table-shaped lines outside the translation list" do
      expect(metadata.keys).not_to include("not-a-bible", "not-a-bible.txt")
    end
  end

  describe "#call" do
    it "returns the parsed metadata" do
      expect(generator.call).to eq(generator.parse)
    end

    it "writes YAML that round-trips to the same data" do
      metadata = generator.call

      expect(YAML.load_file(output_path)).to eq(metadata)
    end

    it "writes the regeneration instructions as a leading comment" do
      generator.call

      expect(output_path.read).to start_with("# Translation metadata sourced from")
      expect(output_path.read).to include("rake bible:generate_metadata")
    end
  end

  describe "the checked-in config/translations.yml" do
    it "matches what the generator produces from the current README" do
      skip "open-bibles submodule not checked out" unless File.exist?(described_class::README_PATH)

      expect(described_class.new(output_path: output_path).parse).to eq(TranslationMetadata::ALL)
    end
  end
end
