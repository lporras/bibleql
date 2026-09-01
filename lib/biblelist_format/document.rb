# frozen_string_literal: true

module BiblelistFormat
  # SAX handler for the XML shape used by the files in db/biblelist/:
  #
  #   <bible title="..." status="..." link="...">
  #     <testament name="Old">
  #       <book number="1">
  #         <chapter number="1">
  #           <verse number="1">In the beginning...</verse>
  #
  # Books are bare ordinals with no names, so the ZXBML ordinal → USFM id map is
  # reused and #book_title reports the id. Callers that need real book names get
  # them elsewhere — see BiblelistImporter, which copies them from an already
  # imported translation of the same language.
  class Document < BibleParser::Parsers::Base::Document
    BOOK_IDS = BibleParser::Parsers::ZXBML::BookIDs::BOOK_IDS

    def start_element(name, attributes)
      case name
      when "book" then start_book(attributes)
      when "chapter" then start_chapter(attributes)
      when "verse" then start_verse(attributes)
      end
    end

    def end_element(name)
      case name
      when "book"
        end_book
        end_verse if @mode == "verse"
      when "chapter"
        end_chapter
        end_verse if @mode == "verse"
      when "verse"
        end_verse
      end
    end

    def characters(string)
      @text << string if @mode == "verse"
    end

    private

    def start_book(attributes)
      @book_num = Hash[attributes]["number"].to_i
      @book_id = BOOK_IDS[@book_num]
      @book_title = @book_id
      @mode = "book"
    end

    def start_chapter(attributes)
      @chapter = Hash[attributes]["number"].to_i
    end

    def start_verse(attributes)
      @verse = Hash[attributes]["number"].to_i
      @text = +""
      @mode = "verse"
    end
  end
end
