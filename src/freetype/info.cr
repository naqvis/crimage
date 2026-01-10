require "./truetype/truetype"

# Font metadata and character coverage analysis.
#
# Extracts human-readable information from TrueType font 'name' table including
# family name, designer, version, copyright, and more. Also provides character
# coverage checking and Unicode range detection.
#
# Example:
# ```
# ttf = FreeType::TrueType.load("font.ttf")
# font = FreeType::Info.load(ttf)
#
# puts font.info.family_name # "Roboto"
# puts font.info.designer    # "Christian Robertson"
#
# # Check character support
# font.has_char?('A')          # true
# font.has_chars?("Hello")     # true
# font.missing_chars("Hello™") # ['™']
# font.coverage("Hello World") # 100.0
#
# # Detect Unicode ranges
# font.unicode_ranges.each do |range|
#   puts "#{range[:name]}: #{range[:coverage]}%"
# end
# ```
module FreeType::Info
  # Name ID constants (from OpenType spec)
  NAME_COPYRIGHT             =  0_u16
  NAME_FAMILY                =  1_u16
  NAME_SUBFAMILY             =  2_u16
  NAME_UNIQUE_ID             =  3_u16
  NAME_FULL_NAME             =  4_u16
  NAME_VERSION               =  5_u16
  NAME_POSTSCRIPT_NAME       =  6_u16
  NAME_TRADEMARK             =  7_u16
  NAME_MANUFACTURER          =  8_u16
  NAME_DESIGNER              =  9_u16
  NAME_DESCRIPTION           = 10_u16
  NAME_VENDOR_URL            = 11_u16
  NAME_DESIGNER_URL          = 12_u16
  NAME_LICENSE               = 13_u16
  NAME_LICENSE_URL           = 14_u16
  NAME_TYPOGRAPHIC_FAMILY    = 16_u16
  NAME_TYPOGRAPHIC_SUBFAMILY = 17_u16

  # Platform IDs
  PLATFORM_UNICODE   = 0_u16
  PLATFORM_MACINTOSH = 1_u16
  PLATFORM_WINDOWS   = 3_u16

  # Font information extracted from name table
  class FontInfo
    property family_name : String = ""
    property subfamily_name : String = ""
    property full_name : String = ""
    property version : String = ""
    property postscript_name : String = ""
    property copyright : String = ""
    property trademark : String = ""
    property manufacturer : String = ""
    property designer : String = ""
    property description : String = ""

    def initialize
    end

    # Get style name (alias for subfamily)
    def style_name : String
      @subfamily_name
    end
  end

  # Font metadata and information
  class Font
    getter font : FreeType::TrueType::Font
    getter info : FontInfo

    def initialize(@font)
      @info = FontInfo.new
      parse_name_table
    end

    # Check if font contains a glyph for the specified character.
    #
    # Returns true if the font has a glyph for this character, false otherwise.
    # Note: Returns false for characters that map to the missing glyph (.notdef).
    def has_char?(char : Char) : Bool
      @font.glyph_index(char) != 0
    end

    # Check if font contains glyphs for all characters in a string.
    #
    # Returns true only if every character in the string has a corresponding
    # glyph in the font.
    def has_chars?(text : String) : Bool
      text.each_char.all? { |c| has_char?(c) }
    end

    # Get list of characters from a string that are not supported by the font.
    #
    # Returns an array of unique characters that don't have glyphs in the font.
    # Useful for validating text before rendering or choosing fallback fonts.
    def missing_chars(text : String) : Array(Char)
      text.chars.select { |c| !has_char?(c) }.uniq
    end

    # Calculate percentage of characters in a string that are supported by the font.
    #
    # Returns a value from 0.0 to 100.0 indicating what percentage of the
    # string's characters have glyphs in the font. Returns 100.0 for empty strings.
    def coverage(text : String) : Float64
      return 100.0 if text.empty?
      present = text.chars.count { |c| has_char?(c) }
      (present.to_f / text.size * 100.0)
    end

    # Detect supported Unicode ranges
    def unicode_ranges : Array(NamedTuple(name: String, range: Range(Int32, Int32), coverage: Float64))
      ranges = [
        {name: "Basic Latin", range: 0x0000..0x007F},
        {name: "Latin-1 Supplement", range: 0x0080..0x00FF},
        {name: "Latin Extended-A", range: 0x0100..0x017F},
        {name: "Latin Extended-B", range: 0x0180..0x024F},
        {name: "Greek and Coptic", range: 0x0370..0x03FF},
        {name: "Cyrillic", range: 0x0400..0x04FF},
        {name: "Arabic", range: 0x0600..0x06FF},
        {name: "Hebrew", range: 0x0590..0x05FF},
        {name: "Devanagari", range: 0x0900..0x097F},
        {name: "Thai", range: 0x0E00..0x0E7F},
        {name: "CJK Unified Ideographs", range: 0x4E00..0x9FFF},
        {name: "Hiragana", range: 0x3040..0x309F},
        {name: "Katakana", range: 0x30A0..0x30FF},
        {name: "Hangul Syllables", range: 0xAC00..0xD7AF},
        {name: "Emoji", range: 0x1F600..0x1F64F},
      ]

      ranges.map do |r|
        # Sample the range (checking every character would be slow)
        sample_size = [100, r[:range].size].min
        step = r[:range].size // sample_size
        step = 1 if step == 0

        present = 0
        total = 0
        r[:range].step(by: step) do |code|
          total += 1
          present += 1 if has_char?(code.chr)
        end

        coverage = total > 0 ? (present.to_f / total * 100.0) : 0.0
        {name: r[:name], range: r[:range], coverage: coverage}
      end
    end

    # Get glyph count
    def glyph_count : Int32
      @font.num_glyphs
    end

    # Check if font has kerning data
    def has_kerning? : Bool
      @font.@kern != 0
    end

    # Check if font has vertical metrics
    def has_vertical_metrics? : Bool
      @font.has_vertical_metrics?
    end

    # Check if font is a variable font
    def is_variable? : Bool
      # Would need to check fvar table
      false # Placeholder for now
    end

    private def parse_name_table
      return if @font.@name == 0

      data = @font.data
      offset = @font.@name

      # Validate name table size
      return if offset + 6 > data.size

      format = read_u16(data, offset)
      return unless format == 0 || format == 1 # Only support format 0 and 1

      count = read_u16(data, offset + 2)
      string_offset = read_u16(data, offset + 4)

      # Parse name records
      record_offset = offset + 6
      count.times do |i|
        current_offset = record_offset + i * 12
        break if current_offset + 12 > data.size

        platform_id = read_u16(data, current_offset)
        encoding_id = read_u16(data, current_offset + 2)
        language_id = read_u16(data, current_offset + 4)
        name_id = read_u16(data, current_offset + 6)
        length = read_u16(data, current_offset + 8)
        name_offset = read_u16(data, current_offset + 10)

        # Calculate absolute offset to string data
        str_offset = offset + string_offset + name_offset
        next if str_offset + length > data.size

        # Extract string based on platform/encoding
        str = extract_string(data, str_offset, length.to_i, platform_id, encoding_id)
        next if str.empty?

        # Store in appropriate field
        case name_id
        when NAME_FAMILY
          @info.family_name = str if @info.family_name.empty?
        when NAME_SUBFAMILY
          @info.subfamily_name = str if @info.subfamily_name.empty?
        when NAME_FULL_NAME
          @info.full_name = str if @info.full_name.empty?
        when NAME_VERSION
          @info.version = str if @info.version.empty?
        when NAME_POSTSCRIPT_NAME
          @info.postscript_name = str if @info.postscript_name.empty?
        when NAME_COPYRIGHT
          @info.copyright = str if @info.copyright.empty?
        when NAME_TRADEMARK
          @info.trademark = str if @info.trademark.empty?
        when NAME_MANUFACTURER
          @info.manufacturer = str if @info.manufacturer.empty?
        when NAME_DESIGNER
          @info.designer = str if @info.designer.empty?
        when NAME_DESCRIPTION
          @info.description = str if @info.description.empty?
        end
      end
    end

    private def extract_string(data : Bytes, offset : Int32, length : Int32, platform_id : UInt16, encoding_id : UInt16) : String
      return "" if offset + length > data.size

      case platform_id
      when PLATFORM_UNICODE, PLATFORM_WINDOWS
        # UTF-16 Big Endian
        return "" if length % 2 != 0

        chars = [] of UInt32
        i = 0
        while i < length
          char = ((data[offset + i].to_u16 << 8) | data[offset + i + 1].to_u16).to_u32
          chars << char
          i += 2
        end

        # Convert UTF-16 to UTF-8
        String.build do |str|
          chars.each do |c|
            str << c.chr if c < 0x110000
          end
        end
      when PLATFORM_MACINTOSH
        # MacRoman encoding (ASCII-compatible for basic chars)
        String.new(data[offset, length])
      else
        ""
      end
    rescue
      ""
    end

    private def read_u16(data : Bytes, offset : Int32) : UInt16
      (data[offset].to_u16 << 8) | data[offset + 1].to_u16
    end
  end

  # Load font with metadata
  def self.load(font : FreeType::TrueType::Font) : Font
    Font.new(font)
  end

  # Load font from file with metadata
  def self.load(path : String) : Font
    ttf = FreeType::TrueType.load(path)
    Font.new(ttf)
  end
end
