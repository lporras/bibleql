require "ipaddr"

# The real client IP for a request that may have come through Cloudflare.
#
# bibleql.org is proxied by Cloudflare, so Rack's request.ip is a Cloudflare edge address, and
# per-IP limits keyed on it throttle Cloudflare instead of the client. Cloudflare sends the
# client's address in CF-Connecting-IP. That header is only trusted when the request actually
# came from a Cloudflare range: a request sent straight to the origin can set it to anything.
module ClientIp
  # https://www.cloudflare.com/ips-v4 and https://www.cloudflare.com/ips-v6 (fetched 2026-11-17)
  CLOUDFLARE_RANGES = %w[
    173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18
    108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17
    162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32
    2a06:98c0::/29 2c0f:f248::/32
  ].map { |range| IPAddr.new(range) }.freeze

  # request: a Rack::Request (Rack::Attack) or ActionDispatch::Request (controllers).
  def self.for(request)
    peer = request.ip
    forwarded = request.get_header("HTTP_CF_CONNECTING_IP").to_s.strip

    cloudflare?(peer) && valid_ip?(forwarded) ? forwarded : peer
  end

  def self.cloudflare?(ip)
    return false if ip.blank?

    address = IPAddr.new(ip)
    CLOUDFLARE_RANGES.any? { |range| range.family == address.family && range.include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def self.valid_ip?(ip)
    ip.present? && IPAddr.new(ip) && true
  rescue IPAddr::InvalidAddressError
    false
  end
end
