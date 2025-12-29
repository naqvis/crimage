require "../spec_helper"

describe "CrImage::TIFF::LZW" do
  describe "Basic compression and decompression" do
    it "compresses and decompresses simple data" do
      data = Bytes[1, 2, 3, 4, 5]

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles repetitive patterns" do
      data = Bytes[1, 2, 3, 1, 2, 3, 1, 2, 3]

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles all byte values" do
      data = Bytes.new(256) { |i| i.to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles empty data" do
      data = Bytes.new(0)

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles single byte" do
      data = Bytes[42]

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Large data handling" do
    it "handles 1KB of data" do
      data = Bytes.new(1024) { |i| (i % 256).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles 10KB of data" do
      data = Bytes.new(10240) { |i| (i % 256).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles highly repetitive data" do
      # Create data with repeating pattern
      data = Bytes.new(5000)
      pattern = Bytes[255, 0, 0, 255] # RGBA red
      (0...5000).each do |i|
        data[i] = pattern[i % 4]
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
      compressed.size.should be < (data.size / 2) # Should compress well
    end

    it "handles data that fills dictionary" do
      # Create data that will fill the 4096-entry dictionary
      data = Bytes.new(10000) { |i| ((i * 37) % 256).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "MSB-first bit ordering" do
    it "uses MSB-first encoding" do
      data = Bytes[1, 2, 3, 4, 5]

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)

      # TIFF LZW should produce different output than GIF LZW due to bit ordering
      gif_compressed = CrImage::GIF::LZW.compress(data, 8)
      compressed.should_not eq(gif_compressed)
    end

    it "handles MSB-first with various data patterns" do
      patterns = [
        Bytes[0, 1, 2, 3, 4, 5, 6, 7],
        Bytes[255, 254, 253, 252, 251, 250],
        Bytes[128, 64, 32, 16, 8, 4, 2, 1],
      ]

      patterns.each do |data|
        compressed = CrImage::TIFF::LZW.compress(data, 8)
        decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)
        decompressed.should eq(data)
      end
    end
  end

  describe "Early change code width" do
    it "increases code width early (TIFF behavior)" do
      # Create data that will trigger code width changes
      data = Bytes.new(2000)
      (0...2000).each do |i|
        data[i] = ((i / 8) % 256).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles transitions at dictionary boundaries" do
      # Pattern that creates entries near code width boundaries
      data = Bytes.new(1000)
      (0...1000).each do |i|
        data[i] = (i % 50).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Compression efficiency" do
    it "compresses repetitive data effectively" do
      # Highly repetitive data
      data = Bytes.new(1000) { |i| (i / 100).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)

      # Should achieve significant compression
      compressed.size.should be < (data.size / 3)
    end

    it "handles incompressible data gracefully" do
      # Random-like data (hard to compress)
      data = Bytes.new(100) { |i| ((i * 37 + 17) % 256).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Edge cases" do
    it "handles maximum code size transitions" do
      # Create data that will cause code size to increase from 9 to 12 bits
      data = Bytes.new(2000)
      (0...2000).each do |i|
        data[i] = ((i / 8) % 256).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles patterns that create dictionary entries" do
      # Pattern designed to create many dictionary entries
      data = Bytes.new(500)
      (0...500).each do |i|
        data[i] = (i % 10).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles alternating bytes" do
      data = Bytes.new(200) { |i| (i % 2 == 0 ? 0_u8 : 255_u8) }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles long repeated sequences" do
      # Very long sequence of same byte
      data = Bytes.new(5000, 42_u8)

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
      compressed.size.should be < 120 # Should compress extremely well
    end

    it "handles sequences at dictionary boundary" do
      # Create pattern that will hit dictionary size limit
      data = Bytes.new(8192)
      (0...8192).each do |i|
        data[i] = ((i // 2) & 0xFF).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles code at hi boundary (special case)" do
      # This tests the special case where code == hi
      data = Bytes.new(1000)
      (0...1000).each do |i|
        data[i] = ((i // 3) & 0xFF).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles maximum width reached" do
      # Create data that will reach 12-bit maximum width
      data = Bytes.new(15000)
      (0...15000).each do |i|
        data[i] = ((i // 4) & 0xFF).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Integration with RGBA image data" do
    it "compresses RGBA image data" do
      # Simulate 50x50 RGBA image (10000 bytes)
      data = Bytes.new(10000)
      (0...2500).each do |pixel|
        y = pixel // 50
        x = pixel % 50
        base = pixel * 4

        if (x + y) % 20 < 10
          data[base] = 255_u8     # R
          data[base + 1] = 0_u8   # G
          data[base + 2] = 0_u8   # B
          data[base + 3] = 255_u8 # A
        else
          data[base] = 0_u8       # R
          data[base + 1] = 0_u8   # G
          data[base + 2] = 255_u8 # B
          data[base + 3] = 255_u8 # A
        end
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
      compressed.size.should be < (data.size / 10) # Should compress very well
    end

    it "compresses grayscale image data" do
      # Simulate 100x100 grayscale image
      data = Bytes.new(10000) { |i| ((i // 100) * 25 % 256).to_u8 }

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "compresses paletted image data" do
      # Simulate 100x100 paletted image
      data = Bytes.new(10000)
      (0...10000).each do |i|
        y = i // 100
        x = i % 100
        data[i] = ((x + y) % 16).to_u8
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles checkerboard pattern" do
      # Checkerboard pattern (common in test images)
      data = Bytes.new(10000)
      (0...10000).each do |i|
        y = i // 100
        x = i % 100
        data[i] = ((x + y) % 2 == 0 ? 0_u8 : 255_u8)
      end

      compressed = CrImage::TIFF::LZW.compress(data, 8)
      decompressed = CrImage::TIFF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Comparison with GIF LZW" do
    it "produces different output than GIF LZW due to bit ordering" do
      test_data = [
        Bytes[1, 2, 3, 4, 5],
        Bytes.new(100) { |i| i.to_u8 },
        Bytes.new(500) { |i| (i % 10).to_u8 },
      ]

      test_data.each do |data|
        tiff_compressed = CrImage::TIFF::LZW.compress(data, 8)
        gif_compressed = CrImage::GIF::LZW.compress(data, 8)

        # Different bit ordering should produce different compressed data
        tiff_compressed.should_not eq(gif_compressed)

        # But both should decompress correctly
        CrImage::TIFF::LZW.decompress(tiff_compressed, 8).should eq(data)
        CrImage::GIF::LZW.decompress(gif_compressed, 8).should eq(data)
      end
    end
  end
end
