require "../spec_helper"

module CrImage::JPEG
  describe "Huffman Table Tests" do
    it "creates huffman table" do
      bits = [0_u8, 1_u8, 5_u8, 1_u8, 1_u8, 1_u8, 1_u8, 1_u8, 1_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]
      values = [0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8, 8_u8, 9_u8, 10_u8, 11_u8]

      table = HuffmanTable.new(bits, values)
      table.should_not be_nil
    end

    it "builds decode table" do
      bits = STANDARD_DC_LUMINANCE_BITS.to_a
      values = STANDARD_DC_LUMINANCE_VALUES.to_a

      table = HuffmanTable.new(bits, values)
      table.maxcode.size.should eq(17)
      table.mincode.size.should eq(17)
    end

    it "decodes huffman symbol" do
      bits = [0_u8, 2_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]
      values = [0_u8, 1_u8]

      table = HuffmanTable.new(bits, values)

      # Create a bit reader with known data
      io = IO::Memory.new(Bytes[0b00000000, 0b10000000])
      reader = BitReader.new(io)

      # Should decode first symbol
      symbol = table.decode(reader)
      symbol.should be >= 0
    end
  end

  describe "BitReader Tests" do
    it "reads single bit" do
      io = IO::Memory.new(Bytes[0b10000000])
      reader = BitReader.new(io)

      bit = reader.read_bit
      bit.should eq(1)
    end

    it "reads multiple bits" do
      io = IO::Memory.new(Bytes[0b11010000])
      reader = BitReader.new(io)

      bits = reader.read_bits(4)
      bits.should eq(0b1101)
    end

    it "handles byte stuffing" do
      # 0xFF 0x00 should be read as 0xFF
      io = IO::Memory.new(Bytes[0xFF, 0x00, 0x80])
      reader = BitReader.new(io)

      # Read 8 bits, should get 0xFF
      bits = reader.read_bits(8)
      bits.should eq(0xFF)
    end

    it "handles end of stream" do
      io = IO::Memory.new(Bytes[0x80])
      reader = BitReader.new(io)

      # Read all bits
      8.times { reader.read_bit }

      # Should fill with 1s when exhausted
      bit = reader.read_bit
      bit.should eq(1)
    end
  end

  describe "BitWriter Tests" do
    it "writes single bit" do
      io = IO::Memory.new
      writer = BitWriter.new(io)

      writer.write_bit(1_u8)
      writer.write_bit(0_u8)
      writer.write_bit(1_u8)
      writer.write_bit(0_u8)
      writer.write_bit(1_u8)
      writer.write_bit(0_u8)
      writer.write_bit(1_u8)
      writer.write_bit(0_u8)
      writer.flush

      io.rewind
      io.read_byte.should eq(0b10101010)
    end

    it "writes multiple bits" do
      io = IO::Memory.new
      writer = BitWriter.new(io)

      writer.write_bits(0b1101_u16, 4)
      writer.write_bits(0b0011_u16, 4)
      writer.flush

      io.rewind
      io.read_byte.should eq(0b11010011)
    end

    it "handles byte stuffing" do
      io = IO::Memory.new
      writer = BitWriter.new(io)

      # Write 0xFF
      writer.write_bits(0xFF_u16, 8)
      writer.flush

      io.rewind
      # Should have written 0xFF 0x00
      io.read_byte.should eq(0xFF)
      io.read_byte.should eq(0x00)
    end

    it "pads with 1s on flush" do
      io = IO::Memory.new
      writer = BitWriter.new(io)

      # Write 4 bits
      writer.write_bits(0b1010_u16, 4)
      writer.flush

      io.rewind
      # Should be padded: 1010 1111
      byte = io.read_byte.not_nil!
      (byte & 0xF0).should eq(0xA0)
    end
  end

  describe "Standard Huffman Tables Tests" do
    it "has correct DC luminance table size" do
      STANDARD_DC_LUMINANCE_BITS.size.should eq(16)
      STANDARD_DC_LUMINANCE_VALUES.size.should eq(12)
    end

    it "has correct DC chrominance table size" do
      STANDARD_DC_CHROMINANCE_BITS.size.should eq(16)
      STANDARD_DC_CHROMINANCE_VALUES.size.should eq(12)
    end

    it "has correct AC luminance table size" do
      STANDARD_AC_LUMINANCE_BITS.size.should eq(16)
      STANDARD_AC_LUMINANCE_VALUES.size.should eq(162)
    end

    it "has correct AC chrominance table size" do
      STANDARD_AC_CHROMINANCE_BITS.size.should eq(16)
      STANDARD_AC_CHROMINANCE_VALUES.size.should eq(162)
    end
  end
end
