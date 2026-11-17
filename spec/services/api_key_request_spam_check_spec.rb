require "rails_helper"

RSpec.describe ApiKeyRequestSpamCheck do
  def check(honeypot: nil, **attrs)
    request = build(:api_key_request, name: "Ana López", email: "ana@example.com",
                                      description: "Bible verse widget for my church site", **attrs)
    described_class.new(request, honeypot: honeypot)
  end

  it "passes a normal request" do
    expect(check).not_to be_spam
    expect(check.reasons).to be_empty
  end

  it "passes real requests with short or informal descriptions" do
    %w[request para\ pruebas ai\ bible\ bot Checking\ it\ out!].each do |description|
      expect(check(description: description)).not_to be_spam
    end
  end

  it "passes names with initials and accents" do
    expect(check(name: "J. R. Smith")).not_to be_spam
    expect(check(name: "José María Pérez-García")).not_to be_spam
  end

  it "flags a filled honeypot" do
    expect(check(honeypot: "http://example.com").reasons).to eq([ "honeypot filled" ])
  end

  it "flags casino spam in the name" do
    name = "* * * 🚀 FREE $3000 BONUS BALANCE: Get $3000 on your bonus account by opening " \
           "https://www.drive-piscines-37.fr/css/go-na.php?tek5ex 🔑, copying the promo code * * *"
    expect(check(name: name).reasons).to eq([ "link in name" ])
  end

  it "flags bare domains in the name" do
    expect(check(name: "Bonus at casino.xyz").reasons).to eq([ "link in name" ])
    expect(check(name: "visit www.example.fr").reasons).to eq([ "link in name" ])
  end

  it "flags the contact-form bot's description" do
    description = "I would like more information. Please contact me by email — get a free bible api key."
    expect(check(name: "Hannah Thomas", description: description).reasons).to eq([ "known spam description" ])
  end

  it "flags blocked email domains, case-insensitively" do
    expect(check(email: "abc123@1WIN.xyz").reasons).to eq([ "blocked email domain" ])
  end
end
