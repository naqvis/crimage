require "../spec_helper"

describe FreeType::Variable do
  describe "VariationAxis" do
    it "creates axis with properties" do
      axis = FreeType::Variable::VariationAxis.new(
        FreeType::Variable::AXIS_WEIGHT,
        100.0_f32,
        400.0_f32,
        900.0_f32,
        "Weight"
      )

      axis.tag.should eq(FreeType::Variable::AXIS_WEIGHT)
      axis.min_value.should eq(100.0_f32)
      axis.default_value.should eq(400.0_f32)
      axis.max_value.should eq(900.0_f32)
      axis.name.should eq("Weight")
    end

    it "converts tag to readable name" do
      axis = FreeType::Variable::VariationAxis.new(
        FreeType::Variable::AXIS_WEIGHT,
        100.0_f32,
        400.0_f32,
        900.0_f32
      )

      axis.tag_name.should eq("wght")
    end

    it "converts width tag to readable name" do
      axis = FreeType::Variable::VariationAxis.new(
        FreeType::Variable::AXIS_WIDTH,
        75.0_f32,
        100.0_f32,
        125.0_f32
      )

      axis.tag_name.should eq("wdth")
    end
  end

  describe "Variable Font detection" do
    it "detects non-variable font" do
      # Create minimal TrueType font without fvar table
      data = VariableFontHelper.create_minimal_ttf([] of String)
      font = FreeType::TrueType::Font.new(data)
      var_font = FreeType::Variable::Font.new(font)

      var_font.is_variable?.should be_false
      var_font.axes.size.should eq(0)
    end

    it "detects variable font with fvar table" do
      # Create TrueType font with fvar table
      data = VariableFontHelper.create_variable_ttf
      font = FreeType::TrueType::Font.new(data)
      var_font = FreeType::Variable::Font.new(font)

      var_font.is_variable?.should be_true
      var_font.axes.size.should eq(1)
    end

    it "parses weight axis" do
      data = VariableFontHelper.create_variable_ttf
      font = FreeType::TrueType::Font.new(data)
      var_font = FreeType::Variable::Font.new(font)

      axis = var_font.axis(FreeType::Variable::AXIS_WEIGHT)
      axis.should_not be_nil
      axis.not_nil!.min_value.should eq(100.0_f32)
      axis.not_nil!.default_value.should eq(400.0_f32)
      axis.not_nil!.max_value.should eq(900.0_f32)
    end

    it "finds axis by tag name" do
      data = VariableFontHelper.create_variable_ttf
      font = FreeType::TrueType::Font.new(data)
      var_font = FreeType::Variable::Font.new(font)

      axis = var_font.axis("wght")
      axis.should_not be_nil
      axis.not_nil!.tag_name.should eq("wght")
    end

    it "returns nil for non-existent axis" do
      data = VariableFontHelper.create_variable_ttf
      font = FreeType::TrueType::Font.new(data)
      var_font = FreeType::Variable::Font.new(font)

      axis = var_font.axis("slnt")
      axis.should be_nil
    end
  end
end

# Helper module for creating test fonts
module VariableFontHelper
  extend self

  # Helper to create minimal TrueType font
  def create_minimal_ttf(extra_tables : Array(String)) : Bytes
    num_tables = 3 + extra_tables.size
    header_size = 12 + num_tables * 16

    # Calculate table sizes
    head_size = 54
    maxp_size = 32
    loca_size = 4

    # Calculate offsets
    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    current_offset = loca_offset + loca_size

    data = Bytes.new(current_offset + 1000) # Extra space for additional tables

    # Write TrueType header
    write_u32(data, 0, 0x00010000) # version
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)  # searchRange
    write_u16(data, 8, 0_u16)  # entrySelector
    write_u16(data, 10, 0_u16) # rangeShift

    # Write table directory
    offset = 12

    # head table
    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32) # checksum
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    # maxp table
    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)
    offset += 16

    # loca table
    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16) # unitsPerEm
    write_i16(data, head_offset + 50, 1_i16)    # indexToLocFormat (long)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32) # version
    write_u16(data, maxp_offset + 4, 1_u16)      # numGlyphs

    data
  end

  # Helper to create variable TrueType font with fvar table
  def create_variable_ttf : Bytes
    num_tables = 4
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    fvar_size = 28 # Header (16) + 1 axis (20) - axes_array_offset adjustment

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    fvar_offset = loca_offset + loca_size

    data = Bytes.new(fvar_offset + fvar_size + 100)

    # Write TrueType header
    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    # Write table directory
    offset = 12

    # head table
    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    # maxp table
    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)
    offset += 16

    # loca table
    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    # fvar table
    write_tag(data, offset, "fvar")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, fvar_offset.to_u32)
    write_u32(data, offset + 12, fvar_size.to_u32)

    # Write head table
    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    # Write maxp table
    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 1_u16)

    # Write fvar table
    write_u16(data, fvar_offset, 1_u16)       # majorVersion
    write_u16(data, fvar_offset + 2, 0_u16)   # minorVersion
    write_u16(data, fvar_offset + 4, 16_u16)  # axesArrayOffset
    write_u16(data, fvar_offset + 6, 0_u16)   # reserved
    write_u16(data, fvar_offset + 8, 1_u16)   # axisCount
    write_u16(data, fvar_offset + 10, 20_u16) # axisSize

    # Write weight axis
    axis_offset = fvar_offset + 16
    write_u32(data, axis_offset, FreeType::Variable::AXIS_WEIGHT) # tag 'wght'
    write_fixed(data, axis_offset + 4, 100.0_f32)                 # minValue
    write_fixed(data, axis_offset + 8, 400.0_f32)                 # defaultValue
    write_fixed(data, axis_offset + 12, 900.0_f32)                # maxValue
    write_u16(data, axis_offset + 16, 0_u16)                      # flags
    write_u16(data, axis_offset + 18, 256_u16)                    # axisNameID

    data
  end

  def write_tag(data : Bytes, offset : Int32, tag : String)
    tag.bytes.each_with_index { |byte, i| data[offset + i] = byte }
  end

  def write_u16(data : Bytes, offset : Int32, value : UInt16)
    data[offset] = (value >> 8).to_u8
    data[offset + 1] = (value & 0xFF).to_u8
  end

  def write_i16(data : Bytes, offset : Int32, value : Int16)
    write_u16(data, offset, value.to_u16)
  end

  def write_u32(data : Bytes, offset : Int32, value : UInt32)
    data[offset] = (value >> 24).to_u8
    data[offset + 1] = ((value >> 16) & 0xFF).to_u8
    data[offset + 2] = ((value >> 8) & 0xFF).to_u8
    data[offset + 3] = (value & 0xFF).to_u8
  end

  def write_fixed(data : Bytes, offset : Int32, value : Float32)
    # Write 16.16 fixed-point number
    fixed = (value * 65536.0_f32).to_i32
    write_u32(data, offset, fixed.to_u32)
  end
end
