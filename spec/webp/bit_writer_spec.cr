require "../spec_helper"

module CrImage::WEBP
  describe BitWriter do
    describe "#write_bits" do
      it "writes 1 bit (not flushed yet)" do
        writer = BitWriter.new
        writer.write_bits(0b1_u64, 1)

        # to_slice only flushes complete bytes, 1 bit stays in buffer
        bytes = writer.to_slice
        bytes.size.should eq(0) # Not flushed yet (< 8 bits)
      end

      it "writes 8 bits and flushes to buffer" do
        writer = BitWriter.new
        writer.write_bits(0b11010101_u64, 8)

        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b11010101)
      end

      it "writes 16 bits and flushes to buffer" do
        writer = BitWriter.new
        writer.write_bits(0xFFFF_u64, 16)

        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xFF)
        bytes[1].should eq(0xFF)
      end

      it "writes 3 bits without flush" do
        writer = BitWriter.new
        writer.write_bits(0b101_u64, 3)

        # 3 bits stay in buffer, not flushed
        bytes = writer.to_slice
        bytes.size.should eq(0)

        # After align, they're flushed
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b101)
      end

      it "appends 2 bits to existing buffer" do
        writer = BitWriter.new
        writer.write_bits(0b1_u64, 1)
        writer.write_bits(0b10_u64, 2)

        # 3 bits total, not flushed yet
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b101)
      end

      it "appends 4 bits to existing 3 bits" do
        writer = BitWriter.new
        writer.write_bits(0b101_u64, 3)
        writer.write_bits(0b1111_u64, 4)

        # 7 bits total, not flushed yet
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b1111101)
      end

      it "preserves existing buffer content" do
        writer = BitWriter.new
        writer.write_bits(0xFF_u64, 8)
        writer.write_bits(0b101_u64, 3)

        # First 8 bits flushed, 3 bits remain
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0xFF)

        # After align, 3 bits are flushed
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xFF)
        bytes[1].should eq(0b101)
      end

      it "flushes 8 bits from accumulated buffer" do
        writer = BitWriter.new
        writer.write_bits(0b1101_u64, 4)
        writer.write_bits(0b1111_u64, 4)

        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0xFD) # 0b11111101
      end

      it "writes 16 bits after previous flush" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bits(0b1010101010101010_u64, 16)

        bytes = writer.to_slice
        bytes.size.should eq(3)
        bytes[0].should eq(0xAB)
        bytes[1].should eq(0xAA)
        bytes[2].should eq(0xAA)
      end

      it "raises error for bit count 0 with non-zero value" do
        writer = BitWriter.new
        expect_raises(ArgumentError, /too many bits/) do
          writer.write_bits(0b101_u64, 0)
        end
      end

      it "raises error for bit count exceeding 64" do
        writer = BitWriter.new
        expect_raises(ArgumentError) do
          writer.write_bits(0b101_u64, 65)
        end
      end

      it "raises error for negative bit count" do
        writer = BitWriter.new
        expect_raises(ArgumentError) do
          writer.write_bits(0b101_u64, -1)
        end
      end

      it "raises error for value too large for bit count" do
        writer = BitWriter.new
        expect_raises(ArgumentError) do
          writer.write_bits(0b101_u64, 2) # 5 doesn't fit in 2 bits
        end
      end
    end

    describe "#write_bytes" do
      it "writes single byte" do
        writer = BitWriter.new
        writer.write_bytes(Bytes[0xFF])

        result = writer.to_slice
        result.size.should eq(1)
        result[0].should eq(0xFF)
      end

      it "writes two bytes" do
        writer = BitWriter.new
        writer.write_bytes(Bytes[0x12, 0x34])

        result = writer.to_slice
        result.size.should eq(2)
        result[0].should eq(0x12)
        result[1].should eq(0x34)
      end

      it "preserves existing buffer" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bytes(Bytes[0xCD])

        result = writer.to_slice
        result.size.should eq(2)
        result[0].should eq(0xAB)
        result[1].should eq(0xCD)
      end

      it "handles partial bit buffer (1 bit) + new byte" do
        writer = BitWriter.new
        writer.write_bits(0b1_u64, 1)
        writer.write_bytes(Bytes[0x80])

        # 1 bit (0b1) + 8 bits (0x80) = 9 bits
        # bitBuf = 0b1 | (0x80 << 1) = 0b100000001
        # Flush 8 bits: 0b00000001 = 0x01
        # Remaining: 0b1 (1 bit)
        result = writer.to_slice
        result.size.should eq(1)
        result[0].should eq(0x01)
      end

      it "handles partial bit buffer (4 bits) + new byte" do
        writer = BitWriter.new
        writer.write_bits(0x00_u64, 8)
        writer.write_bits(0b1111_u64, 4)
        writer.write_bytes(Bytes[0x0F])

        result = writer.to_slice
        result.size.should eq(2)
        result[0].should eq(0x00)
        result[1].should eq(0xFF) # 0b1111 (4 bits) + 0x0F (8 bits) = 0b11111111 flushed
        # 4 bits remain in buffer
      end

      it "writes empty byte array" do
        writer = BitWriter.new
        writer.write_bytes(Bytes.empty)

        result = writer.to_slice
        result.size.should eq(0)
      end
    end

    describe "#write_code" do
      it "writes basic 3-bit code with reversal" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0b101, 3)
        writer.write_code(code)

        # 3 bits not flushed yet
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b101) # Reversed: 101 -> 101
      end

      it "writes 2-bit code with reversal" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0b10, 2)
        writer.write_code(code)

        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b01) # Reversed: 10 -> 01
      end

      it "writes 4-bit code with reversal" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0b1011, 4)
        writer.write_code(code)

        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b1101) # Reversed: 1011 -> 1101
      end

      it "appends 2 bits to existing buffer" do
        writer = BitWriter.new
        writer.write_bits(0b1_u64, 1)
        code = HuffmanCode.new(0, 0b10, 2)
        writer.write_code(code)

        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b011) # 1 + reversed(10) = 1 + 01 = 011
      end

      it "writes zero-depth code (no operation)" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0, 0)
        writer.write_code(code)

        bytes = writer.to_slice
        bytes.size.should eq(0)
      end

      it "flushes full byte with 4 bits remaining" do
        writer = BitWriter.new
        writer.write_bits(0b10101010_u64, 8)
        code = HuffmanCode.new(0, 0b1111, 4)
        writer.write_code(code)

        # 8 bits flushed, 4 bits remain
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b10101010)

        # After align, 4 bits flushed
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0b10101010)
        bytes[1].should eq(0b1111) # Reversed: 1111 -> 1111
      end

      it "writes 5-bit code with reversal" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0b10011, 5)
        writer.write_code(code)

        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b11001) # Reversed: 10011 -> 11001
      end

      it "handles negative depth (no operation)" do
        writer = BitWriter.new
        code = HuffmanCode.new(0, 0b1, -1)
        writer.write_code(code)

        bytes = writer.to_slice
        bytes.size.should eq(0)
      end
    end

    describe "#align_byte" do
      it "aligns 4 bits with no padding" do
        writer = BitWriter.new
        writer.write_bits(0b1101_u64, 4)
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0x0D)
      end

      it "does nothing when already aligned" do
        writer = BitWriter.new
        writer.write_bits(0b10101010_u64, 8)
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b10101010)
      end

      it "aligns 12 bits" do
        writer = BitWriter.new
        writer.write_bits(0b101010101010_u64, 12) # Only 12 bits
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xAA)
        bytes[1].should eq(0x0A)
      end

      it "aligns with existing buffer and 4 bits" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bits(0b1111_u64, 4)
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xAB)
        bytes[1].should eq(0x0F)
      end

      it "aligns 10 bits with existing buffer" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bits(0b1010101010_u64, 10)
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(3)
        bytes[0].should eq(0xAB)
        bytes[1].should eq(0xAA)
        bytes[2].should eq(0x02) # Only 2 bits from the 10-bit value in last byte
      end

      it "works with empty buffer" do
        writer = BitWriter.new
        writer.align_byte

        bytes = writer.to_slice
        bytes.size.should eq(0)
      end
    end

    describe "#write_through" do
      it "flushes exactly 8 bits" do
        writer = BitWriter.new
        writer.write_bits(0b11010101_u64, 8)
        # write_through is called internally by to_slice

        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0b11010101)
      end

      it "flushes multiple of 8 bits (16 bits)" do
        writer = BitWriter.new
        writer.write_bits(0b1111111111111111_u64, 16)

        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xFF)
        bytes[1].should eq(0xFF)
      end

      it "flushes 12 bits with 4 bit remainder" do
        writer = BitWriter.new
        writer.write_bits(0b101010101010_u64, 12) # Only 12 bits

        bytes = writer.to_slice
        bytes.size.should eq(1) # Only 8 bits flushed, 4 remain in buffer
        bytes[0].should eq(0b10101010)
      end

      it "does not flush less than 8 bits" do
        writer = BitWriter.new
        writer.write_bits(0b0000_u64, 4) # Only 4 bits

        bytes = writer.to_slice
        bytes.size.should eq(0) # Nothing flushed (< 8 bits)
      end

      it "preserves existing buffer contents" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bits(0b11010101_u64, 8)

        bytes = writer.to_slice
        bytes.size.should eq(2)
        bytes[0].should eq(0xAB)
        bytes[1].should eq(0xD5)
      end

      it "handles mixed existing buffer and partial flush" do
        writer = BitWriter.new
        writer.write_bits(0xAB_u64, 8)
        writer.write_bits(0b101010101010_u64, 12) # Only 12 bits

        bytes = writer.to_slice
        bytes.size.should eq(2) # 8 + 12 = 20 bits, only 16 flushed
        bytes[0].should eq(0xAB)
        bytes[1].should eq(0xAA)
      end
    end

    describe "#to_slice" do
      it "returns empty slice for new writer" do
        writer = BitWriter.new
        bytes = writer.to_slice
        bytes.size.should eq(0)
      end

      it "does not flush pending bits automatically" do
        writer = BitWriter.new
        writer.write_bits(0b1111_u64, 4)

        # to_slice does NOT auto-align
        bytes = writer.to_slice
        bytes.size.should eq(0)

        # After align, bits are flushed
        writer.align_byte
        bytes = writer.to_slice
        bytes.size.should eq(1)
        bytes[0].should eq(0x0F) # 0b00001111
      end

      it "can be called multiple times" do
        writer = BitWriter.new
        writer.write_bits(0xFF_u64, 8)

        bytes1 = writer.to_slice
        bytes2 = writer.to_slice

        bytes1.should eq(bytes2)
      end
    end

    describe "integration tests" do
      it "writes complex bit pattern" do
        writer = BitWriter.new

        # Simulate writing VP8L-like data
        writer.write_bits(0x2F_u64, 8) # Magic byte
        writer.write_bits(255_u64, 14) # Width - 1
        writer.write_bits(127_u64, 14) # Height - 1
        writer.write_bits(1_u64, 1)    # Alpha flag
        writer.write_bits(0_u64, 3)    # Version

        bytes = writer.to_slice
        bytes.size.should eq(5)
        bytes[0].should eq(0x2F)
      end

      it "mixes bits, bytes, and codes" do
        writer = BitWriter.new

        writer.write_bits(0b1010_u64, 4)
        writer.write_bytes(Bytes[0xAB])
        code = HuffmanCode.new(0, 0b110, 3)
        writer.write_code(code)
        writer.align_byte

        bytes = writer.to_slice
        # 4 bits + 8 bits + 3 bits = 15 bits, aligned to 16 bits = 2 bytes
        bytes.size.should eq(2)
      end

      it "handles large data stream" do
        writer = BitWriter.new

        # Write 1000 bits
        100.times do
          writer.write_bits(0b1010101010_u64, 10)
        end

        bytes = writer.to_slice
        # 1000 bits = 125 bytes
        bytes.size.should eq(125)
      end
    end
  end
end
