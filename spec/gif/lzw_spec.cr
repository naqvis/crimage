require "../spec_helper"

describe "CrImage::GIF::LZW" do
  describe "Basic compression and decompression" do
    it "compresses and decompresses simple data" do
      data = Bytes[1, 2, 3, 4, 5]

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles repetitive patterns" do
      data = Bytes[1, 2, 3, 1, 2, 3, 1, 2, 3]

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles all byte values" do
      data = Bytes.new(256) { |i| i.to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles empty data" do
      data = Bytes.new(0)

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles single byte" do
      data = Bytes[42]

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Large data handling" do
    it "handles 1KB of data" do
      data = Bytes.new(1024) { |i| (i % 256).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles 10KB of data" do
      data = Bytes.new(10240) { |i| (i % 256).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles highly repetitive data" do
      # Create data with repeating pattern
      data = Bytes.new(5000)
      pattern = Bytes[255, 0, 0, 255] # RGBA red
      (0...5000).each do |i|
        data[i] = pattern[i % 4]
      end

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
      compressed.size.should be < (data.size / 2) # Should compress well
    end

    it "handles data that fills dictionary" do
      # Create data that will fill the 4096-entry dictionary
      data = Bytes.new(10000) { |i| ((i * 37) % 256).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Different minimum code sizes" do
    it "works with 2-bit minimum code size" do
      data = Bytes[0, 1, 2, 3, 0, 1, 2, 3]

      compressed = CrImage::GIF::LZW.compress(data, 2)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 2)

      decompressed.should eq(data)
    end

    it "works with 4-bit minimum code size" do
      data = Bytes.new(100) { |i| (i % 16).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 4)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 4)

      decompressed.should eq(data)
    end

    it "works with 8-bit minimum code size" do
      data = Bytes.new(100) { |i| i.to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Compression efficiency" do
    it "compresses repetitive data effectively" do
      # Highly repetitive data
      data = Bytes.new(1000) { |i| (i / 100).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)

      # Should achieve significant compression
      compressed.size.should be < (data.size / 3)
    end

    it "handles incompressible data gracefully" do
      # Random-like data (hard to compress)
      data = Bytes.new(100) { |i| ((i * 37 + 17) % 256).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

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

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles patterns that create dictionary entries" do
      # Pattern designed to create many dictionary entries
      data = Bytes.new(500)
      (0...500).each do |i|
        data[i] = (i % 10).to_u8
      end

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles alternating bytes" do
      data = Bytes.new(200) { |i| (i % 2 == 0 ? 0_u8 : 255_u8) }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles dictionary reset" do
      # Create data that will force dictionary reset
      data = Bytes.new(20000)
      (0...20000).each do |i|
        data[i] = ((i // 5) & 0xFF).to_u8
      end

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles long repeated sequences" do
      # Very long sequence of same byte
      data = Bytes.new(5000, 42_u8)

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
      compressed.size.should be < 150 # Should compress well
    end

    it "handles sequences at dictionary boundary" do
      # Create pattern that will hit dictionary size limit
      data = Bytes.new(8192)
      (0...8192).each do |i|
        data[i] = ((i // 2) & 0xFF).to_u8
      end

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end
  end

  describe "Integration with paletted image data" do
    it "compresses paletted image data" do
      # Simulate 50x50 paletted image with 4 colors
      data = Bytes.new(2500)
      (0...2500).each do |i|
        y = i // 50
        x = i % 50
        data[i] = ((x + y) % 4).to_u8
      end

      compressed = CrImage::GIF::LZW.compress(data, 2)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 2)

      decompressed.should eq(data)
    end

    it "compresses grayscale-like paletted data" do
      # Simulate 100x100 grayscale image with 256 colors
      data = Bytes.new(10000) { |i| ((i // 100) * 25 % 256).to_u8 }

      compressed = CrImage::GIF::LZW.compress(data, 8)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 8)

      decompressed.should eq(data)
    end

    it "handles checkerboard pattern" do
      # Checkerboard pattern (common in test images)
      data = Bytes.new(10000)
      (0...10000).each do |i|
        y = i // 100
        x = i % 100
        data[i] = ((x + y) % 2).to_u8
      end

      compressed = CrImage::GIF::LZW.compress(data, 2)
      decompressed = CrImage::GIF::LZW.decompress(compressed, 2)

      decompressed.should eq(data)
    end
  end
end
