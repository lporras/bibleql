require "rails_helper"

RSpec.describe TranslationMetadata do
  describe ".for" do
    it "returns the curated metadata for a known identifier" do
      expect(described_class.for("eng-web")).to eq(
        "name" => "World English Bible",
        "abbrev" => "WEB",
        "language_name" => "English",
        "note" => "Public Domain"
      )
    end

    it "resolves markdown license links to plain text" do
      expect(described_class.for("spa-bes")["note"]).to eq("CC BY 4.0")
    end

    it "leaves a blank abbreviation as nil rather than an empty string" do
      expect(described_class.for("heb-leningrad")["abbrev"]).to be_nil
    end

    it "returns nil for an unknown identifier" do
      expect(described_class.for("xxx-unknown")).to be_nil
    end
  end

  describe "coverage of the open-bibles submodule" do
    it "has an entry for every translation file on disk" do
      identifiers = Dir.glob(Rails.root.join("db/open-bibles/*.xml")).map do |path|
        File.basename(path).sub(/\.(usfx|osis|zefania)\.xml\z/i, "")
      end
      skip "open-bibles submodule not checked out" if identifiers.empty?

      expect(identifiers - described_class.identifiers).to be_empty
    end

    it "has no unresolved license placeholders" do
      unresolved = described_class::ALL.select { |_identifier, data| data["note"].to_s.start_with?("TODO") }
      expect(unresolved.keys).to be_empty
    end
  end
end
