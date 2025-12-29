require "../spec_helper"

describe FreeType::TrueType do
  describe "Vertical Metrics" do
    it "should parse vhea table" do
      data = Bytes.new(2048, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x05_u8 # 5 tables

      # head table
      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      # maxp table
      offset = 28
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      # loca table
      offset = 44
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      # vhea table
      offset = 60
      "vhea".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8 # Offset 1024

      # vmtx table
      offset = 76
      "vmtx".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x05_u8
      data[offset + 11] = 0x00_u8 # Offset 1280

      # head table data
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table data
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x05_u8 # 5 glyphs

      # vhea table data at offset 1024
      offset = 1024
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8 # Version 1.0
      data[offset + 4] = 0x02_u8
      data[offset + 5] = 0x00_u8 # Vertical ascent 512
      data[offset + 6] = 0xFE_u8
      data[offset + 7] = 0x00_u8 # Vertical descent -512
      data[offset + 34] = 0x00_u8
      data[offset + 35] = 0x03_u8 # 3 vertical metrics

      # vmtx table data at offset 1280
      # Glyph 0: advance=1000, tsb=100
      offset = 1280
      data[offset] = 0x03_u8
      data[offset + 1] = 0xE8_u8 # 1000
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x64_u8 # 100

      # Glyph 1: advance=900, tsb=50
      data[offset + 4] = 0x03_u8
      data[offset + 5] = 0x84_u8 # 900
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x32_u8 # 50

      # Glyph 2: advance=800, tsb=75
      data[offset + 8] = 0x03_u8
      data[offset + 9] = 0x20_u8 # 800
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x4B_u8 # 75

      # Glyphs 3-4 use last advance with different tsb
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x60_u8 # tsb=96
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x80_u8 # tsb=128

      font = FreeType::TrueType::Font.new(data)
      font.has_vertical_metrics?.should be_true

      # Test vertical metrics
      advance, tsb = font.v_metrics(0)
      advance.should eq(1000)
      tsb.should eq(100)

      advance, tsb = font.v_metrics(1)
      advance.should eq(900)
      tsb.should eq(50)

      advance, tsb = font.v_metrics(3)
      advance.should eq(800) # Uses last advance
      tsb.should eq(96)
    end

    it "should handle fonts without vertical metrics" do
      data = Bytes.new(2048, 0_u8)

      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x03_u8

      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 28
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      offset = 44
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      font = FreeType::TrueType::Font.new(data)
      font.has_vertical_metrics?.should be_false

      # Should return default values
      advance, tsb = font.v_metrics(0)
      advance.should eq(0)
      tsb.should eq(0)
    end

    it "should calculate vertical origin offset" do
      data = Bytes.new(2048, 0_u8)

      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x04_u8

      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 28
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      offset = 44
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      offset = 60
      "vhea".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8

      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x01_u8

      offset = 1024
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x02_u8
      data[offset + 5] = 0x00_u8 # Vertical ascent 512
      data[offset + 6] = 0xFE_u8
      data[offset + 7] = 0x00_u8 # Vertical descent -512
      data[offset + 34] = 0x00_u8
      data[offset + 35] = 0x01_u8

      font = FreeType::TrueType::Font.new(data)

      # Vertical origin should be calculated from vhea
      font.vertical_ascent.should eq(512)
      font.vertical_descent.should eq(-512)
    end
  end
end
