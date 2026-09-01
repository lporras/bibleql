# frozen_string_literal: true

module BiblelistFormat
  # A bible_parser format plugin for the db/biblelist/ XML shape. Subclassing the
  # gem's Base::Parser gives #each_book/#each_chapter/#each_verse for free, all
  # streaming through Nokogiri's SAX parser.
  #
  # Deliberately not registered in BibleParser::PARSERS: the format has no
  # distinctive root tag, so adding it to the detection chain would risk
  # mislabelling the open-bibles files. Instantiate it directly instead.
  #
  #   BiblelistFormat::Parser.new(File.open(path)).each_verse { |verse| ... }
  class Parser < BibleParser::Parsers::Base::Parser
    ROOT_TAG = "bible"

    def valid?
      (@io.read(1024) =~ /<#{ROOT_TAG}[^>]*>\s*<testament/im).tap { @io.rewind }
    end

    # Attributes of the root <bible> element, which is where these files keep
    # their name and copyright notice. Attribute naming is inconsistent across
    # files (title/status vs translation/info), so the raw hash is returned and
    # BiblelistImporter decides which keys to prefer.
    def bible_attributes
      @io.rewind
      reader = Nokogiri::XML::Reader(@io)
      reader.each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT

        return node.name == ROOT_TAG ? node.attributes : {}
      end
      {}
    ensure
      @io.rewind
    end
  end
end
