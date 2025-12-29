require "../../crimage/font/font"
require "../../crimage/math/fixed"
require "../raster/raster"

# CFF (Compact Font Format) support for OpenType fonts
# CFF fonts use PostScript-style cubic Bézier curves instead of TrueType's quadratic curves
module FreeType::CFF
  alias Fixed = CrImage::Math::Fixed

  # Font represents an OpenType font with CFF outlines
  class Font
    getter data : Bytes
    getter units_per_em : Int32
    getter ascent : Int32
    getter descent : Int32
    getter num_glyphs : Int32

    # Font tables offsets
    @cff : Int32 = 0
    @cmap : Int32 = 0
    @head : Int32 = 0
    @hhea : Int32 = 0
    @hmtx : Int32 = 0
    @maxp : Int32 = 0
    @name : Int32 = 0
    @os2 : Int32 = 0

    @units_per_em : Int32 = 0
    @ascent : Int32 = 0
    @descent : Int32 = 0
    @num_glyphs : Int32 = 0
    @num_hmetrics : Int32 = 0

    def initialize(@data)
      parse_font
    end

    def is_cff? : Bool
      @cff != 0
    end

    private def parse_font
      # Check for OpenType signature (OTTO for CFF)
      version = read_u32(0)
      is_otto = version == 0x4F54544F                          # 'OTTO'
      is_true = version == 0x00010000 || version == 0x74727565 # TrueType

      raise CrImage::FormatError.new("Invalid font signature") unless is_otto || is_true

      num_tables = read_u16(4)

      # Find tables
      12.step(by: 16, to: 12 + num_tables * 16 - 1) do |offset|
        tag = String.new(@data[offset, 4])
        table_offset = read_u32(offset + 8).to_i

        case tag
        when "CFF " then @cff = table_offset
        when "cmap" then @cmap = table_offset
        when "head" then @head = table_offset
        when "hhea" then @hhea = table_offset
        when "hmtx" then @hmtx = table_offset
        when "maxp" then @maxp = table_offset
        when "name" then @name = table_offset
        when "OS/2" then @os2 = table_offset
        end
      end

      raise CrImage::FormatError.new("Missing required font tables") if @head == 0 || @maxp == 0
      raise CrImage::FormatError.new("not a CFF font") if is_true && @cff == 0

      # Parse head table
      @units_per_em = read_u16(@head + 18).to_i

      # Parse maxp table
      maxp_version = read_u32(@maxp)
      @num_glyphs = read_u16(@maxp + 4).to_i

      # Parse hhea table if present
      if @hhea != 0
        @ascent = read_i16(@hhea + 4).to_i
        @descent = read_i16(@hhea + 6).to_i
        @num_hmetrics = read_u16(@hhea + 34).to_i
      end
    end

    # Get glyph index for a character (uses same cmap as TrueType)
    def glyph_index(char : Char) : Int32
      return 0 if @cmap == 0

      # Reuse TrueType cmap parsing logic
      # This is a simplified version - in production, share code with TrueType
      num_tables = read_u16(@cmap + 2)
      offset = @cmap + 4

      num_tables.times do
        platform_id = read_u16(offset)
        encoding_id = read_u16(offset + 2)
        subtable_offset = read_u32(offset + 4)

        if (platform_id == 3 && encoding_id == 1) || (platform_id == 0 && encoding_id == 3)
          return parse_cmap_format4(@cmap + subtable_offset, char.ord)
        end

        offset += 8
      end

      0
    end

    private def parse_cmap_format4(offset : Int32, code_point : Int32) : Int32
      return 0 if offset + 14 > @data.size
      format = read_u16(offset)
      return 0 unless format == 4

      seg_count_x2 = read_u16(offset + 6)
      seg_count = seg_count_x2 // 2

      end_codes_offset = offset + 14
      start_codes_offset = end_codes_offset + seg_count_x2 + 2
      id_deltas_offset = start_codes_offset + seg_count_x2
      id_range_offsets_offset = id_deltas_offset + seg_count_x2

      seg_count.times do |i|
        return 0 if end_codes_offset + i * 2 + 2 > @data.size
        end_code = read_u16(end_codes_offset + i * 2)
        next if code_point > end_code

        return 0 if start_codes_offset + i * 2 + 2 > @data.size
        start_code = read_u16(start_codes_offset + i * 2)
        return 0 if code_point < start_code

        return 0 if id_deltas_offset + i * 2 + 2 > @data.size
        id_delta = read_i16(id_deltas_offset + i * 2)
        return 0 if id_range_offsets_offset + i * 2 + 2 > @data.size
        id_range_offset = read_u16(id_range_offsets_offset + i * 2)

        if id_range_offset == 0
          return ((code_point + id_delta) & 0xFFFF).to_i
        else
          glyph_index_offset = id_range_offsets_offset + i * 2 + id_range_offset + (code_point - start_code) * 2
          return 0 if glyph_index_offset + 2 > @data.size
          glyph_index = read_u16(glyph_index_offset)
          return 0 if glyph_index == 0
          return ((glyph_index + id_delta) & 0xFFFF).to_i
        end
      end

      0
    end

    private def read_u8(offset : Int32) : UInt8
      @data[offset]
    end

    private def read_u16(offset : Int32) : UInt16
      (@data[offset].to_u16 << 8) | @data[offset + 1].to_u16
    end

    private def read_u32(offset : Int32) : UInt32
      (@data[offset].to_u32 << 24) | (@data[offset + 1].to_u32 << 16) |
        (@data[offset + 2].to_u32 << 8) | @data[offset + 3].to_u32
    end

    private def read_i16(offset : Int32) : Int16
      val = read_u16(offset)
      val > 0x7FFF ? (val.to_i32 - 0x10000).to_i16 : val.to_i16
    end
  end

  # CharstringParser parses Type 2 charstrings (CFF format)
  class CharstringParser
    struct Command
      property operator : UInt8
      property operands : Array(Int32)

      def initialize(@operator, @operands = [] of Int32)
      end
    end

    struct ParseResult
      property commands : Array(Command)

      def initialize(@commands = [] of Command)
      end

      def has_curves? : Bool
        @commands.any? { |cmd| cmd.operator == 8 || cmd.operator == 24 || cmd.operator == 25 }
      end
    end

    def parse(charstring : Bytes) : ParseResult
      result = ParseResult.new
      stack = [] of Int32
      i = 0

      while i < charstring.size
        b = charstring[i]

        if b >= 32 && b <= 246
          # Single byte integer: -107 to 107
          stack << (b.to_i32 - 139)
          i += 1
        elsif b >= 247 && b <= 250
          # Positive two-byte integer
          return result if i + 1 >= charstring.size
          stack << ((b.to_i32 - 247) * 256 + charstring[i + 1].to_i32 + 108)
          i += 2
        elsif b >= 251 && b <= 254
          # Negative two-byte integer
          return result if i + 1 >= charstring.size
          stack << (-(b.to_i32 - 251) * 256 - charstring[i + 1].to_i32 - 108)
          i += 2
        elsif b == 255
          # Five-byte integer (16.16 fixed point, we use integer part)
          return result if i + 4 >= charstring.size
          val = (charstring[i + 1].to_i32 << 24) | (charstring[i + 2].to_i32 << 16) |
                (charstring[i + 3].to_i32 << 8) | charstring[i + 4].to_i32
          stack << (val >> 16) # Use integer part only
          i += 5
        else
          # Operator
          result.commands << Command.new(b, stack.dup)
          stack.clear
          i += 1
        end
      end

      result
    end
  end

  # CubicToQuadratic converts cubic Bézier curves to quadratic approximations
  class CubicToQuadratic
    struct QuadraticSegment
      property p0 : Fixed::Point26_6
      property p1 : Fixed::Point26_6
      property p2 : Fixed::Point26_6

      def initialize(@p0, @p1, @p2)
      end
    end

    # Convert cubic Bézier (p0, p1, p2, p3) to one or more quadratic segments
    def convert(p0 : Fixed::Point26_6, p1 : Fixed::Point26_6,
                p2 : Fixed::Point26_6, p3 : Fixed::Point26_6,
                tolerance : Float64 = 0.5) : Array(QuadraticSegment)
      segments = [] of QuadraticSegment

      # Check if curve is sharp enough to need subdivision
      # Calculate deviation of control points from line p0-p3
      dx = (p3.x - p0.x).to_i.abs
      dy = (p3.y - p0.y).to_i.abs

      d1x = (p1.x - p0.x).to_i.abs
      d1y = (p1.y - p0.y).to_i.abs
      d2x = (p3.x - p2.x).to_i.abs
      d2y = (p3.y - p2.y).to_i.abs

      max_dev = [d1x, d1y, d2x, d2y].max

      # If curve is sharp (large deviation), subdivide
      if max_dev > (tolerance * 64 * 100).to_i
        # Subdivide at t=0.5 using De Casteljau's algorithm
        m01x = (p0.x + p1.x) // 2
        m01y = (p0.y + p1.y) // 2
        m12x = (p1.x + p2.x) // 2
        m12y = (p1.y + p2.y) // 2
        m23x = (p2.x + p3.x) // 2
        m23y = (p2.y + p3.y) // 2

        m012x = (m01x + m12x) // 2
        m012y = (m01y + m12y) // 2
        m123x = (m12x + m23x) // 2
        m123y = (m12y + m23y) // 2

        m0123x = (m012x + m123x) // 2
        m0123y = (m012y + m123y) // 2

        mid = Fixed::Point26_6.new(m0123x, m0123y)
        p01 = Fixed::Point26_6.new(m01x, m01y)
        p012 = Fixed::Point26_6.new(m012x, m012y)
        p123 = Fixed::Point26_6.new(m123x, m123y)
        p23 = Fixed::Point26_6.new(m23x, m23y)

        # Recursively convert both halves
        segments.concat(convert(p0, p01, p012, mid, tolerance))
        segments.concat(convert(mid, p123, p23, p3, tolerance))
      else
        # Simple approximation: use midpoint method
        # Calculate control point for single quadratic approximation
        # Q = (3*P1 + 3*P2 - P0 - P3) / 4
        qx = (p1.x * 3 + p2.x * 3 - p0.x - p3.x) // 4
        qy = (p1.y * 3 + p2.y * 3 - p0.y - p3.y) // 4

        q = Fixed::Point26_6.new(qx, qy)

        segments << QuadraticSegment.new(p0, q, p3)
      end

      segments
    end
  end
end
