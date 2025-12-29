require "./truetype/truetype"

# OpenType Layout Tables (GPOS/GSUB) support
# - GPOS: Glyph Positioning - controls spacing, kerning, mark positioning
# - GSUB: Glyph Substitution - controls ligatures, alternates, contextual forms
# Specification: https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2
module FreeType::Layout
  # Feature tags (common OpenType features)
  FEATURE_KERN = 0x6B65726E_u32 # 'kern' - Kerning
  FEATURE_LIGA = 0x6C696761_u32 # 'liga' - Standard Ligatures
  FEATURE_DLIG = 0x646C6967_u32 # 'dlig' - Discretionary Ligatures
  FEATURE_CALT = 0x63616C74_u32 # 'calt' - Contextual Alternates
  FEATURE_SMCP = 0x736D6370_u32 # 'smcp' - Small Capitals
  FEATURE_SWSH = 0x73777368_u32 # 'swsh' - Swash
  FEATURE_FRAC = 0x66726163_u32 # 'frac' - Fractions

  # Script tags
  SCRIPT_LATIN    = 0x6C61746E_u32 # 'latn'
  SCRIPT_CYRILLIC = 0x6379726C_u32 # 'cyrl'
  SCRIPT_GREEK    = 0x6772656B_u32 # 'grek'
  SCRIPT_ARABIC   = 0x61726162_u32 # 'arab'

  # OpenType feature record
  struct Feature
    property tag : UInt32
    property name : String

    def initialize(@tag, @name = "")
    end

    # Get human-readable tag name
    def tag_name : String
      String.new(Bytes[
        ((@tag >> 24) & 0xFF).to_u8,
        ((@tag >> 16) & 0xFF).to_u8,
        ((@tag >> 8) & 0xFF).to_u8,
        (@tag & 0xFF).to_u8,
      ])
    end
  end

  # OpenType script record
  struct Script
    property tag : UInt32
    property name : String

    def initialize(@tag, @name = "")
    end

    def tag_name : String
      String.new(Bytes[
        ((@tag >> 24) & 0xFF).to_u8,
        ((@tag >> 16) & 0xFF).to_u8,
        ((@tag >> 8) & 0xFF).to_u8,
        (@tag & 0xFF).to_u8,
      ])
    end
  end

  # Layout table (GPOS or GSUB)
  class LayoutTable
    getter features : Array(Feature)
    getter scripts : Array(Script)
    @table_offset : Int32 = 0

    def initialize(data : Bytes, offset : Int32)
      @features = [] of Feature
      @scripts = [] of Script
      @table_offset = offset
      parse_table(data, offset)
    end

    # Check if table has a specific feature
    def has_feature?(tag : UInt32) : Bool
      @features.any? { |f| f.tag == tag }
    end

    # Check if table has a specific feature by name
    def has_feature?(tag_name : String) : Bool
      return false if tag_name.size != 4
      tag = (tag_name[0].ord.to_u32 << 24) |
            (tag_name[1].ord.to_u32 << 16) |
            (tag_name[2].ord.to_u32 << 8) |
            tag_name[3].ord.to_u32
      has_feature?(tag)
    end

    # Check if table supports a specific script
    def has_script?(tag : UInt32) : Bool
      @scripts.any? { |s| s.tag == tag }
    end

    private def parse_table(data : Bytes, offset : Int32)
      return if offset + 10 > data.size

      major_version = read_u16(data, offset)
      minor_version = read_u16(data, offset + 2)

      # Only support version 1.0 and 1.1
      return unless major_version == 1 && (minor_version == 0 || minor_version == 1)

      script_list_offset = read_u16(data, offset + 4)
      feature_list_offset = read_u16(data, offset + 6)
      _lookup_list_offset = read_u16(data, offset + 8)

      # Parse script list
      parse_script_list(data, offset + script_list_offset) if script_list_offset > 0

      # Parse feature list
      parse_feature_list(data, offset + feature_list_offset) if feature_list_offset > 0
    end

    private def parse_script_list(data : Bytes, offset : Int32)
      return if offset + 2 > data.size

      script_count = read_u16(data, offset)
      return if script_count == 0 || script_count > 100

      # Read script records
      script_count.times do |i|
        record_offset = offset + 2 + i * 6
        break if record_offset + 6 > data.size

        tag = read_u32(data, record_offset)
        _script_offset = read_u16(data, record_offset + 4)

        @scripts << Script.new(tag)
      end
    end

    private def parse_feature_list(data : Bytes, offset : Int32)
      return if offset + 2 > data.size

      feature_count = read_u16(data, offset)
      return if feature_count == 0 || feature_count > 200

      # Read feature records
      feature_count.times do |i|
        record_offset = offset + 2 + i * 6
        break if record_offset + 6 > data.size

        tag = read_u32(data, record_offset)
        _feature_offset = read_u16(data, record_offset + 4)

        @features << Feature.new(tag)
      end
    end

    private def read_u16(data : Bytes, offset : Int32) : UInt16
      (data[offset].to_u16 << 8) | data[offset + 1].to_u16
    end

    private def read_u32(data : Bytes, offset : Int32) : UInt32
      (data[offset].to_u32 << 24) | (data[offset + 1].to_u32 << 16) |
        (data[offset + 2].to_u32 << 8) | data[offset + 3].to_u32
    end
  end

  # Font with layout table support
  class Font
    getter font : FreeType::TrueType::Font
    getter gpos : LayoutTable?
    getter gsub : LayoutTable?

    def initialize(@font)
      @gpos = nil
      @gsub = nil
      parse_layout_tables
    end

    # Check if font has GPOS table
    def has_gpos? : Bool
      !@gpos.nil?
    end

    # Check if font has GSUB table
    def has_gsub? : Bool
      !@gsub.nil?
    end

    # Get all features from both tables
    def all_features : Array(Feature)
      features = [] of Feature
      features.concat(@gpos.not_nil!.features) if @gpos
      features.concat(@gsub.not_nil!.features) if @gsub
      features.uniq { |f| f.tag }
    end

    # Get all scripts from both tables
    def all_scripts : Array(Script)
      scripts = [] of Script
      scripts.concat(@gpos.not_nil!.scripts) if @gpos
      scripts.concat(@gsub.not_nil!.scripts) if @gsub
      scripts.uniq { |s| s.tag }
    end

    private def parse_layout_tables
      data = @font.data
      base_offset = @font.@base_offset

      return if data.size < base_offset + 12

      version = read_u32(data, base_offset)
      return unless version == 0x00010000 || version == 0x74727565

      num_tables = read_u16(data, base_offset + 4)

      # Find GPOS and GSUB tables
      (base_offset + 12).step(by: 16, to: base_offset + 12 + num_tables * 16 - 1) do |offset|
        break if offset + 16 > data.size

        tag = String.new(data[offset, 4])
        table_offset = read_u32(data, offset + 8).to_i

        case tag
        when "GPOS"
          @gpos = LayoutTable.new(data, table_offset) rescue nil
        when "GSUB"
          @gsub = LayoutTable.new(data, table_offset) rescue nil
        end
      end
    end

    private def read_u16(data : Bytes, offset : Int32) : UInt16
      (data[offset].to_u16 << 8) | data[offset + 1].to_u16
    end

    private def read_u32(data : Bytes, offset : Int32) : UInt32
      (data[offset].to_u32 << 24) | (data[offset + 1].to_u32 << 16) |
        (data[offset + 2].to_u32 << 8) | data[offset + 3].to_u32
    end
  end

  # Load a font with layout table support
  def self.load(font : FreeType::TrueType::Font) : Font
    Font.new(font)
  end

  # Load a font from file
  def self.load(path : String) : Font
    ttf = FreeType::TrueType.load(path)
    Font.new(ttf)
  end
end
