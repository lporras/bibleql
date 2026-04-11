# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host = "https://bibleql.org"

SitemapGenerator::Sitemap.create do
  # Root "/" is added automatically

  add "/playground", changefreq: "monthly", priority: 0.8
  add "/api-keys/request/new", changefreq: "monthly", priority: 0.7
end
