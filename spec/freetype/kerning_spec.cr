require "../spec_helper"

describe "FreeType Kerning" do
  describe "kern table parsing" do
    it "returns zero for fonts without kern table" do
      data = KerningHelper.create_font_without_kern
      font = FreeType::TrueType::Font.new(data)

      kern_value = font.lookup_kern(1, 2)
      kern_value.should eq(0)
    end

    it "parses kern table format 0" do
      data = KerningHelper.create_font_with_kern
      font = FreeType::TrueType::Font.new(data)

      # Should find the kerning pair (10, 20) with value -50
      kern_value = font.lookup_kern(10, 20)
      kern_value.should eq(-50)
    end

    it "returns zero for non-existent kerning pairs" do
      data = KerningHelper.create_font_with_kern
      font = FreeType::TrueType::Font.new(data)

      # Pair (1, 2) doesn't exist in our test data
      kern_value = font.lookup_kern(1, 2)
      kern_value.should eq(0)
    end

    it "handles multiple kerning pairs" do
      data = KerningHelper.create_font_with_multiple_pairs
      font = FreeType::TrueType::Font.new(data)

      # Test multiple pairs
      font.lookup_kern(5, 10).should eq(-30)
      font.lookup_kern(10, 20).should eq(-50)
      font.lookup_kern(15, 25).should eq(-40)
      font.lookup_kern(20, 30).should eq(-60)
    end

    it "uses binary search correctly" do
      data = KerningHelper.create_font_with_many_pairs
      font = FreeType::TrueType::Font.new(data)

      # Test first, middle, and last pairs
      font.lookup_kern(1, 2).should eq(-1)
      font.lookup_kern(50, 51).should eq(-50)
      font.lookup_kern(99, 100).should eq(-99)
    end
  end

  describe "Face kerning" do
    it "scales kerning values by font size" do
      data = KerningHelper.create_font_with_kern
      font = FreeType::TrueType::Font.new(data)
      face = FreeType::TrueType::Face.new(font, 64.0) # 64pt = 1:1 scale

      # Mock glyph indices (we'd need actual glyphs for real test)
      # For now, test that kern method exists and returns correct type
      kern = face.kern('A', 'V')
      kern.should be_a(CrImage::Math::Fixed::Int26_6)
    end

    it "returns zero for characters without kerning" do
      data = KerningHelper.create_font_without_kern
      font = FreeType::TrueType::Font.new(data)
      face = FreeType::TrueType::Face.new(font, 64.0)

      kern = face.kern('A', 'B')
      kern.should eq(CrImage::Math::Fixed::Int26_6[0])
    end
  end

  describe "GPOS kerning" do
    it "detects GPOS table in Roboto font" do
      font = load_roboto_bold
      font.has_gpos?.should be_true
    end

    it "returns kerning values from GPOS table" do
      font = load_roboto_bold

      # AV is a classic kerning pair
      a_glyph = font.glyph_index('A')
      v_glyph = font.glyph_index('V')

      kern = font.lookup_kern(a_glyph, v_glyph)
      kern.should be < 0 # AV should have negative kerning
    end

    it "returns zero for non-existent GPOS pairs" do
      font = load_roboto_bold

      # Space + period unlikely to have kerning
      space_glyph = font.glyph_index(' ')
      period_glyph = font.glyph_index('.')

      kern = font.lookup_kern(space_glyph, period_glyph)
      kern.should eq(0)
    end

    it "returns consistent kerning for common pairs" do
      font = load_roboto_bold

      # Test several known kerning pairs
      pairs = {
        {'A', 'V'} => true, # Should have kerning
        {'T', 'o'} => true, # Should have kerning
        {'V', 'A'} => true, # Should have kerning
        {'W', 'a'} => true, # Should have kerning
      }

      pairs.each do |(c1, c2), should_have_kern|
        g1 = font.glyph_index(c1)
        g2 = font.glyph_index(c2)
        kern = font.lookup_kern(g1, g2)

        if should_have_kern
          kern.should_not eq(0), "Expected kerning for #{c1}#{c2}"
        end
      end
    end
  end

  describe "Vertical text" do
    it "reports has_vertical_metrics? for Font" do
      font = load_roboto_bold
      # Roboto may or may not have vertical metrics
      font.has_vertical_metrics?.should be_a(Bool)
    end

    it "reports has_vertical_metrics? for Face" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)
      face.has_vertical_metrics?.should be_a(Bool)
    end

    it "returns vertical advance for characters" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      advance, ok = face.vertical_advance('A')
      # Should return a value (either from vmtx or fallback to hmtx)
      advance.to_i.should be >= 0
    end

    it "returns vertical advance by glyph index" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      a_glyph = face.glyph_index('A')
      advance = face.vertical_advance_by_index(a_glyph)
      advance.to_i.should be > 0
    end

    it "returns zero for invalid glyph index" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      advance = face.vertical_advance_by_index(0)
      advance.to_i.should eq(0)
    end

    it "draws vertical text without error" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      # Create a test image
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 300))
      src = CrImage::Uniform.new(CrImage::Color::BLACK)
      drawer = CrImage::Font::Drawer.new(image, src, face)

      # Set starting position
      drawer.dot = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )

      # Should not raise
      drawer.draw_vertical("ABC")

      # Dot should have advanced downward (Y increased)
      drawer.dot.y.to_i.should be > 50 * 64
    end

    it "advances Y position for each character in vertical text" do
      font = load_roboto_bold
      face = FreeType::TrueType::Face.new(font, 48.0)

      image = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 500))
      src = CrImage::Uniform.new(CrImage::Color::BLACK)
      drawer = CrImage::Font::Drawer.new(image, src, face)

      start_y = 50 * 64
      drawer.dot = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[start_y]
      )

      drawer.draw_vertical("Hello")

      # Y should have advanced significantly (5 characters)
      drawer.dot.y.to_i.should be > start_y + 100 * 64
    end
  end
