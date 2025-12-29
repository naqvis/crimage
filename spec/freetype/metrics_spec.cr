require "../spec_helper"

describe FreeType::Metrics do
  describe "ExtendedMetrics" do
    it "creates empty metrics" do
      metrics = FreeType::Metrics::ExtendedMetrics.new
      metrics.underline_position.should eq(0)
      metrics.underline_thickness.should eq(0)
      metrics.strikeout_position.should eq(0)
      metrics.strikeout_size.should eq(0)
    end
  end

  describe "Font metrics parsing" do
    it "parses font without post table" do
      data = MetricsHelper.create_font_without_post
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      font.metrics.underline_position.should eq(0)
      font.metrics.underline_thickness.should eq(0)
    end

    it "parses post table metrics" do
      data = MetricsHelper.create_font_with_post
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      font.metrics.underline_position.should eq(-100)
      font.metrics.underline_thickness.should eq(50)
    end

    it "parses OS/2 table metrics" do
      data = MetricsHelper.create_font_with_os2
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      font.metrics.strikeout_position.should eq(300)
      font.metrics.strikeout_size.should eq(50)
    end

    it "parses OS/2 version 2+ metrics" do
      data = MetricsHelper.create_font_with_os2_v2
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      font.metrics.x_height.should eq(500)
      font.metrics.cap_height.should eq(700)
    end

    it "parses hhea line gap" do
      data = MetricsHelper.create_font_with_hhea
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      font.metrics.line_gap.should eq(200)
    end
  end

  describe "Scaled metrics" do
    it "scales underline position by font size" do
      data = MetricsHelper.create_font_with_post
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      # At 64pt with 1024 units_per_em: scale = 64*64/1024 = 4
      # -100 * 4 / 64 = -6 (approximately)
      scaled = font.underline_position(64.0)
      scaled.should be < 0
    end

    it "scales underline thickness by font size" do
      data = MetricsHelper.create_font_with_post
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      scaled = font.underline_thickness(64.0)
      scaled.should be > 0
    end

    it "scales strikeout metrics by font size" do
      data = MetricsHelper.create_font_with_os2
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      pos = font.strikeout_position(64.0)
      size = font.strikeout_size(64.0)

      pos.should be > 0
      size.should be > 0
    end

    it "scales x_height and cap_height by font size" do
      data = MetricsHelper.create_font_with_os2_v2
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      x_height = font.x_height(64.0)
      cap_height = font.cap_height(64.0)

      x_height.should be > 0
      cap_height.should be > 0
      cap_height.should be > x_height
    end

    it "scales line gap by font size" do
      data = MetricsHelper.create_font_with_hhea
      ttf = FreeType::TrueType::Font.new(data)
      font = FreeType::Metrics::Font.new(ttf)

      gap = font.line_gap(64.0)
      gap.should be > 0
    end
  end
end

# Helper module for creating test fonts
module MetricsHelper
  extend self

  def create_font_without_post : Bytes
    create_minimal_font(include_post: false, include_os2: false)
  end

  def create_font_with_post : Bytes
    create_minimal_font(include_post: true, include_os2: false)
  end

  def create_font_with_os2 : Bytes
    create_minimal_font(include_post: false, include_os2: true, os2_version: 0)
  end

  def create_font_with_os2_v2 : Bytes
    create_minimal_font(include_post: false, include_os2: true, os2_version: 2)
  end

  def create_font_with_hhea : Bytes
    create_minimal_font(include_post: false, include_os2: false, include_hhea: true)
  end

  private def create_minimal_font(include_post : Bool, include_os2 : Bool, os2_version : Int32 = 0, include_hhea : Bool = false) : Bytes
    num_tables = 3
    num_tables += 1 if include_post
    num_tables += 1 if include_os2
    num_tables += 1 if include_hhea

    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    post_size = include_post ? 32 : 0
    os2_size = include_os2 ? (os2_version >= 2 ? 96 : 78) : 0
    hhea_size = include_hhea ? 36 : 0

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    post_offset = loca_offset + loca_size
    os2_offset = post_offset + post_size
    hhea_offset = os2_offset + os2_size

    data = Bytes.new(hhea_offset + hhea_size + 100)

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

    # hhea table (if included)
    if include_hhea
      write_tag(data, offset, "hhea")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, hhea_offset.to_u32)
      write_u32(data, offset + 12, hhea_size.to_u32)
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
    offset += 16

    # OS/2 table (if included)
    if include_os2
      write_tag(data, offset, "OS/2")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, os2_offset.to_u32)
      write_u32(data, offset + 12, os2_size.to_u32)
      offset += 16
    end

    # post table (if included)
    if include_post
      write_tag(data, offset, "post")
      write_u32(data, offset + 4, 0_u32)
      write_u32(data, offset + 8, post_offset.to_u32)
      write_u32(data, offset + 12, post_size.to_u32)
    end

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16) # unitsPerEm
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 100_u16)

    # Write post table
    if include_post
      write_u32(data, post_offset, 0x00020000_u32) # version 2.0
      write_u32(data, post_offset + 4, 0_u32)      # italicAngle
      write_i16(data, post_offset + 8, -100_i16)   # underlinePosition
      write_i16(data, post_offset + 10, 50_i16)    # underlineThickness
    end

    # Write OS/2 table
    if include_os2
      write_u16(data, os2_offset, os2_version.to_u16) # version
      # Skip to strikeout fields (offset 26)
      write_i16(data, os2_offset + 26, 50_i16)  # yStrikeoutSize
      write_i16(data, os2_offset + 28, 300_i16) # yStrikeoutPosition

      # Subscript/superscript (offset 10-24)
      write_i16(data, os2_offset + 10, 650_i16) # ySubscriptXSize
      write_i16(data, os2_offset + 12, 700_i16) # ySubscriptYSize
      write_i16(data, os2_offset + 14, 0_i16)   # ySubscriptXOffset
      write_i16(data, os2_offset + 16, 140_i16) # ySubscriptYOffset
      write_i16(data, os2_offset + 18, 650_i16) # ySuperscriptXSize
      write_i16(data, os2_offset + 20, 700_i16) # ySuperscriptYSize
      write_i16(data, os2_offset + 22, 0_i16)   # ySuperscriptXOffset
      write_i16(data, os2_offset + 24, 480_i16) # ySuperscriptYOffset

      if os2_version >= 2
        write_i16(data, os2_offset + 86, 500_i16) # sxHeight
        write_i16(data, os2_offset + 88, 700_i16) # sCapHeight
      end
    end

    # Write hhea table
    if include_hhea
      write_u32(data, hhea_offset, 0x00010000_u32) # version
      write_i16(data, hhea_offset + 4, 800_i16)    # ascent
      write_i16(data, hhea_offset + 6, -200_i16)   # descent
      write_i16(data, hhea_offset + 8, 200_i16)    # lineGap
    end

    data
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
