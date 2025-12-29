require "./truetype/truetype"

# Variable Fonts (OpenType Font Variations) support
# Specification: https://docs.microsoft.com/en-us/typography/opentype/spec/otvaroverview
module FreeType::Variable
  # Axis tag constants (common variation axes)
  AXIS_WEIGHT       = 0x77676874_u32 # 'wght'
  AXIS_WIDTH        = 0x77647468_u32 # 'wdth'
  AXIS_SLANT        = 0x736C6E74_u32 # 'slnt'
  AXIS_ITALIC       = 0x6974616C_u32 # 'ital'
  AXIS_OPTICAL_SIZE = 0x6F70737A_u32 # 'opsz'

  # Variation axis definition
  struct VariationAxis
    property tag : UInt32
    property min_value : Float32
    property default_value : Float32
    property max_value : Float32
    property name : String

    def initialize(@tag, @min_value, @default_value, @max_value, @name = "")
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

  # Variable font wrapper
  class Font
    getter font : FreeType::TrueType::Font
    getter axes : Array(VariationAxis)
    @fvar_offset : Int32 = 0
    @axis_count : UInt16 = 0

    def initialize(@font)
      @axes = [] of VariationAxis
      parse_fvar_table
    end

    # Check if font is a variable font
    def is_variable? : Bool
      @axis_count > 0
    end

    # Get axis by tag
    def axis(tag : UInt32) : VariationAxis?
      @axes.find { |a| a.tag == tag }
    end

    # Get axis by tag name (e.g., "wght")
    def axis(tag_name : String) : VariationAxis?
      return nil if tag_name.size != 4
      tag = (tag_name[0].ord.to_u32 << 24) |
            (tag_name[1].ord.to_u32 << 16) |
            (tag_name[2].ord.to_u32 << 8) |
            tag_name[3].ord.to_u32
      axis(tag)
    end

    private def parse_fvar_table
      # Find fvar table in font
      data = @font.data
      base_offset = @font.@base_offset

      # Check for fvar table signature in table directory
      raise CrImage::FormatError.new("Font data too small") if data.size < base_offset + 12

      version = read_u32(data, base_offset)
      raise CrImage::FormatError.new("Invalid font signature") unless version == 0x00010000 || version == 0x74727565

      num_tables = read_u16(data, base_offset + 4)

      # Find fvar table
      (base_offset + 12).step(by: 16, to: base_offset + 12 + num_tables * 16 - 1) do |offset|
        break if offset + 16 > data.size

        tag = String.new(data[offset, 4])
        next unless tag == "fvar"

        table_offset = read_u32(data, offset + 8).to_i
        @fvar_offset = table_offset
        parse_fvar_data(data, table_offset)
        return
      end

      # No fvar table found - not a variable font
      @axis_count = 0
    end

    private def parse_fvar_data(data : Bytes, offset : Int32)
      return if offset + 16 > data.size

      major_version = read_u16(data, offset)
      minor_version = read_u16(data, offset + 2)

      # Only support version 1.0
      return unless major_version == 1 && minor_version == 0

      axes_array_offset = read_u16(data, offset + 4)
      _reserved = read_u16(data, offset + 6)
      @axis_count = read_u16(data, offset + 8)
      axis_size = read_u16(data, offset + 10)

      # Validate axis count
      return if @axis_count == 0 || @axis_count > 64

      # Parse variation axes
      axis_offset = offset + axes_array_offset
      @axis_count.times do |i|
        current_offset = axis_offset + i * axis_size
        break if current_offset + 20 > data.size

        tag = read_u32(data, current_offset)
        min_value = read_fixed(data, current_offset + 4)
        default_value = read_fixed(data, current_offset + 8)
        max_value = read_fixed(data, current_offset + 12)
        _flags = read_u16(data, current_offset + 16)
        _name_id = read_u16(data, current_offset + 18)

        axis = VariationAxis.new(tag, min_value, default_value, max_value)
        @axes << axis
      end
    end

    private def read_u16(data : Bytes, offset : Int32) : UInt16
      (data[offset].to_u16 << 8) | data[offset + 1].to_u16
    end

    private def read_u32(data : Bytes, offset : Int32) : UInt32
      (data[offset].to_u32 << 24) | (data[offset + 1].to_u32 << 16) |
        (data[offset + 2].to_u32 << 8) | data[offset + 3].to_u32
    end

    private def read_fixed(data : Bytes, offset : Int32) : Float32
      # Read 16.16 fixed-point number
      value = read_u32(data, offset).to_i32
      (value.to_f / 65536.0).to_f32
    end
  end

  # Load a variable font from TrueType font
  def self.load(font : FreeType::TrueType::Font) : Font
    Font.new(font)
  end

  # Load a variable font from file
  def self.load(path : String) : Font
    ttf = FreeType::TrueType.load(path)
    Font.new(ttf)
  end
end
