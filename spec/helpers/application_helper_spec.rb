# frozen_string_literal: true

require "rails_helper"

# infer_spec_type_from_file_location! is commented out in rails_helper, so the
# helper type is declared explicitly.
RSpec.describe ApplicationHelper, type: :helper do
  describe "#docs_url" do
    # A developer's local .env may set DOCS_URL to point the links at `bin/docs`,
    # so these examples pin the environment rather than inheriting it.
    before { stub_const("ENV", ENV.to_h.except("DOCS_URL")) }

    it "returns the documentation root with no argument" do
      expect(helper.docs_url).to eq("https://docs.bibleql.org")
    end

    it "appends a path" do
      expect(helper.docs_url("getting-started/quickstart"))
        .to eq("https://docs.bibleql.org/getting-started/quickstart")
    end

    it "does not double the separator for a leading slash" do
      expect(helper.docs_url("/api-reference")).to eq("https://docs.bibleql.org/api-reference")
    end

    context "when DOCS_URL is set" do
      before { stub_const("ENV", ENV.to_h.merge("DOCS_URL" => "http://localhost:3001/")) }

      it "uses it and strips a trailing slash" do
        expect(helper.docs_url).to eq("http://localhost:3001")
        expect(helper.docs_url("api-reference")).to eq("http://localhost:3001/api-reference")
      end
    end
  end

  describe "#approximate_count" do
    it "rounds tens down" do
      # Production currently reports 49 translations and 31 languages.
      expect(helper.approximate_count(49)).to eq("40+")
      expect(helper.approximate_count(31)).to eq("30+")
      expect(helper.approximate_count(40)).to eq("40+")
    end

    it "reports small counts exactly, without a misleading plus" do
      expect(helper.approximate_count(0)).to eq("0")
      expect(helper.approximate_count(7)).to eq("7")
    end

    it "abbreviates thousands" do
      expect(helper.approximate_count(1_000)).to eq("1K+")
      expect(helper.approximate_count(12_500)).to eq("12K+")
    end

    it "abbreviates millions to one decimal place" do
      # Production currently reports 1,360,301 verses.
      expect(helper.approximate_count(1_360_301)).to eq("1.3M+")
      expect(helper.approximate_count(2_000_000)).to eq("2M+")
      expect(helper.approximate_count(2_050_000)).to eq("2M+")
      expect(helper.approximate_count(2_150_000)).to eq("2.1M+")
    end

    it "always rounds down, so the claim stays true as the corpus grows" do
      [ 49, 99, 1_999, 1_360_301 ].each do |count|
        digits = helper.approximate_count(count).delete("+KM.").to_i
        expect(digits).to be > 0
        expect(helper.approximate_count(count)).to end_with("+")
      end
    end

    it "handles nil and negatives without raising" do
      expect(helper.approximate_count(nil)).to eq("0")
      expect(helper.approximate_count(-5)).to eq("0")
    end
  end
end
