require "../../crimage/font/font"
require "../../crimage/math/fixed"
require "../raster/raster"
require "./opcodes"

# TrueType font format parser and rasterizer
# Based on the TrueType specification at https://developer.apple.com/fonts/TrueType-Reference-Manual/
module FreeType::TrueType
  alias Fixed = CrImage::Math::Fixed

  # Font represents a TrueType font
  class Font
    # Font data
    getter data : Bytes
    getter units_per_em : Int32
    getter ascent : Int32
    getter descent : Int32
    getter num_glyphs : Int32
    getter vertical_ascent : Int32
    getter vertical_descent : Int32

    # Font tables offsets
    @cmap : Int32 = 0 # Character to glyph mapping
    @glyf : Int32 = 0 # Glyph data
    @head : Int32 = 0 # Font header
    @hhea : Int32 = 0 # Horizontal header
    @hmtx : Int32 = 0 # Horizontal metrics
    @kern : Int32 = 0 # Kerning
    @loca : Int32 = 0 # Index to location
    @maxp : Int32 = 0 # Maximum profile
    @name : Int32 = 0 # Naming table
    @os2 : Int32 = 0  # OS/2 and Windows specific metrics
    @vhea : Int32 = 0 # Vertical header
    @vmtx : Int32 = 0 # Vertical metrics
    @gpos : Int32 = 0 # Glyph positioning (GPOS kerning)
    @gsub : Int32 = 0 # Glyph substitution (GSUB ligatures)

    # GPOS kerning cache (lazily built)
    @gpos_kern_cache : Hash(UInt32, Int16)? = nil

    # GSUB ligature cache (lazily built)
    # Maps first glyph -> array of {component_glyphs, ligature_glyph}
    @gsub_liga_cache : Hash(UInt16, Array(Tuple(Array(UInt16), UInt16)))? = nil

    # Font metrics
    @units_per_em : Int32 = 0
    @bounds : Fixed::Rectangle26_6 = Fixed::Rectangle26_6.zero
    @ascent : Int32 = 0
    @descent : Int32 = 0
    @num_glyphs : Int32 = 0
    @index_to_loc_format : Int32 = 0
    @num_hmetrics : Int32 = 0
    @num_vmetrics : Int32 = 0
    @vertical_ascent : Int32 = 0
    @vertical_descent : Int32 = 0
    @maxp_version : UInt32 = 0_u32

    # Glyph cache (stores GlyphData or nil for empty/invalid glyphs)
    @glyph_cache : Hash(Int32, GlyphData?) = Hash(Int32, GlyphData?).new
    @max_cache_size : Int32 = 1000 # Default cache limit

    # Base offset for TTC files
    @base_offset : Int32 = 0

    def initialize(@data, @base_offset = 0)
      parse_font
    end

    # Parse font file and locate tables
    private def parse_font
      # Validate minimum file size
      raise CrImage::FormatError.new("Font data too small") if @data.size < @base_offset + 12

      # Check for TrueType signature
      version = read_u32(@base_offset)
      raise CrImage::FormatError.new("Invalid font signature") unless version == 0x00010000 || version == 0x74727565 # 'true'

      num_tables = read_u16(@base_offset + 4)

      # Validate table directory size
      table_dir_size = @base_offset + 12 + num_tables * 16
      raise CrImage::FormatError.new("Font data too small for table directory") if @data.size < table_dir_size

      # Find required tables
      (@base_offset + 12).step(by: 16, to: @base_offset + 12 + num_tables * 16 - 1) do |offset|
        tag = String.new(@data[offset, 4])
        table_offset_u32 = read_u32(offset + 8)
        table_length = read_u32(offset + 12)

        # Validate table offset is within bounds
        if table_offset_u32 > @data.size.to_u32
          raise CrImage::FormatError.new("Table offset out of bounds")
        end

        table_offset = table_offset_u32.to_i

        # Validate table doesn't extend beyond file
        if table_offset + table_length > @data.size
          raise CrImage::FormatError.new("Table extends beyond file")
        end

        case tag
        when "cmap" then @cmap = table_offset
        when "glyf" then @glyf = table_offset
        when "head" then @head = table_offset
        when "hhea" then @hhea = table_offset
        when "hmtx" then @hmtx = table_offset
        when "kern" then @kern = table_offset
        when "loca" then @loca = table_offset
        when "maxp" then @maxp = table_offset
        when "name" then @name = table_offset
        when "OS/2" then @os2 = table_offset
        when "vhea" then @vhea = table_offset
        when "vmtx" then @vmtx = table_offset
        when "GPOS" then @gpos = table_offset
        when "GSUB" then @gsub = table_offset
        end
      end

      raise CrImage::FormatError.new("Missing required font tables") if @head == 0 || @maxp == 0 || @loca == 0

      # Validate head table size
      raise CrImage::FormatError.new("head table too small") if @head + 54 > @data.size

      # Parse head table
      @units_per_em = read_u16(@head + 18).to_i
      @index_to_loc_format = read_i16(@head + 50).to_i

      # Validate units per em
      raise CrImage::FormatError.new("Invalid units per em") if @units_per_em < 16 || @units_per_em > 16384

      # Validate maxp table size
      raise CrImage::FormatError.new("maxp table too small") if @maxp + 6 > @data.size

      # Parse maxp table
      @maxp_version = read_u32(@maxp)
      @num_glyphs = read_u16(@maxp + 4).to_i

      # Validate number of glyphs
      raise CrImage::FormatError.new("Excessive number of glyphs") if @num_glyphs > 65534

      # Parse hhea table if present
      if @hhea != 0
        raise CrImage::FormatError.new("hhea table too small") if @hhea + 36 > @data.size
        @ascent = read_i16(@hhea + 4).to_i
        @descent = read_i16(@hhea + 6).to_i
        @num_hmetrics = read_u16(@hhea + 34).to_i
      end

      # Parse vhea table if present (for vertical text layout)
      if @vhea != 0
        raise CrImage::FormatError.new("vhea table too small") if @vhea + 36 > @data.size
        @vertical_ascent = read_i16(@vhea + 4).to_i
        @vertical_descent = read_i16(@vhea + 6).to_i
        @num_vmetrics = read_u16(@vhea + 34).to_i
      end
    end

    # Get glyph index for a character
    def glyph_index(char : Char) : Int32
      return 0 if @cmap == 0

      # Find suitable cmap subtable
      num_tables = read_u16(@cmap + 2)
      offset = @cmap + 4

      # Try to find the best cmap subtable
      # Priority: Format 12 (full Unicode) > Format 4 (BMP) > Format 6 > Format 0
      best_subtable = 0
      best_priority = -1

      num_tables.times do
        platform_id = read_u16(offset)
        encoding_id = read_u16(offset + 2)
        subtable_offset = read_u32(offset + 4)

        priority = -1

        # Windows Unicode Full (3,10) - Format 12 usually
        if platform_id == 3 && encoding_id == 10
          priority = 4
          # Windows Unicode BMP (3,1) - Format 4 usually
        elsif platform_id == 3 && encoding_id == 1
          priority = 3
          # Unicode (0,3) or (0,4) - Format 4 or 6
        elsif platform_id == 0 && (encoding_id == 3 || encoding_id == 4)
          priority = 2
          # Macintosh Roman (1,0) - Format 0 or 6
        elsif platform_id == 1 && encoding_id == 0
          priority = 1
        end

        if priority > best_priority
          best_priority = priority
          best_subtable = subtable_offset.to_i
        end

        offset += 8
      end

      return 0 if best_subtable == 0

      # Parse the subtable based on its format
      parse_cmap_subtable(@cmap + best_subtable, char.ord)
    end

    # Parse cmap subtable based on format
    private def parse_cmap_subtable(offset : Int32, code_point : Int32) : Int32
      return 0 if offset + 2 > @data.size

      format = read_u16(offset)

      case format
      when 0
        parse_cmap_format0(offset, code_point)
      when 4
        parse_cmap_format4(offset, code_point)
      when 6
        parse_cmap_format6(offset, code_point)
      when 12
        parse_cmap_format12(offset, code_point)
      else
        0 # Unsupported format
      end
    end

    # Parse format 0 cmap subtable (byte encoding)
    private def parse_cmap_format0(offset : Int32, code_point : Int32) : Int32
      return 0 if offset + 6 > @data.size
      return 0 unless read_u16(offset) == 0 # Verify format

      # Format 0 only supports code points 0-255
      return 0 if code_point < 0 || code_point > 255

      # Glyph ID array starts at offset + 6
      glyph_offset = offset + 6 + code_point
      return 0 if glyph_offset >= @data.size

      @data[glyph_offset].to_i
    end

    # Parse format 4 cmap subtable
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

      # Binary search for segment
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

    # Parse format 6 cmap subtable (trimmed table)
    private def parse_cmap_format6(offset : Int32, code_point : Int32) : Int32
      return 0 if offset + 10 > @data.size
      return 0 unless read_u16(offset) == 6 # Verify format

      first_code = read_u16(offset + 6)
      entry_count = read_u16(offset + 8)

      # Check if code point is in range
      return 0 if code_point < first_code
      return 0 if code_point >= first_code + entry_count

      # Calculate offset into glyph ID array
      glyph_offset = offset + 10 + (code_point - first_code) * 2
      return 0 if glyph_offset + 2 > @data.size

      read_u16(glyph_offset).to_i
    end

    # Parse format 12 cmap subtable (segmented coverage)
    private def parse_cmap_format12(offset : Int32, code_point : Int32) : Int32
      return 0 if offset + 16 > @data.size
      return 0 unless read_u16(offset) == 12 # Verify format

      num_groups = read_u32(offset + 12)

      # Binary search through groups
      groups_offset = offset + 16
      left = 0
      right = num_groups - 1

      while left <= right
        mid = (left + right) // 2
        group_offset = groups_offset + mid * 12

        return 0 if group_offset + 12 > @data.size

        start_char_code = read_u32(group_offset)
        end_char_code = read_u32(group_offset + 4)
        start_glyph_id = read_u32(group_offset + 8)

        if code_point < start_char_code
          right = mid - 1
        elsif code_point > end_char_code
          left = mid + 1
        else
          # Found the group
          return (start_glyph_id + (code_point - start_char_code)).to_i
        end
      end

      0
    end

    # Get glyph data
    def glyph_data(glyph_index : Int32) : GlyphData?
      return @glyph_cache[glyph_index] if @glyph_cache.has_key?(glyph_index)

      if glyph_index < 0 || glyph_index >= @num_glyphs
        cache_glyph(glyph_index, nil)
        return nil
      end

      # Validate loca table access
      loca_offset = if @index_to_loc_format == 0
                      @loca + glyph_index * 2
                    else
                      @loca + glyph_index * 4
                    end

      loca_next_offset = if @index_to_loc_format == 0
                           @loca + (glyph_index + 1) * 2
                         else
                           @loca + (glyph_index + 1) * 4
                         end

      # Check bounds
      if loca_offset + 2 > @data.size
        cache_glyph(glyph_index, nil)
        return nil
      end
      if loca_next_offset + 2 > @data.size
        cache_glyph(glyph_index, nil)
        return nil
      end

      # Get glyph offset from loca table
      glyph_offset = if @index_to_loc_format == 0
                       # Short format
                       read_u16(loca_offset).to_u32 * 2
                     else
                       # Long format
                       read_u32(loca_offset)
                     end

      next_glyph_offset = if @index_to_loc_format == 0
                            read_u16(loca_next_offset).to_u32 * 2
                          else
                            read_u32(loca_next_offset)
                          end

      # Empty glyph (like space)
      if glyph_offset == next_glyph_offset
        cache_glyph(glyph_index, nil)
        return nil
      end

      # Validate glyph offset
      offset = @glyf + glyph_offset
      if offset + 10 > @data.size
        cache_glyph(glyph_index, nil)
        return nil
      end

      num_contours = read_i16(offset)

      glyph = GlyphData.new
      glyph.num_contours = num_contours.to_i
      glyph.x_min = read_i16(offset + 2)
      glyph.y_min = read_i16(offset + 4)
      glyph.x_max = read_i16(offset + 6)
      glyph.y_max = read_i16(offset + 8)

      if num_contours > 0
        # Simple glyph
        parse_simple_glyph(glyph, offset + 10)
      elsif num_contours < 0
        # Composite glyph - parse component glyphs
        parse_composite_glyph(glyph, offset + 10)
      end

      cache_glyph(glyph_index, glyph)
      glyph
    rescue IndexError
      # Handle corrupted glyph data gracefully
      cache_glyph(glyph_index, nil)
      nil
    end

    # Cache a glyph (including nil values)
    private def cache_glyph(glyph_index : Int32, glyph : GlyphData?)
      # Check cache size limit before adding
      if @glyph_cache.size >= @max_cache_size
        # Remove oldest entry (simple LRU-like behavior)
        @glyph_cache.delete(@glyph_cache.first_key)
      end

      @glyph_cache[glyph_index] = glyph
    end

    # Clear the glyph cache
    def clear_glyph_cache
      @glyph_cache.clear
    end

    # Get current cache size
    def glyph_cache_size : Int32
      @glyph_cache.size
    end

    # Set maximum cache size
    def max_cache_size=(size : Int32)
      @max_cache_size = size
      # Trim cache if it exceeds new limit
      while @glyph_cache.size > @max_cache_size
        @glyph_cache.delete(@glyph_cache.first_key)
      end
    end

    # Get maximum cache size
    def max_cache_size : Int32
      @max_cache_size
    end

    # Parse simple glyph outline
    private def parse_simple_glyph(glyph : GlyphData, offset : Int32)
      # Read end points of contours
      glyph.end_pts_of_contours = Array(Int32).new(glyph.num_contours) do |i|
        read_u16(offset + i * 2).to_i
      end

      num_points = glyph.end_pts_of_contours.last + 1
      offset += glyph.num_contours * 2

      # Skip instructions
      instruction_length = read_u16(offset)
      offset += 2 + instruction_length

      # Read flags
      flags = Array(UInt8).new(num_points, 0_u8)
      i = 0
      while i < num_points
        flag = @data[offset]
        offset += 1
        flags[i] = flag

        # Repeat flag
        if (flag & 0x08) != 0
          repeat_count = @data[offset]
          offset += 1
          repeat_count.times do
            i += 1
            flags[i] = flag if i < num_points
          end
        end
        i += 1
      end

      # Read x coordinates
      x_coords = Array(Int16).new(num_points, 0_i16)
      x = 0_i16
      num_points.times do |idx|
        flag = flags[idx]
        if (flag & 0x02) != 0
          # X is 1 byte
          dx = @data[offset].to_i16
          offset += 1
          x += (flag & 0x10) != 0 ? dx : -dx
        elsif (flag & 0x10) == 0
          # X is 2 bytes
          x += read_i16(offset)
          offset += 2
        end
        x_coords[idx] = x
      end

      # Read y coordinates
      y_coords = Array(Int16).new(num_points, 0_i16)
      y = 0_i16
      num_points.times do |idx|
        flag = flags[idx]
        if (flag & 0x04) != 0
          # Y is 1 byte
          dy = @data[offset].to_i16
          offset += 1
          y += (flag & 0x20) != 0 ? dy : -dy
        elsif (flag & 0x20) == 0
          # Y is 2 bytes
          y += read_i16(offset)
          offset += 2
        end
        y_coords[idx] = y
      end

      glyph.flags = flags
      glyph.x_coordinates = x_coords
      glyph.y_coordinates = y_coords
    end

    # Parse composite glyph (glyph made of multiple component glyphs)
    # Composite glyphs are defined in the TrueType spec and consist of
    # references to other glyphs with transformations applied.
    private def parse_composite_glyph(glyph : GlyphData, offset : Int32)
      # Composite glyph flags
      arg_1_and_2_are_words = 0x0001
      args_are_xy_values = 0x0002
      round_xy_to_grid = 0x0004
      we_have_a_scale = 0x0008
      more_components = 0x0020
      we_have_an_x_and_y_scale = 0x0040
      we_have_a_two_by_two = 0x0080
      we_have_instructions = 0x0100
      use_my_metrics = 0x0200
      overlap_compound = 0x0400

      # Accumulated contours and points from all components
      all_end_pts = [] of Int32
      all_flags = [] of UInt8
      all_x_coords = [] of Int16
      all_y_coords = [] of Int16
      point_offset = 0

      # Parse and merge all component glyphs
      loop do
        return if offset + 4 > @data.size

        flags = read_u16(offset)
        offset += 2

        component_index = read_u16(offset).to_i
        offset += 2

        # Read arguments (translation offsets or point numbers)
        arg1, arg2 = if (flags & arg_1_and_2_are_words) != 0
                       return if offset + 4 > @data.size
                       a1 = read_i16(offset)
                       a2 = read_i16(offset + 2)
                       offset += 4
                       {a1, a2}
                     else
                       return if offset + 2 > @data.size
                       a1 = @data[offset].unsafe_as(Int8).to_i16
                       a2 = @data[offset + 1].unsafe_as(Int8).to_i16
                       offset += 2
                       {a1, a2}
                     end

        # Read transformation matrix
        m00, m01, m10, m11 = 1.0, 0.0, 0.0, 1.0 # Identity matrix

        if (flags & we_have_a_scale) != 0
          return if offset + 2 > @data.size
          scale = read_i16(offset).to_f / 16384.0 # 2.14 fixed point
          m00 = m11 = scale
          offset += 2
        elsif (flags & we_have_an_x_and_y_scale) != 0
          return if offset + 4 > @data.size
          m00 = read_i16(offset).to_f / 16384.0
          m11 = read_i16(offset + 2).to_f / 16384.0
          offset += 4
        elsif (flags & we_have_a_two_by_two) != 0
          return if offset + 8 > @data.size
          m00 = read_i16(offset).to_f / 16384.0
          m01 = read_i16(offset + 2).to_f / 16384.0
          m10 = read_i16(offset + 4).to_f / 16384.0
          m11 = read_i16(offset + 6).to_f / 16384.0
          offset += 8
        end

        # Load component glyph (recursively)
        component = glyph_data(component_index)
        next unless component
        next if component.num_contours <= 0 # Skip empty or composite components

        # Apply transformation and translation to component points
        component.x_coordinates.each_with_index do |x, i|
          y = component.y_coordinates[i]

          # Apply transformation matrix
          tx = (m00 * x + m10 * y).round.to_i16
          ty = (m01 * x + m11 * y).round.to_i16

          # Apply translation (args_are_xy_values means arg1/arg2 are offsets)
          if (flags & args_are_xy_values) != 0
            tx += arg1
            ty += arg2
          end

          all_x_coords << tx
          all_y_coords << ty
        end

        # Copy flags
        all_flags.concat(component.flags)

        # Adjust end points of contours
        component.end_pts_of_contours.each do |end_pt|
          all_end_pts << (end_pt + point_offset)
        end

        point_offset += component.x_coordinates.size

        break unless (flags & more_components) != 0
      end

      # Store merged data
      glyph.end_pts_of_contours = all_end_pts
      glyph.flags = all_flags
      glyph.x_coordinates = all_x_coords
      glyph.y_coordinates = all_y_coords
      glyph.num_contours = all_end_pts.size
    end

    # Get horizontal metrics for a glyph
    def h_metrics(glyph_index : Int32) : {Int32, Int32}
      if glyph_index < @num_hmetrics
        offset = @hmtx + glyph_index * 4
        advance_width = read_u16(offset)
        left_side_bearing = read_i16(offset + 2)
      else
        # Use last advance width
        offset = @hmtx + (@num_hmetrics - 1) * 4
        advance_width = read_u16(offset)
        # Get LSB from extended table
        lsb_offset = @hmtx + @num_hmetrics * 4 + (glyph_index - @num_hmetrics) * 2
        left_side_bearing = read_i16(lsb_offset)
      end

      {advance_width.to_i, left_side_bearing.to_i}
    end

    # Check if font has vertical metrics
    def has_vertical_metrics? : Bool
      @vhea != 0 && @vmtx != 0
    end

    # Get vertical metrics for a glyph
    def v_metrics(glyph_index : Int32) : {Int32, Int32}
      return {0, 0} unless has_vertical_metrics?

      if glyph_index < @num_vmetrics
        offset = @vmtx + glyph_index * 4
        advance_height = read_u16(offset)
        top_side_bearing = read_i16(offset + 2)
      else
        # Use last advance height
        offset = @vmtx + (@num_vmetrics - 1) * 4
        advance_height = read_u16(offset)
        # Get TSB from extended table
        tsb_offset = @vmtx + @num_vmetrics * 4 + (glyph_index - @num_vmetrics) * 2
        top_side_bearing = read_i16(tsb_offset)
      end

      {advance_height.to_i, top_side_bearing.to_i}
    end

    # Check if font has GPOS table
    def has_gpos? : Bool
      @gpos != 0
    end

    # Lookup kerning value for a glyph pair
    # Tries GPOS kerning first, then falls back to legacy kern table
    def lookup_kern(glyph0 : Int32, glyph1 : Int32) : Int32
      # Try GPOS kerning first (modern fonts)
      if @gpos != 0
        gpos_kern = lookup_gpos_kern(glyph0, glyph1)
        return gpos_kern if gpos_kern != 0
      end

      # Fall back to legacy kern table
      lookup_legacy_kern(glyph0, glyph1)
    end

    # Lookup kerning from GPOS table (PairPos subtables)
    private def lookup_gpos_kern(glyph0 : Int32, glyph1 : Int32) : Int32
      # Build cache on first access
      @gpos_kern_cache ||= build_gpos_kern_cache

      cache = @gpos_kern_cache.not_nil!
      key = (glyph0.to_u32 << 16) | glyph1.to_u32
      cache[key]?.try(&.to_i32) || 0
    end

    # Build a cache of all GPOS kerning pairs
    private def build_gpos_kern_cache : Hash(UInt32, Int16)
      cache = Hash(UInt32, Int16).new
      return cache if @gpos == 0

      # GPOS header
      return cache if @gpos + 10 > @data.size

      major_version = read_u16(@gpos)
      return cache unless major_version == 1

      script_list_offset = read_u16(@gpos + 4)
      feature_list_offset = read_u16(@gpos + 6)
      lookup_list_offset = read_u16(@gpos + 8)

      # Find kern feature lookup indices
      kern_lookup_indices = find_kern_feature_lookups(@gpos + feature_list_offset.to_i)
      return cache if kern_lookup_indices.empty?

      # Parse lookup list
      lookup_list_abs = @gpos + lookup_list_offset.to_i
      return cache if lookup_list_abs + 2 > @data.size

      lookup_count = read_u16(lookup_list_abs)

      kern_lookup_indices.each do |lookup_idx|
        next if lookup_idx >= lookup_count

        lookup_offset_rel = read_u16(lookup_list_abs + 2 + lookup_idx * 2)
        lookup_abs = lookup_list_abs + lookup_offset_rel.to_i

        parse_gpos_lookup(lookup_abs, cache)
      end

      cache
    end

    # Find lookup indices for 'kern' feature
    private def find_kern_feature_lookups(feature_list_offset : Int32) : Array(Int32)
      indices = [] of Int32
      return indices if feature_list_offset + 2 > @data.size

      feature_count = read_u16(feature_list_offset)
      return indices if feature_count > 200

      feature_count.times do |i|
        record_offset = feature_list_offset + 2 + i * 6
        break if record_offset + 6 > @data.size

        tag = read_u32(record_offset)
        # 'kern' = 0x6B65726E
        if tag == 0x6B65726E_u32
          feature_offset = read_u16(record_offset + 4)
          feature_abs = feature_list_offset + feature_offset.to_i

          return indices if feature_abs + 4 > @data.size

          _feature_params = read_u16(feature_abs)
          lookup_index_count = read_u16(feature_abs + 2)

          lookup_index_count.times do |j|
            break if feature_abs + 4 + j * 2 + 2 > @data.size
            indices << read_u16(feature_abs + 4 + j * 2).to_i
          end
        end
      end

      indices
    end

    # Parse a GPOS lookup table for kerning pairs
    private def parse_gpos_lookup(lookup_offset : Int32, cache : Hash(UInt32, Int16))
      return if lookup_offset + 6 > @data.size

      lookup_type = read_u16(lookup_offset)
      _lookup_flag = read_u16(lookup_offset + 2)
      subtable_count = read_u16(lookup_offset + 4)

      # Handle Extension Positioning (type 9)
      actual_type = lookup_type
      extension_offset = 0

      subtable_count.times do |i|
        subtable_rel = read_u16(lookup_offset + 6 + i * 2)
        subtable_abs = lookup_offset + subtable_rel.to_i

        if lookup_type == 9
          # Extension Positioning
          return if subtable_abs + 8 > @data.size
          format = read_u16(subtable_abs)
          next unless format == 1

          actual_type = read_u16(subtable_abs + 2)
          extension_offset = read_u32(subtable_abs + 4).to_i
          subtable_abs = subtable_abs + extension_offset
        end

        # Only handle PairPos (type 2)
        next unless actual_type == 2

        parse_pair_pos_subtable(subtable_abs, cache)
      end
    end

    # Parse PairPos subtable (GPOS lookup type 2)
    private def parse_pair_pos_subtable(subtable_offset : Int32, cache : Hash(UInt32, Int16))
      return if subtable_offset + 8 > @data.size

      format = read_u16(subtable_offset)
      coverage_offset = read_u16(subtable_offset + 2)
      value_format1 = read_u16(subtable_offset + 4)
      value_format2 = read_u16(subtable_offset + 6)

      # We only care about X advance adjustment in value_format1
      # value_format1 bit 2 (0x0004) = XAdvance
      return unless (value_format1 & 0x0004) != 0

      value_record1_size = count_value_record_size(value_format1)
      value_record2_size = count_value_record_size(value_format2)

      # Get coverage table (maps glyph IDs to coverage indices)
      coverage_abs = subtable_offset + coverage_offset.to_i
      coverage = parse_coverage_table(coverage_abs)

      case format
      when 1
        parse_pair_pos_format1(subtable_offset, coverage, value_format1, value_record1_size, value_record2_size, cache)
      when 2
        parse_pair_pos_format2(subtable_offset, coverage, value_format1, value_record1_size, value_record2_size, cache)
      end
    end

    # Count bytes in a value record based on format flags
    private def count_value_record_size(format : UInt16) : Int32
      size = 0
      size += 2 if (format & 0x0001) != 0 # XPlacement
      size += 2 if (format & 0x0002) != 0 # YPlacement
      size += 2 if (format & 0x0004) != 0 # XAdvance
      size += 2 if (format & 0x0008) != 0 # YAdvance
      size += 2 if (format & 0x0010) != 0 # XPlaDevice
      size += 2 if (format & 0x0020) != 0 # YPlaDevice
      size += 2 if (format & 0x0040) != 0 # XAdvDevice
      size += 2 if (format & 0x0080) != 0 # YAdvDevice
      size
    end

    # Extract XAdvance from a value record
    private def extract_x_advance(offset : Int32, format : UInt16) : Int16
      pos = offset
      pos += 2 if (format & 0x0001) != 0 # Skip XPlacement
      pos += 2 if (format & 0x0002) != 0 # Skip YPlacement

      if (format & 0x0004) != 0
        return read_i16(pos)
      end

      0_i16
    end

    # Parse coverage table
    private def parse_coverage_table(offset : Int32) : Hash(UInt16, Int32)
      coverage = Hash(UInt16, Int32).new
      return coverage if offset + 4 > @data.size

      format = read_u16(offset)

      case format
      when 1
        # Coverage Format 1: list of glyph IDs
        glyph_count = read_u16(offset + 2)
        glyph_count.times do |i|
          break if offset + 4 + i * 2 + 2 > @data.size
          glyph_id = read_u16(offset + 4 + i * 2)
          coverage[glyph_id] = i.to_i
        end
      when 2
        # Coverage Format 2: ranges
        range_count = read_u16(offset + 2)
        range_count.times do |i|
          range_offset = offset + 4 + i * 6
          break if range_offset + 6 > @data.size

          start_glyph = read_u16(range_offset)
          end_glyph = read_u16(range_offset + 2)
          start_coverage_index = read_u16(range_offset + 4)

          (start_glyph..end_glyph).each_with_index do |glyph, j|
            coverage[glyph.to_u16] = start_coverage_index.to_i + j.to_i
          end
        end
      end

      coverage
    end

    # Parse PairPos Format 1 (individual glyph pairs)
    private def parse_pair_pos_format1(subtable_offset : Int32, coverage : Hash(UInt16, Int32),
                                       value_format1 : UInt16, value_record1_size : Int32,
                                       value_record2_size : Int32, cache : Hash(UInt32, Int16))
      return if subtable_offset + 10 > @data.size

      pair_set_count = read_u16(subtable_offset + 8)

      coverage.each do |first_glyph, coverage_index|
        next if coverage_index >= pair_set_count

        pair_set_offset_rel = read_u16(subtable_offset + 10 + coverage_index * 2)
        pair_set_abs = subtable_offset + pair_set_offset_rel.to_i

        next if pair_set_abs + 2 > @data.size

        pair_value_count = read_u16(pair_set_abs)
        pair_value_record_size = 2 + value_record1_size + value_record2_size

        pair_value_count.times do |i|
          record_offset = pair_set_abs + 2 + i * pair_value_record_size
          break if record_offset + pair_value_record_size > @data.size

          second_glyph = read_u16(record_offset)
          x_advance = extract_x_advance(record_offset + 2, value_format1)

          if x_advance != 0
            key = (first_glyph.to_u32 << 16) | second_glyph.to_u32
            cache[key] = x_advance
          end
        end
      end
    end

    # Parse PairPos Format 2 (class-based pairs)
    private def parse_pair_pos_format2(subtable_offset : Int32, coverage : Hash(UInt16, Int32),
                                       value_format1 : UInt16, value_record1_size : Int32,
                                       value_record2_size : Int32, cache : Hash(UInt32, Int16))
      return if subtable_offset + 16 > @data.size

      class_def1_offset = read_u16(subtable_offset + 8)
      class_def2_offset = read_u16(subtable_offset + 10)
      class1_count = read_u16(subtable_offset + 12)
      class2_count = read_u16(subtable_offset + 14)

      class_def1 = parse_class_def_table(subtable_offset + class_def1_offset.to_i)
      class_def2 = parse_class_def_table(subtable_offset + class_def2_offset.to_i)

      class2_record_size = value_record1_size + value_record2_size
      class1_record_size = class2_count.to_i * class2_record_size

      # For each glyph in coverage, find its class and look up kerning
      coverage.each do |first_glyph, _|
        class1 = class_def1[first_glyph]? || 0

        # For each possible second glyph class
        class_def2.each do |second_glyph, class2|
          record_offset = subtable_offset + 16 + class1 * class1_record_size + class2 * class2_record_size
          next if record_offset + class2_record_size > @data.size

          x_advance = extract_x_advance(record_offset, value_format1)

          if x_advance != 0
            key = (first_glyph.to_u32 << 16) | second_glyph.to_u32
            cache[key] = x_advance
          end
        end
      end
    end

    # Parse ClassDef table
    private def parse_class_def_table(offset : Int32) : Hash(UInt16, Int32)
      class_def = Hash(UInt16, Int32).new
      return class_def if offset + 4 > @data.size

      format = read_u16(offset)

      case format
      when 1
        # ClassDef Format 1: range of glyphs
        start_glyph = read_u16(offset + 2)
        glyph_count = read_u16(offset + 4)

        glyph_count.times do |i|
          break if offset + 6 + i * 2 + 2 > @data.size
          class_value = read_u16(offset + 6 + i * 2)
          class_def[(start_glyph + i).to_u16] = class_value.to_i
        end
      when 2
        # ClassDef Format 2: ranges
        range_count = read_u16(offset + 2)

        range_count.times do |i|
          range_offset = offset + 4 + i * 6
          break if range_offset + 6 > @data.size

          start_glyph = read_u16(range_offset)
          end_glyph = read_u16(range_offset + 2)
          class_value = read_u16(range_offset + 4)

          (start_glyph..end_glyph).each do |glyph|
            class_def[glyph.to_u16] = class_value.to_i
          end
        end
      end

      class_def
    end

    # Lookup kerning from legacy kern table
    private def lookup_legacy_kern(glyph0 : Int32, glyph1 : Int32) : Int32
      return 0 if @kern == 0

      # Read kern table header
      version = read_u16(@kern)
      return 0 if version != 0 # Only support version 0

      n_tables = read_u16(@kern + 2)
      offset = @kern + 4

      # Search through subtables for format 0
      n_tables.times do
        return 0 if offset + 6 > @data.size

        subtable_version = read_u16(offset)
        length = read_u16(offset + 2)
        coverage = read_u16(offset + 4)

        # Check if this is a horizontal kerning table (bit 0 = 1) and format 0 (bits 8-15 = 0)
        format = (coverage >> 8) & 0xFF
        horizontal = (coverage & 0x01) != 0

        if format == 0 && horizontal
          # Format 0: sorted list of kerning pairs
          n_pairs = read_u16(offset + 6)
          pairs_offset = offset + 14

          # Binary search for the kerning pair
          left = 0
          right = n_pairs - 1

          while left <= right
            mid = (left + right) // 2
            pair_offset = pairs_offset + mid * 6

            return 0 if pair_offset + 6 > @data.size

            pair_left = read_u16(pair_offset)
            pair_right = read_u16(pair_offset + 2)

            if pair_left == glyph0 && pair_right == glyph1
              # Found the pair, return kerning value
              return read_i16(pair_offset + 4).to_i
            elsif pair_left < glyph0 || (pair_left == glyph0 && pair_right < glyph1)
              left = mid + 1
            else
              right = mid - 1
            end
          end
        end

        offset += length
      end

      0 # No kerning found
    end

    # Check if font has GSUB table
    def has_gsub? : Bool
      @gsub != 0
    end

    # Lookup ligature substitution for a glyph sequence
    # Returns {ligature_glyph, components_consumed} or {0, 0} if no ligature found
    def lookup_ligature(glyphs : Array(UInt16), start_index : Int32 = 0) : {UInt16, Int32}
      return {0_u16, 0} if @gsub == 0
      return {0_u16, 0} if start_index >= glyphs.size

      # Build cache on first access
      @gsub_liga_cache ||= build_gsub_liga_cache

      cache = @gsub_liga_cache.not_nil!
      first_glyph = glyphs[start_index]

      # Check if first glyph has any ligatures
      ligatures = cache[first_glyph]?
      return {0_u16, 0} unless ligatures

      # Try to match ligatures (longer matches first - they're sorted by component count)
      ligatures.each do |components, lig_glyph|
        # Check if we have enough glyphs remaining
        next if start_index + 1 + components.size > glyphs.size

        # Check if components match
        match = true
        components.each_with_index do |comp, i|
          if glyphs[start_index + 1 + i] != comp
            match = false
            break
          end
        end

        if match
          # Return ligature glyph and number of glyphs consumed (1 + components)
          return {lig_glyph, 1 + components.size}
        end
      end

      {0_u16, 0}
    end

    # Build cache of all ligatures from GSUB 'liga' feature
    private def build_gsub_liga_cache : Hash(UInt16, Array(Tuple(Array(UInt16), UInt16)))
      cache = Hash(UInt16, Array(Tuple(Array(UInt16), UInt16))).new
      return cache if @gsub == 0

      # GSUB header
      return cache if @gsub + 10 > @data.size

      major_version = read_u16(@gsub)
      return cache unless major_version == 1

      feature_list_offset = read_u16(@gsub + 6)
      lookup_list_offset = read_u16(@gsub + 8)

      # Find 'liga' feature lookup indices
      liga_lookup_indices = find_gsub_feature_lookups(@gsub + feature_list_offset.to_i, 0x6C696761_u32) # 'liga'
      return cache if liga_lookup_indices.empty?

      # Parse lookup list
      lookup_list_abs = @gsub + lookup_list_offset.to_i
      return cache if lookup_list_abs + 2 > @data.size

      lookup_count = read_u16(lookup_list_abs)

      liga_lookup_indices.each do |lookup_idx|
        next if lookup_idx >= lookup_count

        lookup_offset_rel = read_u16(lookup_list_abs + 2 + lookup_idx * 2)
        lookup_abs = lookup_list_abs + lookup_offset_rel.to_i

        parse_gsub_ligature_lookup(lookup_abs, cache)
      end

      # Sort ligatures by component count (descending) for greedy matching
      cache.each do |_, ligatures|
        ligatures.sort_by! { |components, _| -components.size }
      end

      cache
    end

    # Find lookup indices for a GSUB feature by tag
    private def find_gsub_feature_lookups(feature_list_offset : Int32, feature_tag : UInt32) : Array(Int32)
      indices = [] of Int32
      return indices if feature_list_offset + 2 > @data.size

      feature_count = read_u16(feature_list_offset)
      return indices if feature_count > 200

      feature_count.times do |i|
        record_offset = feature_list_offset + 2 + i * 6
        break if record_offset + 6 > @data.size

        tag = read_u32(record_offset)
        if tag == feature_tag
          feature_offset = read_u16(record_offset + 4)
          feature_abs = feature_list_offset + feature_offset.to_i

          return indices if feature_abs + 4 > @data.size

          lookup_index_count = read_u16(feature_abs + 2)

          lookup_index_count.times do |j|
            break if feature_abs + 4 + j * 2 + 2 > @data.size
            idx = read_u16(feature_abs + 4 + j * 2).to_i
            indices << idx unless indices.includes?(idx)
          end
        end
      end

      indices
    end

    # Parse a GSUB ligature lookup (type 4)
    private def parse_gsub_ligature_lookup(lookup_offset : Int32, cache : Hash(UInt16, Array(Tuple(Array(UInt16), UInt16))))
      return if lookup_offset + 6 > @data.size

      lookup_type = read_u16(lookup_offset)
      subtable_count = read_u16(lookup_offset + 4)

      # Handle Extension Substitution (type 7)
      if lookup_type == 7
        subtable_count.times do |i|
          subtable_rel = read_u16(lookup_offset + 6 + i * 2)
          subtable_abs = lookup_offset + subtable_rel.to_i

          return if subtable_abs + 8 > @data.size
          format = read_u16(subtable_abs)
          next unless format == 1

          actual_type = read_u16(subtable_abs + 2)
          next unless actual_type == 4 # Ligature

          extension_offset = read_u32(subtable_abs + 4).to_i
          parse_ligature_subtable(subtable_abs + extension_offset, cache)
        end
        return
      end

      # Only handle Ligature lookup (type 4)
      return unless lookup_type == 4

      subtable_count.times do |i|
        subtable_rel = read_u16(lookup_offset + 6 + i * 2)
        subtable_abs = lookup_offset + subtable_rel.to_i
        parse_ligature_subtable(subtable_abs, cache)
      end
    end

    # Parse a ligature substitution subtable
    private def parse_ligature_subtable(subtable_offset : Int32, cache : Hash(UInt16, Array(Tuple(Array(UInt16), UInt16))))
      return if subtable_offset + 6 > @data.size

      format = read_u16(subtable_offset)
      return unless format == 1 # Only format 1 exists for ligatures

      coverage_offset = read_u16(subtable_offset + 2)
      lig_set_count = read_u16(subtable_offset + 4)

      # Parse coverage table to get first glyphs
      coverage_abs = subtable_offset + coverage_offset.to_i
      coverage = parse_coverage_table(coverage_abs)

      # Parse ligature sets
      coverage.each do |first_glyph, coverage_index|
        next if coverage_index >= lig_set_count

        lig_set_offset = read_u16(subtable_offset + 6 + coverage_index * 2)
        lig_set_abs = subtable_offset + lig_set_offset.to_i

        next if lig_set_abs + 2 > @data.size

        lig_count = read_u16(lig_set_abs)

        lig_count.times do |i|
          lig_offset = read_u16(lig_set_abs + 2 + i * 2)
          lig_abs = lig_set_abs + lig_offset.to_i

          next if lig_abs + 4 > @data.size

          lig_glyph = read_u16(lig_abs)
          comp_count = read_u16(lig_abs + 2)

          # comp_count includes the first glyph, so components = comp_count - 1
          next if comp_count < 2
          components = Array(UInt16).new(comp_count - 1) do |j|
            read_u16(lig_abs + 4 + j * 2)
          end

          # Add to cache
          cache[first_glyph] ||= [] of Tuple(Array(UInt16), UInt16)
          cache[first_glyph] << {components, lig_glyph}
        end
      end
    end

    # Helper methods to read font data
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
      # Reinterpret UInt16 as Int16 (two's complement)
      val > 0x7FFF ? (val.to_i32 - 0x10000).to_i16 : val.to_i16
    end

    private def read_i32(offset : Int32) : Int32
      val = read_u32(offset)
      # Reinterpret UInt32 as Int32 (two's complement)
      val > 0x7FFFFFFF ? (val.to_i64 - 0x100000000).to_i32 : val.to_i32
    end
  end

  # Glyph outline data
  class GlyphData
    property num_contours : Int32 = 0
    property x_min : Int16 = 0
    property y_min : Int16 = 0
    property x_max : Int16 = 0
    property y_max : Int16 = 0
    property end_pts_of_contours : Array(Int32) = [] of Int32
    property flags : Array(UInt8) = [] of UInt8
    property x_coordinates : Array(Int16) = [] of Int16
    property y_coordinates : Array(Int16) = [] of Int16

    def initialize
    end
  end

  # TrueType font face implementation
  class Face
    include CrImage::Font::Face

    getter font : Font
    getter scale : Fixed::Int26_6
    getter hinting : CrImage::Font::Hinting

    # Rasterizer for rendering glyphs
    @rasterizer : FreeType::Raster::Rasterizer
    # Glyph mask buffer
    @mask : CrImage::Alpha

    def initialize(@font, size : Float64, @hinting = CrImage::Font::Hinting::None)
      # Calculate scale from font units to pixels (in 26.6 fixed point)
      # We want: (font_units * scale) / 64 = pixels_in_26.6_format
      # So: scale = (pixels * 64) / font_units = (size * 64) / units_per_em
      # This scale is NOT in 26.6 format - it's a raw multiplier
      @scale = Fixed::Int26_6[((size * 64.0) / @font.units_per_em * 64.0).round.to_i]

      @rasterizer = FreeType::Raster::Rasterizer.new
      @rasterizer.use_non_zero_winding = true # TrueType fonts use non-zero winding rule
      @mask = CrImage::Alpha.new(CrImage.rect(0, 0, 0, 0))
    end

    def glyph(dot : Fixed::Point26_6, r : Char) : {CrImage::Rectangle, CrImage::Image, CrImage::Point, Fixed::Int26_6, Bool}
      glyph_index = @font.glyph_index(r)
      glyph_by_index(dot, glyph_index)
    end

    # Render a glyph by its index (used for ligature substitution)
    def glyph_by_index(dot : Fixed::Point26_6, glyph_index : Int32) : {CrImage::Rectangle, CrImage::Image, CrImage::Point, Fixed::Int26_6, Bool}
      return {CrImage::Rectangle.zero, @mask, CrImage::Point.zero, Fixed::Int26_6[0], false} if glyph_index == 0

      advance_width, lsb = @font.h_metrics(glyph_index)
      advance = (@scale * advance_width) // 64

      glyph_data = @font.glyph_data(glyph_index)
      # For glyphs with no outline (like space), return advance but ok=false
      return {CrImage::Rectangle.zero, @mask, CrImage::Point.zero, advance, false} unless glyph_data
      # Calculate glyph bounds in pixels
      # Use x_min/x_max from glyph data for consistent bounds (not lsb which may differ)
      x0 = (dot.x + (@scale * glyph_data.x_min) // 64).floor
      y0 = (dot.y - (@scale * glyph_data.y_max) // 64).floor
      x1 = (dot.x + (@scale * glyph_data.x_max) // 64).ceil
      y1 = (dot.y - (@scale * glyph_data.y_min) // 64).ceil

      dr = CrImage.rect(x0, y0, x1, y1)

      # Always create a new mask with the exact size needed for this glyph
      # (Reusing masks with different sizes causes clipping issues)
      @mask = CrImage::Alpha.new(CrImage.rect(0, 0, dr.width, dr.height))

      # Rasterize glyph
      rasterize_glyph(glyph_data, dot, lsb)

      {dr, @mask, CrImage::Point.zero, advance, true}
    end

    def glyph_bounds(r : Char) : {Fixed::Rectangle26_6, Fixed::Int26_6, Bool}
      glyph_index = @font.glyph_index(r)
      return {Fixed::Rectangle26_6.zero, Fixed::Int26_6[0], false} if glyph_index == 0

      glyph_data = @font.glyph_data(glyph_index)
      return {Fixed::Rectangle26_6.zero, Fixed::Int26_6[0], false} unless glyph_data

      advance_width, lsb = @font.h_metrics(glyph_index)

      bounds = Fixed::Rectangle26_6.new(
        Fixed::Point26_6.new(
          (@scale * lsb) // 64,
          -(@scale * glyph_data.y_max) // 64
        ),
        Fixed::Point26_6.new(
          (@scale * glyph_data.x_max) // 64,
          -(@scale * glyph_data.y_min) // 64
        )
      )

      advance = (@scale * advance_width) // 64

      {bounds, advance, true}
    end

    def glyph_advance(r : Char) : {Fixed::Int26_6, Bool}
      glyph_index = @font.glyph_index(r)
      return {Fixed::Int26_6[0], false} if glyph_index == 0

      advance_width, _ = @font.h_metrics(glyph_index)
      advance = (@scale * advance_width) // 64

      {advance, true}
    end

    def kern(r0 : Char, r1 : Char) : Fixed::Int26_6
      # Kerning support - returns horizontal adjustment for glyph pairs
      # Check if font has any kerning (legacy kern or GPOS)
      return Fixed::Int26_6[0] if @font.@kern == 0 && @font.@gpos == 0

      glyph0 = @font.glyph_index(r0)
      glyph1 = @font.glyph_index(r1)
      return Fixed::Int26_6[0] if glyph0 == 0 || glyph1 == 0

      kern_value = @font.lookup_kern(glyph0, glyph1)
      return Fixed::Int26_6[0] if kern_value == 0

      # Scale kerning value by font size
      (@scale * kern_value) // 64
    end

    # Kerning by glyph index (used for ligature substitution)
    def kern_by_index(glyph0 : Int32, glyph1 : Int32) : Fixed::Int26_6
      return Fixed::Int26_6[0] if @font.@kern == 0 && @font.@gpos == 0
      return Fixed::Int26_6[0] if glyph0 == 0 || glyph1 == 0

      kern_value = @font.lookup_kern(glyph0, glyph1)
      return Fixed::Int26_6[0] if kern_value == 0

      (@scale * kern_value) // 64
    end

    def metrics : CrImage::Font::Metrics
      ascent = (@scale * @font.@ascent) // 64
      descent = (@scale * -@font.@descent) // 64
      height = ascent + descent

      CrImage::Font::Metrics.new(
        height: height,
        ascent: ascent,
        descent: descent,
        x_height: ascent // 2, # Approximate
        cap_height: ascent,    # Approximate
        caret_slope: CrImage::Point.new(0, 1)
      )
    end

    # Returns true if this face supports ligature substitution
    def supports_ligatures? : Bool
      @font.has_gsub?
    end

    # Convert a character to its glyph index
    def glyph_index(r : Char) : Int32
      @font.glyph_index(r)
    end

    # Lookup ligature substitution for a glyph sequence
    def lookup_ligature(glyphs : Array(UInt16), start_index : Int32 = 0) : {UInt16, Int32}
      @font.lookup_ligature(glyphs, start_index)
    end

    # Check if font has vertical metrics (for vertical text layout)
    def has_vertical_metrics? : Bool
      @font.has_vertical_metrics?
    end

    # Get vertical advance for a glyph (used for vertical text layout)
    def vertical_advance(r : Char) : {Fixed::Int26_6, Bool}
      glyph_index = @font.glyph_index(r)
      return {Fixed::Int26_6[0], false} if glyph_index == 0

      advance_height, _ = @font.v_metrics(glyph_index)
      # If no vertical metrics, use line height (ascent - descent) as fallback
      # This gives proper spacing for vertical text in fonts without vmtx
      if advance_height == 0
        advance_height = @font.ascent - @font.descent
      end

      advance = (@scale * advance_height) // 64
      {advance, true}
    end

    # Get vertical advance by glyph index
    def vertical_advance_by_index(glyph_index : Int32) : Fixed::Int26_6
      return Fixed::Int26_6[0] if glyph_index == 0

      advance_height, _ = @font.v_metrics(glyph_index)
      # If no vertical metrics, use line height (ascent - descent) as fallback
      if advance_height == 0
        advance_height = @font.ascent - @font.descent
      end

      (@scale * advance_height) // 64
    end

    # Rasterize glyph outline
    private def rasterize_glyph(glyph : GlyphData, dot : Fixed::Point26_6, lsb : Int32)
      return if glyph.num_contours <= 0

      # Calculate the offset to transform from absolute coordinates to mask-relative coordinates
      # Use x_min from glyph data (not lsb) to match the bounds calculation
      mask_origin_x = dot.x + (@scale * glyph.x_min) // 64
      mask_origin_y = dot.y - (@scale * glyph.y_max) // 64

      @rasterizer.reset(@mask.bounds.width, @mask.bounds.height)

      start_pt = 0
      glyph.end_pts_of_contours.each do |end_pt|
        rasterize_contour(glyph, start_pt, end_pt, dot, lsb, mask_origin_x, mask_origin_y)
        start_pt = end_pt + 1
      end

      painter = FreeType::Raster::AlphaSrcPainter.new(@mask)
      @rasterizer.rasterize(painter, @mask.bounds.width, @mask.bounds.height)
    end

    private def rasterize_contour(glyph : GlyphData, start_idx : Int32, end_idx : Int32, dot : Fixed::Point26_6, lsb : Int32, mask_origin_x : Fixed::Int26_6, mask_origin_y : Fixed::Int26_6)
      return if start_idx > end_idx

      num_points = end_idx - start_idx + 1
      return if num_points < 1

      # Helper to get point at index (with wrapping)
      get_point = ->(idx : Int32) {
        actual_idx = start_idx + (idx % num_points)
        x = transform_x(glyph.x_coordinates[actual_idx], dot, lsb) - mask_origin_x
        y = transform_y(glyph.y_coordinates[actual_idx], dot) - mask_origin_y
        on_curve = (glyph.flags[actual_idx] & 0x01) != 0
        {Fixed::Point26_6.new(x, y), on_curve}
      }

      # Find the first on-curve point, or create one from midpoint of two off-curve points
      first_on_curve : Fixed::Point26_6
      first_idx = 0

      pt0, on0 = get_point.call(0)
      if on0
        first_on_curve = pt0
        first_idx = 0
      else
        # First point is off-curve, check the last point
        pt_last, on_last = get_point.call(num_points - 1)
        if on_last
          # Start from the last on-curve point
          first_on_curve = pt_last
          first_idx = num_points - 1
        else
          # Both first and last are off-curve, start from their midpoint
          first_on_curve = Fixed::Point26_6.new((pt0.x + pt_last.x) // 2, (pt0.y + pt_last.y) // 2)
          first_idx = 0
        end
      end

      @rasterizer.start(first_on_curve)

      # Current position in the contour
      i = first_idx
      iterations = 0
      max_iterations = num_points + 1

      while iterations < max_iterations
        iterations += 1

        curr_pt, curr_on = get_point.call(i)
        next_i = (i + 1) % num_points
        next_pt, next_on = get_point.call(next_i)

        if curr_on
          # Current point is on-curve
          if next_on
            # Next is also on-curve: draw line
            @rasterizer.add1(next_pt)
            i = next_i
          else
            # Next is off-curve: it's a control point
            # Look ahead to find the endpoint
            next_next_i = (next_i + 1) % num_points
            next_next_pt, next_next_on = get_point.call(next_next_i)

            if next_next_on
              # Endpoint is on-curve
              @rasterizer.add2(next_pt, next_next_pt)
              i = next_next_i
            else
              # Endpoint is midpoint between two off-curve points
              mid_pt = Fixed::Point26_6.new((next_pt.x + next_next_pt.x) // 2, (next_pt.y + next_next_pt.y) // 2)
              @rasterizer.add2(next_pt, mid_pt)
              i = next_i
            end
          end
        else
          # Current point is off-curve (control point)
          if next_on
            # Next is on-curve: draw curve to it
            @rasterizer.add2(curr_pt, next_pt)
            i = next_i
          else
            # Next is also off-curve: endpoint is midpoint
            mid_pt = Fixed::Point26_6.new((curr_pt.x + next_pt.x) // 2, (curr_pt.y + next_pt.y) // 2)
            @rasterizer.add2(curr_pt, mid_pt)
            i = next_i
          end
        end

        # Check if we've completed the loop back to start
        if i == first_idx
          break
        end
      end

      # Ensure contour is closed
      @rasterizer.add1(first_on_curve)
    end

    private def transform_x(x : Int16, dot : Fixed::Point26_6, lsb : Int32) : Fixed::Int26_6
      # Transform font units to 26.6 fixed point pixels
      dot.x + (@scale * x) // 64
    end

    private def transform_y(y : Int16, dot : Fixed::Point26_6) : Fixed::Int26_6
      # Transform font units to 26.6 fixed point pixels
      dot.y - (@scale * y) // 64
    end
  end

  # Load a TrueType font from file
  def self.load(path : String) : Font
    data = File.read(path).to_slice
    Font.new(data)
  end

  # Create a font face with specified size
  def self.new_face(font : Font, size : Float64, hinting = CrImage::Font::Hinting::None) : Face
    Face.new(font, size, hinting)
  end

  # TrueType Collection (TTC) support
  # TTC files contain multiple fonts in a single file
  class Collection
    getter data : Bytes
    getter num_fonts : Int32
    @font_offsets : Array(Int32)
    @is_collection : Bool

    def initialize(@data)
      @font_offsets = [] of Int32
      @is_collection = false
      @num_fonts = 0
      parse_collection
    end

    def is_collection? : Bool
      @is_collection
    end

    private def parse_collection
      # Check minimum size
      raise CrImage::FormatError.new("Font data too small") if @data.size < 12

      # Check for TTC signature 'ttcf'
      signature = read_u32(0)

      if signature == 0x74746366 # 'ttcf'
        @is_collection = true

        # Read TTC version
        version = read_u32(4)
        raise CrImage::FormatError.new("Unsupported TTC version") unless version == 0x00010000 || version == 0x00020000

        # Read number of fonts
        @num_fonts = read_u32(8).to_i
        raise CrImage::FormatError.new("Invalid number of fonts in collection") if @num_fonts < 1 || @num_fonts > 256

        # Validate header size
        header_size = 12 + @num_fonts * 4
        raise CrImage::FormatError.new("TTC header extends beyond file") if header_size > @data.size

        # Read font offsets
        @num_fonts.times do |i|
          offset = read_u32(12 + i * 4).to_i
          raise CrImage::FormatError.new("Font offset out of bounds") if offset >= @data.size
          @font_offsets << offset
        end
      else
        # Not a collection, treat as single font
        @is_collection = false
        @num_fonts = 1
        @font_offsets << 0
      end
    end

    # Get font at specified index
    def font(index : Int32) : Font
      raise CrImage::FormatError.new("Font index out of range") if index < 0 || index >= @num_fonts

      offset = @font_offsets[index]

      # For TTC files, we need to pass the whole data because table offsets
      # in the font directory are absolute (relative to start of file)
      # We'll create a Font with an offset parameter
      if @is_collection
        Font.new(@data, offset)
      else
        Font.new(@data)
      end
    end

    private def read_u32(offset : Int32) : UInt32
      (@data[offset].to_u32 << 24) | (@data[offset + 1].to_u32 << 16) |
        (@data[offset + 2].to_u32 << 8) | @data[offset + 3].to_u32
    end
  end

  # Load a TrueType Collection from file
  def self.load_collection(path : String) : Collection
    data = File.read(path).to_slice
    Collection.new(data)
  end
end
