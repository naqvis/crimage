require "../spec_helper"

describe FreeType::TrueType do
  describe "Glyph Caching" do
    it "should cache glyph data" do
      data = Bytes.new(2048, 0_u8)

      # Create minimal valid font
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
      "glyf".each_char_with_index do |c, i|
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
      data[offset + 5] = 0x02_u8

      font = FreeType::TrueType::Font.new(data)

      # First access - should parse
      glyph1 = font.glyph_data(0)

      # Second access - should use cache
      glyph2 = font.glyph_data(0)

      # Should return same object (cached)
      glyph1.should eq(glyph2)
    end

    it "should clear glyph cache" do
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
      "glyf".each_char_with_index do |c, i|
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
      data[offset + 5] = 0x02_u8

      font = FreeType::TrueType::Font.new(data)

      # Access glyph to cache it
      font.glyph_data(0)

      # Clear cache
      font.clear_glyph_cache

      # Cache should be empty
      font.glyph_cache_size.should eq(0)
    end

    it "should report cache statistics" do
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
      "glyf".each_char_with_index do |c, i|
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
      data[offset + 5] = 0x02_u8

      font = FreeType::TrueType::Font.new(data)

      # Initially empty
      font.glyph_cache_size.should eq(0)

      # Access some glyphs
      font.glyph_data(0)
      font.glyph_data(1)

      # Should have 2 cached (even if nil)
      font.glyph_cache_size.should eq(2)
    end

    it "should limit cache size" do
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
      "glyf".each_char_with_index do |c, i|
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
      data[offset + 5] = 0x64_u8 # 100 glyphs

      font = FreeType::TrueType::Font.new(data)

      # Set cache limit
      font.max_cache_size = 10

      # Access more glyphs than limit
      15.times do |i|
        font.glyph_data(i)
      end

      # Cache should not exceed limit
      font.glyph_cache_size.should be <= 10
    end
  end
end
