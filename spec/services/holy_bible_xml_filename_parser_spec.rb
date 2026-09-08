require "rails_helper"

RSpec.describe HolyBibleXmlFilenameParser do
  def call(filename) = described_class.call(filename)

  it "derives a plain language-only filename" do
    result = call("AfrikaansBible.xml")

    expect(result).to have_attributes(
      identifier: "afr",
      language_code: "afr",
      language_name: "Afrikaans",
      variant: "",
      abbrev: nil
    )
  end

  it "treats an all-caps variant as an abbreviation" do
    result = call("ArabicSVDBible.xml")

    expect(result).to have_attributes(
      identifier: "ara-svd",
      language_code: "ara",
      language_name: "Arabic",
      variant: "svd",
      abbrev: "SVD"
    )
  end

  it "treats a numeric variant as a plain variant, not an abbreviation" do
    result = call("Afrikaans1983Bible.xml")

    expect(result).to have_attributes(
      identifier: "afr-1983",
      language_code: "afr",
      variant: "1983",
      abbrev: nil
    )
  end

  it "keeps a run of capitals together instead of splitting every letter" do
    result = call("AmharicDawroDFBEBible.xml")

    expect(result).to have_attributes(
      identifier: "amh-dawro-dfbe",
      language_code: "amh",
      variant: "dawro-dfbe",
      abbrev: nil
    )
  end

  it "splits a multi-word variant into hyphenated lowercase words" do
    result = call("BalochiSoutherenLatinBible.xml")

    expect(result).to have_attributes(
      identifier: "bal-southeren-latin",
      language_code: "bal",
      variant: "southeren-latin"
    )
  end

  it "falls back to a lowercased slug for a language not in config/language_codes.yml" do
    result = call("ZarmaBible.xml")

    expect(result).to have_attributes(
      identifier: "zarma",
      language_code: "zarma",
      language_name: "Zarma",
      variant: ""
    )
  end

  it "accepts a full path and only looks at the basename" do
    result = call("db/holy-bible-xml/Afrikaans1983Bible.xml")

    expect(result.identifier).to eq("afr-1983")
  end

  it "is case-insensitive about the Bible.xml suffix" do
    result = call("Afrikaans1983BIBLE.XML")

    expect(result.identifier).to eq("afr-1983")
  end
end
