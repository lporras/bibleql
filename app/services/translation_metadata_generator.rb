# frozen_string_literal: true

# Regenerates config/translations.yml from the "Translation List" table in the
# open-bibles submodule README. Development maintenance only — the app reads the
# generated YAML through TranslationMetadata, never this class.
class TranslationMetadataGenerator
  README_PATH = Rails.root.join("db", "open-bibles", "README.md")
  OUTPUT_PATH = Rails.root.join("config", "translations.yml")

  FILE_SUFFIX = /\.(usfx|osis|zefania)\.xml\z/i

  # Licenses the README defers to its "Translation Details" prose section.
  CUSTOM_LICENSES = {
    "heb-leningrad" => "Free to use — see db/open-bibles/README.md#hebrew-leningrad-codex"
  }.freeze

  HEADER = <<~COMMENT
    # Translation metadata sourced from db/open-bibles/README.md "Translation List".
    # Regenerate with: bundle exec rake bible:generate_metadata
  COMMENT

  def initialize(readme_path: README_PATH, output_path: OUTPUT_PATH)
    @readme_path = readme_path
    @output_path = output_path
  end

  def call
    metadata = parse
    File.write(@output_path, HEADER + metadata.to_yaml(line_width: -1))
    metadata
  end

  def parse
    rows.each_with_object({}) do |row, hash|
      identifier = row[:filename].sub(FILE_SUFFIX, "")
      hash[identifier] = {
        "name" => row[:version],
        "abbrev" => row[:abbrev].presence,
        "language_name" => row[:language],
        "note" => normalize_license(row[:license], identifier)
      }
    end.sort.to_h
  end

  private

  def rows
    table_lines.filter_map do |line|
      cells = line.split("|").map(&:strip)
      cells.shift # leading pipe produces an empty first cell
      next unless cells.size >= 6
      next unless cells[0].match?(FILE_SUFFIX)

      {
        filename: cells[0],
        language: cells[1],
        format: cells[2],
        abbrev: cells[3],
        version: cells[4],
        license: cells[5]
      }
    end
  end

  def table_lines
    File.readlines(@readme_path).select { |line| line.start_with?("|") }
  end

  # "Public Domain" passes through; "[CC BY 4.0][cc-by-4]" becomes "CC BY 4.0";
  # "_see below_" resolves via CUSTOM_LICENSES. Anything else is flagged rather
  # than silently written as if it were a real license.
  def normalize_license(license, identifier)
    case license
    when /\A\[([^\]]+)\]\[[^\]]+\]\z/ then Regexp.last_match(1)
    when "_see below_", "" then CUSTOM_LICENSES.fetch(identifier) { "TODO: see db/open-bibles/README.md" }
    else license
    end
  end
end
