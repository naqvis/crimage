require "../spec_helper"

describe FreeType::Layout do
  describe "Feature" do
    it "creates feature with tag" do
      feature = FreeType::Layout::Feature.new(FreeType::Layout::FEATURE_LIGA)
      feature.tag.should eq(FreeType::Layout::FEATURE_LIGA)
    end

    it "converts tag to readable name" do
      feature = FreeType::Layout::Feature.new(FreeType::Layout::FEATURE_LIGA)
      feature.tag_name.should eq("liga")
    end

    it "converts kern tag to readable name" do
      feature = FreeType::Layout::Feature.new(FreeType::Layout::FEATURE_KERN)
      feature.tag_name.should eq("kern")
    end
  end

  describe "Script" do
    it "creates script with tag" do
      script = FreeType::Layout::Script.new(FreeType::Layout::SCRIPT_LATIN)
      script.tag.should eq(FreeType::Layout::SCRIPT_LATIN)
    end

    it "converts tag to readable name" do
      script = FreeType::Layout::Script.new(FreeType::Layout::SCRIPT_LATIN)
      script.tag_name.should eq("latn")
    end
  end

  describe "Layout table detection" do
    it "detects font without layout tables" do
      data = LayoutHelper.create_minimal_ttf
      font = FreeType::TrueType::Font.new(data)
      layout_font = FreeType::Layout::Font.new(font)

      layout_font.has_gpos?.should be_false
      layout_font.has_gsub?.should be_false
    end

    it "detects font with GSUB table" do
      data = LayoutHelper.create_ttf_with_gsub
      font = FreeType::TrueType::Font.new(data)
      layout_font = FreeType::Layout::Font.new(font)

      layout_font.has_gsub?.should be_true
      layout_font.has_gpos?.should be_false
    end

    it "parses GSUB features" do
      data = LayoutHelper.create_ttf_with_gsub
      font = FreeType::TrueType::Font.new(data)
      layout_font = FreeType::Layout::Font.new(font)

      gsub = layout_font.gsub
      gsub.should_not be_nil
      gsub.not_nil!.features.size.should eq(2)
      gsub.not_nil!.has_feature?(FreeType::Layout::FEATURE_LIGA).should be_true
      gsub.not_nil!.has_feature?("liga").should be_true
    end

    it "parses GSUB scripts" do
      data = LayoutHelper.create_ttf_with_gsub
      font = FreeType::TrueType::Font.new(data)
      layout_font = FreeType::Layout::Font.new(font)

      gsub = layout_font.gsub
      gsub.should_not be_nil
      gsub.not_nil!.scripts.size.should eq(1)
      gsub.not_nil!.has_script?(FreeType::Layout::SCRIPT_LATIN).should be_true
    end

    it "returns all features from both tables" do
      data = LayoutHelper.create_ttf_with_both_tables
      font = FreeType::TrueType::Font.new(data)
      layout_font = FreeType::Layout::Font.new(font)

      layout_font.has_gpos?.should be_true
      layout_font.has_gsub?.should be_true

      all_features = layout_font.all_features
      all_features.size.should be >= 2
    end
  end
end

