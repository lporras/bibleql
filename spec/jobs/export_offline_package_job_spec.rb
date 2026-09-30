require "rails_helper"

RSpec.describe ExportOfflinePackageJob do
  let(:translation) { create(:translation, offline_downloadable: true) }
  let(:book) { create(:book) }
  let(:publisher) { instance_double(OfflinePackages::Publisher) }
  let(:published) do
    { storage_key: "translations/eng-web/v1/abc.sqlite.gz", url: "https://downloads.example.com/translations/eng-web/v1/abc.sqlite.gz",
      sha256: "abc", size_bytes: 100, uncompressed_size_bytes: 400 }
  end

  before do
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 1, text: "In the beginning")
    allow(OfflinePackages::Publisher).to receive(:new).and_return(publisher)
    allow(publisher).to receive(:publish).and_return(published)
  end

  def digest = OfflinePackages::Builder.new(translation).source_digest

  it "builds, publishes and records the package" do
    described_class.perform_now(translation.id)

    package = translation.offline_packages.sole
    expect(package).to have_attributes(published.merge(schema_version: 1, source_digest: digest, verse_count: 1))
  end

  it "passes a real SQLite file to the publisher" do
    allow(OfflinePackages::Publisher).to receive(:new) do |_translation, path|
      expect(SQLite3::Database.new(path).get_first_value("SELECT count(*) FROM verses")).to eq(1)
      publisher
    end

    described_class.perform_now(translation.id)
  end

  it "skips publishing when the source digest is unchanged" do
    create(:offline_package, translation: translation, source_digest: digest)

    described_class.perform_now(translation.id)
    expect(publisher).not_to have_received(:publish)
  end

  it "republishes with force and updates the existing row instead of duplicating it" do
    existing = create(:offline_package, translation: translation, source_digest: digest, sha256: "old")

    described_class.perform_now(translation.id, force: true)

    expect(publisher).to have_received(:publish)
    expect(translation.offline_packages.count).to eq(1)
    expect(existing.reload.sha256).to eq("abc")
  end

  it "republishes when the data changed" do
    create(:offline_package, translation: translation, source_digest: "stale")

    described_class.perform_now(translation.id)
    expect(translation.offline_packages.sole.source_digest).to eq(digest)
  end

  it "refuses a translation that is not offline-downloadable" do
    translation.update!(offline_downloadable: false)

    expect { described_class.perform_now(translation.id) }.to raise_error(OfflinePackages::NotDownloadable)
    expect(publisher).not_to have_received(:publish)
  end
end