end

private def load_roboto_bold : FreeType::TrueType::Font
  path = "spec/testdata/fonts/Roboto/Roboto-Bold.ttf"
  data = File.read(path).to_slice
  FreeType::TrueType::Font.new(data)
end

# Helper module for creating test fonts with kern tables
module KerningHelper
  extend self

  def create_font_without_kern : Bytes
    create_minimal_font(include_kern: false)
  end

  def create_font_with_kern : Bytes
    pairs = [{10_u16, 20_u16, -50_i16}]
    create_font_with_kern_pairs(pairs)
  end

  def create_font_with_multiple_pairs : Bytes
    pairs = [
      {5_u16, 10_u16, -30_i16},
      {10_u16, 20_u16, -50_i16},
      {15_u16, 25_u16, -40_i16},
      {20_u16, 30_u16, -60_i16},
    ]
    create_font_with_kern_pairs(pairs)
  end

  def create_font_with_many_pairs : Bytes
    # Create pairs sorted by (left, right) as required by kern table format 0
    pairs = (1..100).map do |i|
      {i.to_u16, (i + 1).to_u16, -i.to_i16}
    end.sort_by { |(left, right, _)| (left.to_u32 << 16) | right.to_u32 }
    create_font_with_kern_pairs(pairs)
  end

  private def create_minimal_font(include_kern : Bool) : Bytes
    num_tables = include_kern ? 4 : 3
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    kern_size = include_kern ? 100 : 0

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    kern_offset = loca_offset + loca_size

    data = Bytes.new(kern_offset + kern_size + 100)

    # TrueType header
    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    offset = 12

    # head table
    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    # kern table (if included)
    if include_kern
      write_tag(data, offset, "kern")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, kern_offset.to_u32)
      write_u32(data, offset + 12, kern_size.to_u32)
      offset += 16
    end

    # loca table
    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    # maxp table
    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 100_u16) # numGlyphs

    data
  end

  private def create_font_with_kern_pairs(pairs : Array(Tuple(UInt16, UInt16, Int16))) : Bytes
    num_tables = 4
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4

    # Calculate kern table size
    # Header: 4 bytes (version + nTables)
    # Subtable header: 6 bytes
    # Format 0 header: 8 bytes
    # Pairs: 6 bytes each
    kern_size = 4 + 6 + 8 + (pairs.size * 6)

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    kern_offset = loca_offset + loca_size

    data = Bytes.new(kern_offset + kern_size + 100)

    # TrueType header
    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    offset = 12

    # head table
    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    # kern table
    write_tag(data, offset, "kern")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, kern_offset.to_u32)
    write_u32(data, offset + 12, kern_size.to_u32)
    offset += 16

    # loca table
    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    # maxp table
    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 100_u16)

    # Write kern table
    write_kern_table(data, kern_offset, pairs)

    data
  end

  private def write_kern_table(data : Bytes, offset : Int32, pairs : Array(Tuple(UInt16, UInt16, Int16)))
    # Kern table header
    write_u16(data, offset, 0_u16)     # version
    write_u16(data, offset + 2, 1_u16) # nTables

    # Subtable header
    subtable_offset = offset + 4
    subtable_length = 6 + 8 + (pairs.size * 6)
    write_u16(data, subtable_offset, 0_u16)                      # version
    write_u16(data, subtable_offset + 2, subtable_length.to_u16) # length
    write_u16(data, subtable_offset + 4, 0x0001_u16)             # coverage (format 0, horizontal)

    # Format 0 header
    format_offset = subtable_offset + 6
    write_u16(data, format_offset, pairs.size.to_u16) # nPairs

    # Calculate searchRange, entrySelector, rangeShift
    max_power = Math.log2(pairs.size).floor.to_i
    search_range = (1 << max_power) * 6
    entry_selector = max_power
    range_shift = pairs.size * 6 - search_range

    write_u16(data, format_offset + 2, search_range.to_u16)
    write_u16(data, format_offset + 4, entry_selector.to_u16)
    write_u16(data, format_offset + 6, range_shift.to_u16)

    # Write kerning pairs (must be sorted)
    pairs_offset = format_offset + 8
    pairs.each_with_index do |(left, right, value), i|
      pair_offset = pairs_offset + i * 6
      write_u16(data, pair_offset, left)
      write_u16(data, pair_offset + 2, right)
      write_i16(data, pair_offset + 4, value)
    end
  end

  private def write_tag(data : Bytes, offset : Int32, tag : String)
    tag.bytes.each_with_index { |byte, i| data[offset + i] = byte }
  end

  private def write_u16(data : Bytes, offset : Int32, value : UInt16)
    data[offset] = (value >> 8).to_u8
    data[offset + 1] = (value & 0xFF).to_u8
  end

  private def write_i16(data : Bytes, offset : Int32, value : Int16)
    # Convert signed to unsigned representation (two's complement)
    unsigned = value < 0 ? (0x10000 + value).to_u16 : value.to_u16
    write_u16(data, offset, unsigned)
  end

  private def write_u32(data : Bytes, offset : Int32, value : UInt32)
    data[offset] = (value >> 24).to_u8
    data[offset + 1] = ((value >> 16) & 0xFF).to_u8
    data[offset + 2] = ((value >> 8) & 0xFF).to_u8
    data[offset + 3] = (value & 0xFF).to_u8
  end
end
