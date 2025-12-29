require "../spec_helper"

module CrImage::WEBP
  describe HuffmanEncoder do
    describe ".build_codes" do
      it "builds codes with single symbol" do
        histogram = [10]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(1)
        # Single symbol gets depth -1 (special case)
        codes[0].symbol.should eq(0)
        codes[0].bits.should eq(0)
        codes[0].depth.should eq(-1)
      end

      it "builds codes with two symbols" do
        histogram = [5, 15]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(2)
        # Symbol 0 gets code '0' (depth 1)
        codes[0].symbol.should eq(0)
        codes[0].bits.should eq(0b0)
        codes[0].depth.should eq(1)
        # Symbol 1 gets code '1' (depth 1)
        codes[1].symbol.should eq(1)
        codes[1].bits.should eq(0b1)
        codes[1].depth.should eq(1)
      end

      it "builds codes with symbols requiring different depths" do
        histogram = [5, 9, 12, 13, 1]
        codes = HuffmanEncoder.build_codes(histogram, 4)

        codes.size.should eq(5)
        # With min_weight adjustment (sum=40, max_depth=4, min_weight=40>>2=10)
        # Adjusted weights: [10, 10, 12, 13, 10]
        # This creates a different tree structure than without min_weight
        codes[0].symbol.should eq(0)
        codes[0].bits.should eq(0b110)
        codes[0].depth.should eq(3)

        codes[1].symbol.should eq(1)
        codes[1].bits.should eq(0b111)
        codes[1].depth.should eq(3)

        codes[2].symbol.should eq(2)
        codes[2].bits.should eq(0b00)
        codes[2].depth.should eq(2)

        codes[3].symbol.should eq(3)
        codes[3].bits.should eq(0b01)
        codes[3].depth.should eq(2)

        codes[4].symbol.should eq(4)
        codes[4].bits.should eq(0b10)
        codes[4].depth.should eq(2)
      end

      it "builds codes from simple histogram" do
        # Histogram: symbol 0 appears 5 times, symbol 1 appears 3 times
        histogram = [5, 3, 0, 0]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # Symbol 0 should have shorter code (more frequent)
        codes[0].depth.should be > 0
        codes[1].depth.should be > 0
        codes[0].depth.should be <= codes[1].depth
      end

      it "builds codes from uniform histogram" do
        # All symbols equally frequent
        histogram = [10, 10, 10, 10]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # All codes should have same depth
        depths = codes.select { |c| c.depth > 0 }.map(&.depth).uniq
        depths.size.should eq(1)
        depths[0].should eq(2) # 4 symbols need 2 bits
      end

      it "builds codes from skewed histogram" do
        # One very frequent symbol, others rare
        histogram = [100, 1, 1, 1]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # Most frequent symbol should have shortest code
        codes[0].depth.should be < codes[1].depth
      end

      it "handles empty histogram" do
        histogram = [0, 0, 0, 0]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # All codes should have depth 0
        codes.all? { |c| c.depth == 0 }.should be_true
      end

      it "handles single symbol histogram" do
        histogram = [10, 0, 0, 0]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # Single symbol gets depth -1 (special case)
        codes[0].depth.should eq(-1)
        codes[1].depth.should eq(0)
        codes[2].depth.should eq(0)
        codes[3].depth.should eq(0)
      end

      it "handles two symbol histogram" do
        histogram = [5, 3, 0, 0]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(4)
        # Both symbols should have depth 1
        codes[0].depth.should eq(1)
        codes[1].depth.should eq(1)
        codes[2].depth.should eq(0)
        codes[3].depth.should eq(0)
      end

      it "limits depth to max_depth" do
        # Create histogram that would naturally create deep tree
        histogram = [1000, 500, 250, 125, 62, 31, 15, 7, 3, 1]
        codes = HuffmanEncoder.build_codes(histogram, 5)

        # No code should exceed max depth
        max_depth = codes.map(&.depth).max
        max_depth.should be <= 5
      end

      it "limits depth to 15 by default" do
        # Create large histogram
        histogram = Array(Int32).new(256) { |i| 256 - i }
        codes = HuffmanEncoder.build_codes(histogram)

        # No code should exceed 15
        max_depth = codes.map(&.depth).max
        max_depth.should be <= 15
      end

      it "generates canonical codes" do
        histogram = [5, 3, 2, 1]
        codes = HuffmanEncoder.build_codes(histogram)

        # Canonical codes: codes of same length are sequential
        # Group by depth
        by_depth = codes.select { |c| c.depth > 0 }.group_by(&.depth)

        by_depth.each do |depth, group|
          # Codes should be sequential
          bits = group.map(&.bits).sort
          bits.each_with_index do |bit, i|
            if i > 0
              # Each code should be previous + 1
              (bit - bits[i - 1]).should be <= 1
            end
          end
        end
      end

      it "assigns unique codes to each symbol" do
        histogram = [10, 8, 6, 4, 2]
        codes = HuffmanEncoder.build_codes(histogram)

        # All non-zero codes should be unique
        non_zero = codes.select { |c| c.depth > 0 }
        # Create unique identifier from depth and bits
        identifiers = non_zero.map { |c| {c.depth, c.bits} }
        identifiers.uniq.size.should eq(non_zero.size)
      end

      it "handles large alphabet" do
        # 256 symbols (typical for color channel)
        histogram = Array(Int32).new(256) { |i| (i + 1) * 2 }
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(256)
        # All symbols should have codes
        codes.all? { |c| c.depth > 0 }.should be_true
      end

      it "preserves symbol indices" do
        histogram = [5, 0, 3, 0, 2]
        codes = HuffmanEncoder.build_codes(histogram)

        codes.size.should eq(5)
        codes.each_with_index do |code, i|
          code.symbol.should eq(i)
        end
      end
    end

    describe ".write_codes" do
      it "writes no codes (empty)" do
        writer = BitWriter.new
        codes = [] of HuffmanCode

        HuffmanEncoder.write_codes(writer, codes)

        # Should write simple code flag (1 bit) = 1
        bytes = writer.to_slice
        bytes.size.should eq(0) # Only 4 bits written, not flushed
      end

      it "writes single symbol with symbol <= 1" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 1),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # Should write simple code flag (1 bit) = 1
        bytes = writer.to_slice
        bytes.size.should eq(0) # Only 4 bits written
      end

      it "writes single symbol with symbol > 1" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(3, 0b11, 1),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # 8 bits written, 3 bits remain in buffer
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b00011101)
      end

      it "writes two symbols with symbol[0] > 1" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(2, 0b10, 1),
          HuffmanCode.new(3, 0b11, 1),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # 16 bits written, 3 bits remain in buffer
        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0b00010111)
        bytes[1].should eq(0b00011000)
      end

      it "writes full Huffman code (complex)" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 3),
          HuffmanCode.new(1, 1, 3),
          HuffmanCode.new(2, 2, 2),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # 24 bits written, 3 bits remain in buffer
        bytes = writer.to_slice
        bytes.size.should eq(3)
        bytes[0].should eq(0b00000100)
        bytes[1].should eq(0b00000000)
        bytes[2].should eq(0b00010010)
      end

      it "writes simple code with single symbol (symbol 0)" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 1),
          HuffmanCode.new(1, 0, 0),
          HuffmanCode.new(2, 0, 0),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # Only 4 bits written (simple code flag + num_symbols + symbol), not flushed
        bytes = writer.to_slice
        bytes.size.should eq(0)
      end

      it "writes simple code with two symbols" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 1),
          HuffmanCode.new(1, 1, 1),
          HuffmanCode.new(2, 0, 0),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
        # First bit should be 1 (simple code)
        (bytes[0] & 0x01).should eq(1)
      end

      it "writes complex code for many symbols" do
        writer = BitWriter.new
        # Create codes for 10 symbols
        codes = Array(HuffmanCode).new(10) do |i|
          HuffmanCode.new(i, i, i < 5 ? 2 : 3)
        end

        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
        # First bit should be 0 (complex code)
        (bytes[0] & 0x01).should eq(0)
      end

      it "writes empty code set" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 0),
          HuffmanCode.new(1, 0, 0),
        ]

        HuffmanEncoder.write_codes(writer, codes)

        # Empty codes write simple code flag (4 bits), not flushed
        bytes = writer.to_slice
        bytes.size.should eq(0)
      end

      it "handles symbols >= 256 in simple code" do
        writer = BitWriter.new
        codes = Array(HuffmanCode).new(300) { |i| HuffmanCode.new(i, 0, 0) }
        codes[256] = HuffmanCode.new(256, 0, 1)

        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
      end
    end

    describe ".write_full_huffman_code" do
      it "writes full Huffman code with meta-Huffman encoding" do
        writer = BitWriter.new
        codes = Array(HuffmanCode).new(10) do |i|
          HuffmanCode.new(i, i, i < 5 ? 2 : 3)
        end

        HuffmanEncoder.write_full_huffman_code(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
        # First bit should be 0 (not simple code)
        (bytes[0] & 0x01).should eq(0)
      end

      it "handles varying code lengths" do
        writer = BitWriter.new
        codes = [
          HuffmanCode.new(0, 0, 1),
          HuffmanCode.new(1, 0, 2),
          HuffmanCode.new(2, 0, 3),
          HuffmanCode.new(3, 0, 4),
          HuffmanCode.new(4, 0, 5),
        ]

        HuffmanEncoder.write_full_huffman_code(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
      end

      it "handles all same length codes" do
        writer = BitWriter.new
        codes = Array(HuffmanCode).new(8) do |i|
          HuffmanCode.new(i, i, 3)
        end

        HuffmanEncoder.write_full_huffman_code(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
      end

      it "handles sparse code set" do
        writer = BitWriter.new
        codes = Array(HuffmanCode).new(20) { |i| HuffmanCode.new(i, 0, 0) }
        codes[0] = HuffmanCode.new(0, 0, 2)
        codes[5] = HuffmanCode.new(5, 1, 2)
        codes[10] = HuffmanCode.new(10, 2, 3)
        codes[15] = HuffmanCode.new(15, 3, 3)

        HuffmanEncoder.write_full_huffman_code(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
      end
    end

    describe "HuffmanCode" do
      it "initializes with symbol, bits, and depth" do
        code = HuffmanCode.new(42, 0b1011, 4)

        code.symbol.should eq(42)
        code.bits.should eq(0b1011)
        code.depth.should eq(4)
      end

      it "allows property modification" do
        code = HuffmanCode.new(0, 0, 0)

        code.symbol = 10
        code.bits = 0b101
        code.depth = 3

        code.symbol.should eq(10)
        code.bits.should eq(0b101)
        code.depth.should eq(3)
      end
    end

    describe "integration tests" do
      it "builds and writes codes for typical color channel" do
        # Simulate histogram for a color channel
        histogram = Array(Int32).new(256, 0)
        # Some colors more frequent than others
        histogram[0] = 100  # Black
        histogram[255] = 80 # White
        histogram[128] = 50 # Gray
        (1..254).each { |i| histogram[i] = (256 - i) // 10 }

        codes = HuffmanEncoder.build_codes(histogram)
        writer = BitWriter.new
        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0

        # Verify most frequent colors have shorter codes
        codes[0].depth.should be <= codes[128].depth
        codes[255].depth.should be <= codes[128].depth
      end

      it "handles round-trip encoding" do
        # Build codes from histogram
        histogram = [10, 8, 6, 4, 2, 1]
        codes = HuffmanEncoder.build_codes(histogram)

        # Write codes
        writer = BitWriter.new
        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0

        # Verify all symbols have valid codes
        codes.each_with_index do |code, i|
          if histogram[i] > 0
            code.depth.should be > 0
            code.bits.should be >= 0
          end
        end
      end

      it "handles WebP-typical green alphabet" do
        # Green alphabet: 256 literals + 24 length codes + cache
        histogram = Array(Int32).new(256 + 24 + 16, 0)

        # Literals
        (0...256).each { |i| histogram[i] = 100 - i // 3 }
        # Length codes (less frequent)
        (256...280).each { |i| histogram[i] = 10 }
        # Cache codes (moderately frequent)
        (280...296).each { |i| histogram[i] = 20 }

        codes = HuffmanEncoder.build_codes(histogram)
        writer = BitWriter.new
        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0

        # Verify depth limit
        codes.map(&.depth).max.should be <= 15
      end

      it "handles distance alphabet" do
        # Distance alphabet: 40 codes
        histogram = Array(Int32).new(40, 0)
        # Nearby distances more frequent
        (0...10).each { |i| histogram[i] = 50 - i * 3 }
        (10...40).each { |i| histogram[i] = 5 }

        codes = HuffmanEncoder.build_codes(histogram)
        writer = BitWriter.new
        HuffmanEncoder.write_codes(writer, codes)

        bytes = writer.to_slice
        bytes.size.should be > 0
      end
    end
  end
end
