# frozen_string_literal: true

module OfflinePackages
  # Gzips a built package and uploads it to R2 under an immutable, content-addressed
  # key, so a new export never overwrites a file a client may be downloading.
  class Publisher
    CACHE_CONTROL = "public, max-age=31536000, immutable"
    CONTENT_TYPE = "application/gzip"

    def initialize(translation, path, client: nil, bucket: nil, public_base_url: nil)
      @translation = translation
      @path = path.to_s
      @client = client
      @bucket = bucket
      @public_base_url = public_base_url
    end

    # Returns { storage_key:, url:, sha256:, size_bytes:, uncompressed_size_bytes: }.
    # sha256 and size_bytes describe the .gz, which is what clients download and verify.
    def publish
      gz_path = "#{@path}.gz"
      gzip(gz_path)
      sha256 = Digest::SHA256.file(gz_path).hexdigest
      key = storage_key(sha256)

      File.open(gz_path, "rb") do |body|
        client.put_object(
          bucket: bucket,
          key: key,
          body: body,
          content_type: CONTENT_TYPE,
          cache_control: CACHE_CONTROL
        )
      end

      {
        storage_key: key,
        url: "#{public_base_url.chomp('/')}/#{key}",
        sha256: sha256,
        size_bytes: File.size(gz_path),
        uncompressed_size_bytes: File.size(@path)
      }
    end

    def storage_key(sha256)
      "translations/#{@translation.identifier}/v#{Builder::SCHEMA_VERSION}/#{sha256}.sqlite.gz"
    end

    private

    def gzip(gz_path)
      Zlib::GzipWriter.open(gz_path, Zlib::BEST_COMPRESSION) do |gz|
        File.open(@path, "rb") { |file| IO.copy_stream(file, gz) }
      end
    end

    def client = @client ||= OfflinePackages.s3_client
    def bucket = @bucket ||= OfflinePackages.config.fetch(:bucket)
    def public_base_url = @public_base_url ||= OfflinePackages.config.fetch(:public_base_url)
  end
end