# Helper module for creating test fonts
module LayoutHelper
  extend self

  def create_minimal_ttf : Bytes
    num_tables = 3
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size

    data = Bytes.new(loca_offset + loca_size + 100)

    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    offset = 12

    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)
    offset += 16

    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)

    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 1_u16)

    data
  end

  def create_ttf_with_gsub : Bytes
    num_tables = 4
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    gsub_size = 100

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    gsub_offset = loca_offset + loca_size

    data = Bytes.new(gsub_offset + gsub_size + 100)

    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    offset = 12

    write_tag(data, offset, "GSUB")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, gsub_offset.to_u32)
    write_u32(data, offset + 12, gsub_size.to_u32)
    offset += 16

    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)

    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 1_u16)

    # Write GSUB table
    write_u16(data, gsub_offset, 1_u16)      # majorVersion
    write_u16(data, gsub_offset + 2, 0_u16)  # minorVersion
    write_u16(data, gsub_offset + 4, 10_u16) # scriptListOffset
    write_u16(data, gsub_offset + 6, 20_u16) # featureListOffset
    write_u16(data, gsub_offset + 8, 40_u16) # lookupListOffset

    # Script list (1 script: Latin)
    script_list_offset = gsub_offset + 10
    write_u16(data, script_list_offset, 1_u16)                              # scriptCount
    write_u32(data, script_list_offset + 2, FreeType::Layout::SCRIPT_LATIN) # 'latn'
    write_u16(data, script_list_offset + 6, 0_u16)                          # scriptOffset

    # Feature list (2 features: liga, calt)
    feature_list_offset = gsub_offset + 20
    write_u16(data, feature_list_offset, 2_u16)                              # featureCount
    write_u32(data, feature_list_offset + 2, FreeType::Layout::FEATURE_LIGA) # 'liga'
    write_u16(data, feature_list_offset + 6, 0_u16)                          # featureOffset
    write_u32(data, feature_list_offset + 8, FreeType::Layout::FEATURE_CALT) # 'calt'
    write_u16(data, feature_list_offset + 12, 0_u16)                         # featureOffset

    data
  end

  def create_ttf_with_both_tables : Bytes
    num_tables = 5
    header_size = 12 + num_tables * 16

    head_size = 54
    maxp_size = 32
    loca_size = 4
    gpos_size = 50
    gsub_size = 50

    head_offset = header_size
    maxp_offset = head_offset + head_size
    loca_offset = maxp_offset + maxp_size
    gpos_offset = loca_offset + loca_size
    gsub_offset = gpos_offset + gpos_size

    data = Bytes.new(gsub_offset + gsub_size + 100)

    write_u32(data, 0, 0x00010000)
    write_u16(data, 4, num_tables.to_u16)
    write_u16(data, 6, 0_u16)
    write_u16(data, 8, 0_u16)
    write_u16(data, 10, 0_u16)

    offset = 12

    write_tag(data, offset, "GPOS")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, gpos_offset.to_u32)
    write_u32(data, offset + 12, gpos_size.to_u32)
    offset += 16

    write_tag(data, offset, "GSUB")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, gsub_offset.to_u32)
    write_u32(data, offset + 12, gsub_size.to_u32)
    offset += 16

    write_tag(data, offset, "head")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, head_offset.to_u32)
    write_u32(data, offset + 12, head_size.to_u32)
    offset += 16

    write_tag(data, offset, "loca")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, loca_offset.to_u32)
    write_u32(data, offset + 12, loca_size.to_u32)
    offset += 16

    write_tag(data, offset, "maxp")
    write_u32(data, offset + 4, 0_u32)
    write_u32(data, offset + 8, maxp_offset.to_u32)
    write_u32(data, offset + 12, maxp_size.to_u32)

    write_u16(data, head_offset + 18, 1024_u16)
    write_i16(data, head_offset + 50, 1_i16)

    write_u32(data, maxp_offset, 0x00010000_u32)
    write_u16(data, maxp_offset + 4, 1_u16)

    # Write GPOS table
    write_u16(data, gpos_offset, 1_u16)
    write_u16(data, gpos_offset + 2, 0_u16)
    write_u16(data, gpos_offset + 4, 10_u16)
    write_u16(data, gpos_offset + 6, 20_u16)
    write_u16(data, gpos_offset + 8, 30_u16)

    script_offset = gpos_offset + 10
    write_u16(data, script_offset, 1_u16)
    write_u32(data, script_offset + 2, FreeType::Layout::SCRIPT_LATIN)
    write_u16(data, script_offset + 6, 0_u16)

    feature_offset = gpos_offset + 20
    write_u16(data, feature_offset, 1_u16)
    write_u32(data, feature_offset + 2, FreeType::Layout::FEATURE_KERN)
    write_u16(data, feature_offset + 6, 0_u16)

    # Write GSUB table
    write_u16(data, gsub_offset, 1_u16)
    write_u16(data, gsub_offset + 2, 0_u16)
    write_u16(data, gsub_offset + 4, 10_u16)
    write_u16(data, gsub_offset + 6, 20_u16)
    write_u16(data, gsub_offset + 8, 30_u16)

    script_offset = gsub_offset + 10
    write_u16(data, script_offset, 1_u16)
    write_u32(data, script_offset + 2, FreeType::Layout::SCRIPT_LATIN)
    write_u16(data, script_offset + 6, 0_u16)

    feature_offset = gsub_offset + 20
    write_u16(data, feature_offset, 1_u16)
    write_u32(data, feature_offset + 2, FreeType::Layout::FEATURE_LIGA)
    write_u16(data, feature_offset + 6, 0_u16)

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
end
