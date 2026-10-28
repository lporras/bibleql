# Sends Unsplash's required download ping (a photo's links.download_location) after a client
# reports it used a photo via trackImageDownload. Fire-and-forget: a failed ping is logged and
# dropped rather than retried.
class TrackUnsplashDownloadJob < ApplicationJob
  queue_as :default

  discard_on(UnsplashClient::Error) do |_job, error|
    Rails.logger.warn("[unsplash] download tracking failed: #{error.class.name.demodulize}: #{error.message}")
  end

  def perform(download_location)
    UnsplashClient.new.track_download(download_location)
  end
end
