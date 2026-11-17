require "rails_helper"

RSpec.describe ClientIp do
  def request_from(remote_addr, cf_connecting_ip: nil)
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => remote_addr)
    env["HTTP_CF_CONNECTING_IP"] = cf_connecting_ip if cf_connecting_ip
    Rack::Request.new(env)
  end

  it "uses CF-Connecting-IP when the request comes from a Cloudflare IPv4 edge" do
    expect(described_class.for(request_from("172.71.151.144", cf_connecting_ip: "203.0.113.7"))).to eq("203.0.113.7")
  end

  it "uses CF-Connecting-IP when the request comes from a Cloudflare IPv6 edge" do
    expect(described_class.for(request_from("2606:4700::1", cf_connecting_ip: "2001:db8::5"))).to eq("2001:db8::5")
  end

  it "ignores CF-Connecting-IP from a non-Cloudflare peer, so it can't be spoofed" do
    expect(described_class.for(request_from("198.51.100.20", cf_connecting_ip: "203.0.113.7"))).to eq("198.51.100.20")
  end

  it "falls back to the peer when the header is missing or not an IP" do
    expect(described_class.for(request_from("104.22.160.9"))).to eq("104.22.160.9")
    expect(described_class.for(request_from("104.22.160.9", cf_connecting_ip: "not-an-ip"))).to eq("104.22.160.9")
  end

  it "uses the Cloudflare edge from X-Forwarded-For when behind the host's load balancer" do
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "10.0.0.5",
      "HTTP_X_FORWARDED_FOR" => "203.0.113.7, 104.22.160.50", "HTTP_CF_CONNECTING_IP" => "203.0.113.7")
    expect(described_class.for(Rack::Request.new(env))).to eq("203.0.113.7")
  end
end
