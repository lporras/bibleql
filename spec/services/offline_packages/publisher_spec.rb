require "rails_helper"
require "aws-sdk-s3"

RSpec.describe OfflinePackages::Publisher do
  let(:translation) { build(:translation, identifier: "eng-web") }
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "eng-web.sqlite") }

  before { File.write(path, "not really sqlite " * 1000) }
  after { FileUtils.rm_rf(dir) }

  def publish
    described_class.new(translation, path, client: client, bucket: "bibleql-test",
      public_base_url: "https://downloads.example.com/").publish
  end

  it "uploads the gzipped file under an immutable, content-addressed key" do
    result = publish
    gz_bytes = File.binread("#{path}.gz")
    sha256 = Digest::SHA256.hexdigest(gz_bytes)

    expect(result).to eq(
      storage_key: "translations/eng-web/v1/#{sha256}.sqlite.gz",
      url: "https://downloads.example.com/translations/eng-web/v1/#{sha256}.sqlite.gz",
      sha256: sha256,
      size_bytes: gz_bytes.bytesize,
      uncompressed_size_bytes: File.size(path)
    )
    expect(Zlib.gunzip(gz_bytes)).to eq(File.binread(path))
  end

  it "sends the caching and content-type headers" do
    publish
    request = client.api_requests.find { |r| r[:operation_name] == :put_object }

    expect(request[:params]).to include(
      bucket: "bibleql-test",
      content_type: "application/gzip",
      cache_control: "public, max-age=31536000, immutable"
    )
    expect(request[:params][:key]).to match(%r{\Atranslations/eng-web/v1/\h{64}\.sqlite\.gz\z})
  end
end
