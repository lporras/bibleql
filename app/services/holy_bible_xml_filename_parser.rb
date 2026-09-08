# frozen_string_literal: true

# Derives a stable identifier, language code, and variant from a
# Holy-Bible-XML-Format filename, e.g. "Afrikaans1983Bible.xml" or
# "ArabicSVDBible.xml". There is no per-file metadata table for this source
# (unlike config/biblelist_translations.yml) — everything here is inferred
# from the filename itself, on a best-effort basis. See config/language_codes.yml.
#
#   HolyBibleXmlFilenameParser.call("ArabicSVDBible.xml")
#   # => #<data identifier="ara-svd", language_code="ara", language_name="Arabic", variant="svd", abbrev="SVD">
class HolyBibleXmlFilenameParser
  Result = Data.define(:identifier, :language_code, :language_name, :variant, :abbrev)

  LANGUAGE_CODES = YAML.load_file(Rails.root.join("config", "language_codes.yml")).freeze
  FILENAME_SUFFIX = /Bible\.xml\z/i
  ABBREV_RE = /\A[A-Z][A-Z0-9]*\z/

  def self.call(filename)
    stem = File.basename(filename).sub(FILENAME_SUFFIX, "")
    words = split_words(stem)
    language_words, language_code = match_language(words)
    variant_words = words[language_words.size..]

    variant = variant_words.map(&:downcase).join("-")
    abbrev = variant_words.first if variant_words.size == 1 && variant_words.first.match?(ABBREV_RE)
    identifier = variant.empty? ? language_code : "#{language_code}-#{variant}"

    Result.new(
      identifier: identifier,
      language_code: language_code,
      language_name: language_words.join(" "),
      variant: variant,
      abbrev: abbrev
    )
  end

  # Splits a PascalCase/digit run into words, keeping acronym runs (e.g. "SVD",
  # "DFBE") intact as a single word instead of splitting on every capital.
  def self.split_words(stem)
    words = []
    current = +""

    stem.each_char.with_index do |char, index|
      if boundary?(current, char, stem[index + 1])
        words << current
        current = +""
      end
      current << char
    end

    words << current unless current.empty?
    words
  end
  private_class_method :split_words

  def self.boundary?(current, char, next_char)
    return false if current.empty?

    last = current[-1]
    return true if char.match?(/[A-Za-z]/) && last.match?(/\d/)
    return true if char.match?(/\d/) && !last.match?(/\d/)
    return true if char.match?(/[A-Z]/) && last.match?(/[a-z]/)
    return true if char.match?(/[A-Z]/) && last.match?(/[A-Z]/) && next_char&.match?(/[a-z]/)

    false
  end
  private_class_method :boundary?

  # Matches the longest leading run of words against config/language_codes.yml
  # (so a future multi-word entry, e.g. "South Azerbaijan", is supported);
  # falls back to treating the first word as the language verbatim.
  def self.match_language(words)
    words.length.downto(1) do |n|
      candidate = words.first(n)
      code = LANGUAGE_CODES[candidate.join(" ")]
      return [ candidate, code ] if code
    end

    [ [ words.first ], words.first.downcase ]
  end
  private_class_method :match_language
end
