require "rails_helper"

RSpec.describe TextSearchConfigResolver do
  after { described_class.reset_installed_configs_cache! }

  describe ".for" do
    it "maps a known language to its PostgreSQL text search configuration" do
      expect(described_class.for("spa")).to eq("spanish")
      expect(described_class.for("eng")).to eq("english")
    end

    it "falls back to simple for an unmapped language" do
      expect(described_class.for("xyz")).to eq("simple")
    end

    it "falls back to simple when the mapped dictionary isn't installed" do
      allow(described_class).to receive(:installed_configs).and_return(Set.new(%w[simple english]))

      expect(described_class.for("spa")).to eq("simple")
    end

    it "accepts a symbol or nil without raising" do
      expect(described_class.for(:eng)).to eq("english")
      expect(described_class.for(nil)).to eq("simple")
    end
  end

  describe ".stemming?" do
    it "is true when the language resolves to a real dictionary" do
      expect(described_class.stemming?("spa")).to be true
    end

    it "is false when the language falls back to simple" do
      expect(described_class.stemming?("xyz")).to be false
    end

    it "is false when the mapped dictionary isn't installed" do
      allow(described_class).to receive(:installed_configs).and_return(Set.new(%w[simple]))

      expect(described_class.stemming?("spa")).to be false
    end
  end

  describe ".installed_configs" do
    it "reflects PostgreSQL's actual pg_ts_config catalog" do
      expect(described_class.installed_configs).to include("simple", "english")
    end
  end
end
