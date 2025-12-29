require "../spec_helper"

describe FreeType::TrueType do
  describe "TrueType Collection (TTC)" do
    it "should detect TTC signature" do
      data = Bytes.new(4096, 0_u8)

      # TTC signature 'ttcf'
      data[0] = 't'.ord.to_u8
      data[1] = 't'.ord.to_u8
      data[2] = 'c'.ord.to_u8
      data[3] = 'f'.ord.to_u8

      # Version 1.0
      data[4] = 0x00_u8
      data[5] = 0x01_u8
      data[6] = 0x00_u8
      data[7] = 0x00_u8

      # Number of fonts
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x02_u8 # 2 fonts

      # Offset to first font
      data[12] = 0x00_u8
      data[13] = 0x00_u8
      data[14] = 0x01_u8
      data[15] = 0x00_u8 # Offset 256

      # Offset to second font
      data[16] = 0x00_u8
      data[17] = 0x00_u8
      data[18] = 0x02_u8
      data[19] = 0x00_u8 # Offset 512

      # First font at offset 256
      offset = 256
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8 # TrueType signature

      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x03_u8 # 3 tables

      # Add minimal tables for first font
      # head table
      table_offset = offset + 12
      "head".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x04_u8
      data[table_offset + 11] = 0x00_u8 # Offset 1024

      # maxp table
      table_offset = offset + 28
      "maxp".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x05_u8
      data[table_offset + 11] = 0x00_u8 # Offset 1280

      # loca table
      table_offset = offset + 44
      "loca".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x06_u8
      data[table_offset + 11] = 0x00_u8 # Offset 1536

      # head table data
      offset = 1024
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8 # 2048 units per EM
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table data
      offset = 1280
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8 # 10 glyphs

      collection = FreeType::TrueType::Collection.new(data)
      collection.should_not be_nil
      collection.is_collection?.should be_true
      collection.num_fonts.should eq(2)
    end

    it "should load individual fonts from collection" do
      data = Bytes.new(4096, 0_u8)

      # TTC header
      "ttcf".each_char_with_index do |c, i|
        data[i] = c.ord.to_u8
      end
      data[4] = 0x00_u8
      data[5] = 0x01_u8
      data[6] = 0x00_u8
      data[7] = 0x00_u8
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x01_u8 # 1 font

      # Font offset
      data[12] = 0x00_u8
      data[13] = 0x00_u8
      data[14] = 0x01_u8
      data[15] = 0x00_u8 # Offset 256

      # Font at offset 256
      offset = 256
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x03_u8

      # Tables
      table_offset = offset + 12
      "head".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x04_u8
      data[table_offset + 11] = 0x00_u8

      table_offset = offset + 28
      "maxp".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x05_u8
      data[table_offset + 11] = 0x00_u8

      table_offset = offset + 44
      "loca".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x06_u8
      data[table_offset + 11] = 0x00_u8

      # head table
      offset = 1024
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table
      offset = 1280
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      collection = FreeType::TrueType::Collection.new(data)
      font = collection.font(0)
      font.should_not be_nil
      font.num_glyphs.should eq(10)
    end

    it "should reject invalid font index" do
      data = Bytes.new(4096, 0_u8)

      "ttcf".each_char_with_index do |c, i|
        data[i] = c.ord.to_u8
      end
      data[4] = 0x00_u8
      data[5] = 0x01_u8
      data[6] = 0x00_u8
      data[7] = 0x00_u8
      data[8] = 0x00_u8
      data[9] = 0x00_u8
      data[10] = 0x00_u8
      data[11] = 0x01_u8

      data[12] = 0x00_u8
      data[13] = 0x00_u8
      data[14] = 0x01_u8
      data[15] = 0x00_u8

      offset = 256
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x03_u8

      table_offset = offset + 12
      "head".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x04_u8
      data[table_offset + 11] = 0x00_u8

      table_offset = offset + 28
      "maxp".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x05_u8
      data[table_offset + 11] = 0x00_u8

      table_offset = offset + 44
      "loca".each_char_with_index do |c, i|
        data[table_offset + i] = c.ord.to_u8
      end
      data[table_offset + 8] = 0x00_u8
      data[table_offset + 9] = 0x00_u8
      data[table_offset + 10] = 0x06_u8
      data[table_offset + 11] = 0x00_u8

      offset = 1024
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      offset = 1280
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      collection = FreeType::TrueType::Collection.new(data)

      expect_raises(CrImage::FormatError, /Font index out of range/) do
        collection.font(5)
      end
    end

    it "should detect non-collection fonts" do
      data = Bytes.new(2048, 0_u8)

      # Regular TrueType signature
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

      collection = FreeType::TrueType::Collection.new(data)
      collection.is_collection?.should be_false
      collection.num_fonts.should eq(1)

      # Should still be able to load as single font
      font = collection.font(0)
      font.should_not be_nil
    end
  end
end
