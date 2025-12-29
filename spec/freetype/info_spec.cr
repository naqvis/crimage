require "../spec_helper"

describe FreeType::Info do
  describe "FontInfo" do
    it "creates empty font info" do
      info = FreeType::Info::FontInfo.new
      info.family_name.should eq("")
      info.subfamily_name.should eq("")
      info.style_name.should eq("")
    end

    it "style_name is alias for subfamily_name" do
      info = FreeType::Info::FontInfo.new
      info.subfamily_name = "Bold"
      info.style_name.should eq("Bold")
    end
  end

  describe "Font metadata parsing" do
    it "parses font without name table" do
      data = InfoHelper.create_font_without_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.info.family_name.should eq("")
      font.info.version.should eq("")
    end

    it "parses basic font metadata" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.info.family_name.should eq("Test Font")
      font.info.subfamily_name.should eq("Regular")
      font.info.style_name.should eq("Regular")
      font.info.version.should eq("Version 1.0")
    end

    it "parses full font metadata" do
      data = InfoHelper.create_font_with_full_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.info.family_name.should eq("Test Font")
      font.info.full_name.should eq("Test Font Regular")
      font.info.postscript_name.should eq("TestFont-Regular")
      font.info.copyright.should eq("Copyright 2024")
    end
  end

  describe "Character coverage" do
    it "checks if font has character" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      # Font has glyph 0 (missing glyph) so all chars return false
      # In real font, this would check actual glyphs
      font.has_char?('A').should be_false
    end

    it "checks if font has all characters in string" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.has_chars?("ABC").should be_false
    end

    it "finds missing characters" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      missing = font.missing_chars("ABC")
      missing.should eq(['A', 'B', 'C'])
    end

    it "removes duplicate missing characters" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      missing = font.missing_chars("AAA")
      missing.should eq(['A'])
    end

    it "calculates coverage percentage" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      # All chars missing = 0%
      coverage = font.coverage("ABC")
      coverage.should eq(0.0)
    end

    it "returns 100% for empty string" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      coverage = font.coverage("")
      coverage.should eq(100.0)
    end

    it "detects unicode ranges" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      ranges = font.unicode_ranges
      ranges.size.should be > 0

      # Check structure
      first = ranges.first
      first[:name].should be_a(String)
      first[:range].should be_a(Range(Int32, Int32))
      first[:coverage].should be_a(Float64)
    end
  end

  describe "Font properties" do
    it "returns glyph count" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.glyph_count.should eq(100)
    end

    it "checks for kerning support" do
      data = InfoHelper.create_font_without_kern
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.has_kerning?.should be_false
    end

    it "checks for vertical metrics" do
      data = InfoHelper.create_font_with_name
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Info::Font.new(ttf)

      font.has_vertical_metrics?.should be_false
    end
  end
end

# Helper module for creating test fonts
module InfoHelper
  extend self

  def create_font_without_name : Bytes
    create_minimal_font(include_name: false)
  end

  def create_font_with_name : Bytes
    names = {
      FreeType::Info::NAME_FAMILY    => "Test Font",
      FreeType::Info::NAME_SUBFAMILY => "Regular",
      FreeType::Info::NAME_VERSION   => "Version 1.0",
    }
    create_font_with_names(names)
  end

  def create_font_with_full_name : Bytes
    names = {
      FreeType::Info::NAME_FAMILY          => "Test Font",
      FreeType::Info::NAME_SUBFAMILY       => "Regular",
      FreeType::Info::NAME_FULL_NAME       => "Test Font Regular",
      FreeType::Info::NAME_VERSION         => "Version 1.0",
      FreeType::Info::NAME_POSTSCRIPT_NAME => "TestFont-Regular",
      FreeType::Info::NAME_COPYRIGHT       => "Copyright 2024",
    }
    create_font_with_names(names)
  end

  def create_font_without_kern : Bytes
    create_minimal_font(include_name: true, include_kern: false)
  end

  private def create_minimal_font(include_name : Bool, include_kern : Bool = false) : Bytes
    num_tables = 3
    num_tables += 1 if include_name
    num_tables += 1 if include_kern

    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    name_size = include_name ? 200 : 0
    kern_size = include_kern ? 50 : 0

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    name_offset = loca_offset + loca_size
    kern_offset = name_offset + name_size

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
    offset += 16

    # name table (if included)
    if include_name
      write_tag(data, offset, "name")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, name_offset.to_u32)
      write_u32(data, offset + 12, name_size.to_u32)
      offset += 16
    end

    # kern table (if included)
    if include_kern
      write_tag(data, offset, "kern")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, kern_offset.to_u32)
      write_u32(data, offset + 12, kern_size.to_u32)
    end

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 100_u16) # numGlyphs

    data
  end

  private def create_font_with_names(names : Hash(UInt16, String)) : Bytes
    num_tables = 4
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4

    # Calculate name table size
    name_count = names.size
    name_header_size = 6 + name_count * 12

    # Calculate string storage size (UTF-16 BE)
    string_data_size = names.values.sum { |s| s.size * 2 }
    name_size = name_header_size + string_data_size

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    name_offset = loca_offset + loca_size

    data = Bytes.new(name_offset + name_size + 100)

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
    offset += 16

    # name table
    write_tag(data, offset, "name")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, name_offset.to_u32)
    write_u32(data, offset + 12, name_size.to_u32)

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 100_u16)

    # Write name table
    write_name_table(data, name_offset, names)

    data
  end

  private def write_name_table(data : Bytes, offset : Int32, names : Hash(UInt16, String))
    # Name table header
    write_u16(data, offset, 0_u16)                            # format
    write_u16(data, offset + 2, names.size.to_u16)            # count
    write_u16(data, offset + 4, (6 + names.size * 12).to_u16) # stringOffset

    # Write name records
    record_offset = offset + 6
    string_offset = 0

    names.each do |(name_id, string)|
      write_u16(data, record_offset, FreeType::Info::PLATFORM_WINDOWS) # platformID
      write_u16(data, record_offset + 2, 1_u16)                        # encodingID (Unicode BMP)
      write_u16(data, record_offset + 4, 0x0409_u16)                   # languageID (en-US)
      write_u16(data, record_offset + 6, name_id)                      # nameID
      write_u16(data, record_offset + 8, (string.size * 2).to_u16)     # length
      write_u16(data, record_offset + 10, string_offset.to_u16)        # offset

      # Write string data (UTF-16 BE)
      str_offset = offset + 6 + names.size * 12 + string_offset
      string.each_char_with_index do |char, i|
        write_u16(data, str_offset + i * 2, char.ord.to_u16)
      end

      string_offset += string.size * 2
      record_offset += 12
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
