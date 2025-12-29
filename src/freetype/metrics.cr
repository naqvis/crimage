require "./truetype/truetype"

# Extended font metrics for precise typography.
#
# Extracts detailed typographic metrics from TrueType font tables (post, OS/2, hhea)
# including underline position, strikeout position, x-height, cap height, and more.
#
# These metrics are used internally for text decorations and are available for
# advanced typography applications.
module FreeType::Metrics
  # Extended typographic metrics from font tables.
  #
  # Contains measurements for text decorations, subscripts, superscripts,
  # and other typographic features. All values are in font units and must
  # be scaled to the desired font size.
  struct ExtendedMetrics
    # Underline metrics (from post table)
    property underline_position : Int16 = 0
    property underline_thickness : Int16 = 0

    # Strikeout metrics (from OS/2 table)
    property strikeout_position : Int16 = 0
    property strikeout_size : Int16 = 0

    # Additional OS/2 metrics
    property x_height : Int16 = 0   # Height of lowercase 'x'
    property cap_height : Int16 = 0 # Height of uppercase letters
    property subscript_x_size : Int16 = 0
    property subscript_y_size : Int16 = 0
    property subscript_x_offset : Int16 = 0
    property subscript_y_offset : Int16 = 0
    property superscript_x_size : Int16 = 0
    property superscript_y_size : Int16 = 0
    property superscript_x_offset : Int16 = 0
    property superscript_y_offset : Int16 = 0

    # Line gap (additional spacing between lines)
    property line_gap : Int16 = 0

    def initialize
    end
  end

  # Font with extended metrics
  class Font
    getter font : FreeType::TrueType::Font
    getter metrics : ExtendedMetrics

    def initialize(@font)
      @metrics = ExtendedMetrics.new
      parse_post_table
      parse_os2_table
      parse_hhea_table
    end

    # Get scaled underline position for given font size
    def underline_position(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.underline_position.to_i32 * scale) // 64).to_i32
    end

    # Get scaled underline thickness for given font size
    def underline_thickness(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.underline_thickness.to_i32 * scale) // 64).to_i32
    end

    # Get scaled strikeout position for given font size
    def strikeout_position(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.strikeout_position.to_i32 * scale) // 64).to_i32
    end

    # Get scaled strikeout size for given font size
    def strikeout_size(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.strikeout_size.to_i32 * scale) // 64).to_i32
    end

    # Get scaled x-height for given font size
    def x_height(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.x_height.to_i32 * scale) // 64).to_i32
    end

    # Get scaled cap height for given font size
    def cap_height(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.cap_height.to_i32 * scale) // 64).to_i32
    end

    # Get scaled line gap for given font size
    def line_gap(size : Float64) : Int32
      scale = (size * 64.0 / @font.units_per_em).to_i32
      ((@metrics.line_gap.to_i32 * scale) // 64).to_i32
    end

    private def parse_post_table
      # Find post table
      data = @font.data
      base_offset = @font.@base_offset

      return if data.size < base_offset + 12

      version = read_u32(data, base_offset)
      return unless version == 0x00010000 || version == 0x74727565

      num_tables = read_u16(data, base_offset + 4)

      # Find post table
      post_offset = 0
      (base_offset + 12).step(by: 16, to: base_offset + 12 + num_tables * 16 - 1) do |offset|
        break if offset + 16 > data.size

        tag = String.new(data[offset, 4])
        next unless tag == "post"

        post_offset = read_u32(data, offset + 8).to_i
        break
      end

      return if post_offset == 0 || post_offset + 32 > data.size

      # Parse post table
      # Skip version (4 bytes) and italic angle (4 bytes)
      @metrics.underline_position = read_i16(data, post_offset + 8)
      @metrics.underline_thickness = read_i16(data, post_offset + 10)
    end

    private def parse_os2_table
      return if @font.@os2 == 0

      offset = @font.@os2
      data = @font.data

      # Validate OS/2 table size (version 0 is 78 bytes minimum)
      return if offset + 78 > data.size

      version = read_u16(data, offset)

      # Parse common fields (present in all versions)
      @metrics.strikeout_size = read_i16(data, offset + 26)
      @metrics.strikeout_position = read_i16(data, offset + 28)

      # Version 2+ has x_height and cap_height
      if version >= 2 && offset + 96 > data.size
        return
      end

      if version >= 2
        @metrics.x_height = read_i16(data, offset + 86)
        @metrics.cap_height = read_i16(data, offset + 88)
      end

      # Subscript/superscript metrics (all versions)
      @metrics.subscript_x_size = read_i16(data, offset + 10)
      @metrics.subscript_y_size = read_i16(data, offset + 12)
      @metrics.subscript_x_offset = read_i16(data, offset + 14)
      @metrics.subscript_y_offset = read_i16(data, offset + 16)
      @metrics.superscript_x_size = read_i16(data, offset + 18)
      @metrics.superscript_y_size = read_i16(data, offset + 20)
      @metrics.superscript_x_offset = read_i16(data, offset + 22)
      @metrics.superscript_y_offset = read_i16(data, offset + 24)
    end

    private def parse_hhea_table
      return if @font.@hhea == 0

      offset = @font.@hhea
      data = @font.data

      return if offset + 36 > data.size

      # Line gap is at offset 8
      @metrics.line_gap = read_i16(data, offset + 8)
    end

    private def read_u16(data : Bytes, offset : Int32) : UInt16
      (data[offset].to_u16 << 8) | data[offset + 1].to_u16
    end

    private def read_u32(data : Bytes, offset : Int32) : UInt32
      (data[offset].to_u32 << 24) | (data[offset + 1].to_u32 << 16) |
        (data[offset + 2].to_u32 << 8) | data[offset + 3].to_u32
    end

    private def read_i16(data : Bytes, offset : Int32) : Int16
      val = read_u16(data, offset)
      val > 0x7FFF ? (val.to_i32 - 0x10000).to_i16 : val.to_i16
    end
  end

  # Load font with extended metrics
  def self.load(font : FreeType::TrueType::Font) : Font
    Font.new(font)
  end

  # Load font from file with extended metrics
  def self.load(path : String) : Font
    ttf = FreeType::TrueType.load(path)
    Font.new(ttf)
  end
end
