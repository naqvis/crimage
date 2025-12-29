require "../spec_helper"

describe FreeType::TrueType do
  describe "Font Validation" do
    it "should reject fonts with invalid signature" do
      data = Bytes.new(1024, 0_u8)

      # Invalid signature
      data[0] = 0xFF_u8
      data[1] = 0xFF_u8
      data[2] = 0xFF_u8
      data[3] = 0xFF_u8

      expect_raises(CrImage::FormatError, /Invalid font signature/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should reject fonts that are too small" do
      data = Bytes.new(10, 0_u8)

      expect_raises(CrImage::FormatError, /Font data too small/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should reject fonts with missing required tables" do
      data = Bytes.new(1024, 0_u8)

      # Valid signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      # Only 1 table (need at least head, maxp, loca)
      data[4] = 0x00_u8
      data[5] = 0x01_u8

      # Add only head table
      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8

      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8

      expect_raises(CrImage::FormatError, /Missing required font tables/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should validate table offsets are within bounds" do
      data = Bytes.new(1024, 0_u8)

      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x01_u8

      # Table with offset beyond file size
      offset = 12
      "head".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0xFF_u8
      data[offset + 9] = 0xFF_u8
      data[offset + 10] = 0xFF_u8
      data[offset + 11] = 0xFF_u8 # Offset way beyond file

      expect_raises(CrImage::FormatError, /Table offset out of bounds/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should validate units per em is reasonable" do
      data = Bytes.new(2048, 0_u8)

      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x03_u8

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

      # head table data with invalid units per em (0)
      offset = 256
      data[offset + 18] = 0x00_u8
      data[offset + 19] = 0x00_u8 # 0 units per EM (invalid)
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table data
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8

      expect_raises(CrImage::FormatError, /Invalid units per em/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should validate number of glyphs is reasonable" do
      data = Bytes.new(2048, 0_u8)

      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x03_u8

      # Tables setup
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

      # head table
      offset = 256
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8

      # maxp table with excessive glyphs
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8
      data[offset + 4] = 0xFF_u8
      data[offset + 5] = 0xFF_u8 # 65535 glyphs (suspicious)

      expect_raises(CrImage::FormatError, /Excessive number of glyphs/) do
        FreeType::TrueType::Font.new(data)
      end
    end

    it "should handle corrupted glyph data gracefully" do
      data = Bytes.new(2048, 0_u8)

      # Create valid font structure
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      data[4] = 0x00_u8
      data[5] = 0x04_u8

      # Setup tables
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
      "glyf".each_char_with_index do |c, i|
        data[offset + i] = c.ord.to_u8
      end
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x04_u8
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
      data[offset + 5] = 0x02_u8 # 2 glyphs

      # loca table (short format)
      offset = 768
      data[offset] = 0x00_u8
      data[offset + 1] = 0x00_u8 # Glyph 0 at offset 0
      data[offset + 2] = 0xFF_u8
      data[offset + 3] = 0xFF_u8 # Glyph 1 at invalid offset

      font = FreeType::TrueType::Font.new(data)

      # Should return nil for corrupted glyph, not crash
      glyph = font.glyph_data(1)
      glyph.should be_nil
    end
  end
end
