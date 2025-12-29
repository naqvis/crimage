require "../spec_helper"

describe FreeType::TrueType do
  describe "Cmap Format 0" do
    it "should parse format 0 cmap (byte encoding)" do
      # Create minimal font with format 0 cmap
      data = Bytes.new(2048, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      # Number of tables: 4 (head, maxp, loca, cmap)
      data[4] = 0x00_u8
      data[5] = 0x04_u8

      # Table directory entries (16 bytes each)
      # Table 1: cmap at offset 12
      offset = 12
      "cmap".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8 # Offset 1024

      # Table 2: head at offset 28
      offset = 28
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8 # Offset 256

      # Table 3: maxp at offset 44
      offset = 44
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8 # Offset 512

      # Table 4: loca at offset 60
      offset = 60
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8 # Offset 768

      # head table at offset 256
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8 # 2048 units per EM
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8 # Short loca format

      # maxp table at offset 512
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0xFF_u8 # 255 glyphs

      # cmap table at offset 1024
      offset = 1024
      # cmap header
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8 # Version 0
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x01_u8 # 1 encoding table

      # Encoding record
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x01_u8 # Platform ID 1 (Macintosh)
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x00_u8 # Encoding ID 0 (Roman)
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x0C_u8 # Offset to subtable (12 bytes from cmap start)

      # Format 0 subtable at offset 1024 + 12 = 1036
      offset = 1036
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8 # Format 0
      data[offset + 2] = 0x01_u8
      data[offset + 3] = 0x06_u8 # Length 262 (6 + 256)
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x00_u8 # Language 0

      # Glyph ID array (256 bytes)
      # Map 'A' (65) to glyph 1
      data[offset + 6 + 65] = 0x01_u8
      # Map 'B' (66) to glyph 2
      data[offset + 6 + 66] = 0x02_u8
      # Map 'a' (97) to glyph 3
      data[offset + 6 + 97] = 0x03_u8

      font = FreeType::TrueType::Font.new(data)

      # Test character mapping
      font.glyph_index('A').should eq(1)
      font.glyph_index('B').should eq(2)
      font.glyph_index('a').should eq(3)
      font.glyph_index('Z').should eq(0) # Not mapped
    end
  end

  describe "Cmap Format 6" do
    it "should parse format 6 cmap (trimmed table)" do
      # Create minimal font with format 6 cmap
      data = Bytes.new(2048, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      # Number of tables: 4
      data[4] = 0x00_u8
      data[5] = 0x04_u8

      # Table directory (same as format 0 test)
      offset = 12
      "cmap".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8

      offset = 28
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 44
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      offset = 60
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      # head table
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      # cmap table at offset 1024
      offset = 1024
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x01_u8

      # Encoding record
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x03_u8 # Platform ID 3 (Windows)
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x01_u8 # Encoding ID 1 (Unicode BMP)
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x0C_u8

      # Format 6 subtable at offset 1036
      offset = 1036
      data[offset] = 0x00_u8
      data[offset + 1] = 0x06_u8 # Format 6
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x1A_u8 # Length 26 (10 + 16)
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x00_u8 # Language 0
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x41_u8 # First code 65 ('A')
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x08_u8 # Entry count 8

      # Glyph ID array (8 entries, 2 bytes each)
      # A=65 -> glyph 1
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x01_u8
      # B=66 -> glyph 2
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x02_u8
      # C=67 -> glyph 3
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x03_u8
      # D-H mapped to glyphs 4-8
      data[offset + 16] = 0x00_u8
      data[offset + 17] = 0x04_u8
      data[offset + 18] = 0x00_u8
      data[offset + 19] = 0x05_u8
      data[offset + 20] = 0x00_u8
      data[offset + 21] = 0x06_u8
      data[offset + 22] = 0x00_u8
      data[offset + 23] = 0x07_u8
      data[offset + 24] = 0x00_u8
      data[offset + 25] = 0x08_u8

      font = FreeType::TrueType::Font.new(data)

      # Test character mapping
      font.glyph_index('A').should eq(1)
      font.glyph_index('B').should eq(2)
      font.glyph_index('C').should eq(3)
      font.glyph_index('H').should eq(8)
      font.glyph_index('Z').should eq(0) # Outside range
      font.glyph_index('@').should eq(0) # Before range
    end
  end

  describe "Cmap Format 12" do
    it "should parse format 12 cmap (segmented coverage)" do
      # Create minimal font with format 12 cmap
      data = Bytes.new(2048, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      # Number of tables: 4
      data[4] = 0x00_u8
      data[5] = 0x04_u8

      # Table directory
      offset = 12
      "cmap".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
      data[offset + 11] = 0x00_u8

      offset = 28
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 44
      "maxp".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8

      offset = 60
      "loca".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8

      # head table
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      # cmap table at offset 1024
      offset = 1024
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x01_u8

      # Encoding record
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x03_u8 # Platform ID 3 (Windows)
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x0A_u8 # Encoding ID 10 (Unicode full)
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x0C_u8

      # Format 12 subtable at offset 1036
      offset = 1036
      data[offset] = 0x00_u8
      data[offset + 1] = 0x0C_u8 # Format 12
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8 # Reserved
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x00_u8
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x2C_u8 # Length 44 (16 + 2*12 + 4)
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x00_u8
      data[offset + 11] = 0x00_u8 # Language 0
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x00_u8
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x02_u8 # 2 groups

      # Group 1: A-Z (65-90) -> glyphs 1-26
      data[offset + 16] = 0x00_u8
      data[offset + 17] = 0x00_u8
      data[offset + 18] = 0x00_u8
      data[offset + 19] = 0x41_u8 # Start char 65 ('A')
      data[offset + 20] = 0x00_u8
      data[offset + 21] = 0x00_u8
      data[offset + 22] = 0x00_u8
      data[offset + 23] = 0x5A_u8 # End char 90 ('Z')
      data[offset + 24] = 0x00_u8
      data[offset + 25] = 0x00_u8
      data[offset + 26] = 0x00_u8
      data[offset + 27] = 0x01_u8 # Start glyph 1

      # Group 2: a-z (97-122) -> glyphs 27-52
      data[offset + 28] = 0x00_u8
      data[offset + 29] = 0x00_u8
      data[offset + 30] = 0x00_u8
      data[offset + 31] = 0x61_u8 # Start char 97 ('a')
      data[offset + 32] = 0x00_u8
      data[offset + 33] = 0x00_u8
      data[offset + 34] = 0x00_u8
      data[offset + 35] = 0x7A_u8 # End char 122 ('z')
      data[offset + 36] = 0x00_u8
      data[offset + 37] = 0x00_u8
      data[offset + 38] = 0x00_u8
      data[offset + 39] = 0x1B_u8 # Start glyph 27

      font = FreeType::TrueType::Font.new(data)

      # Test character mapping
      font.glyph_index('A').should eq(1)
      font.glyph_index('Z').should eq(26)
      font.glyph_index('a').should eq(27)
      font.glyph_index('z').should eq(52)
      font.glyph_index('0').should eq(0) # Not in any group
      font.glyph_index('[').should eq(0) # Between groups
    end
  end
end
