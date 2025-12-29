module CrImage::JPEG
  # Huffman table for JPEG encoding/decoding
  struct HuffmanTable
    property bits : Array(UInt8)    # Number of codes of each length (1-16)
    property values : Array(UInt8)  # Symbol values in order
    property codes : Array(UInt16)  # Generated Huffman codes
    property sizes : Array(UInt8)   # Code lengths for each symbol
    property maxcode : Array(Int32) # Largest code of each length
    property mincode : Array(Int32) # Smallest code of each length
    property valptr : Array(Int32)  # Index into values array

    def initialize(@bits : Array(UInt8), @values : Array(UInt8))
      @codes = [] of UInt16
      @sizes = [] of UInt8
      @maxcode = Array(Int32).new(17, -1)
      @mincode = Array(Int32).new(17, -1)
      @valptr = Array(Int32).new(17, 0)
      build_decode_table
    end

    # Build decoding lookup tables from bits and values arrays
    def build_decode_table : Nil
      # Derive minCodes, maxCodes, and valsIndices
      c = 0_i32
      index = 0_i32

      @bits.each_with_index do |num, idx|
        if num == 0
          @mincode[idx + 1] = -1
          @maxcode[idx + 1] = -1
          @valptr[idx + 1] = -1
        else
          @mincode[idx + 1] = c
          @maxcode[idx + 1] = c + num - 1
          @valptr[idx + 1] = index
          c += num
          index += num
        end
        c <<= 1
      end
    end

    # Decode the next Huffman symbol from the BitReader
    # Returns the decoded symbol value (0-255)
    def decode(reader : BitReader) : UInt8
      code = 0_i32
      0.upto(15) do |i|
        # Read one bit
        bit = reader.read_bit
        if bit != 0
          code |= 1
        end

        # Check if this code length has any codes
        # i is 0-indexed, tables are 1-indexed (index 0 is unused)
        table_idx = i + 1
        if code <= @maxcode[table_idx]
          # Found a valid code
          index = @valptr[table_idx] + code - @mincode[table_idx]
          return @values[index]
        end

        # Shift code left for next bit
        code <<= 1
      end

      # If we get here, we didn't find a valid code
      raise FormatError.new("bad Huffman code")
    end
  end

  # Standard JPEG Huffman table for DC coefficients (luminance)
  # From JPEG spec Annex K.3.1
  STANDARD_DC_LUMINANCE_BITS = [
    0_u8, 1_u8, 5_u8, 1_u8, 1_u8, 1_u8, 1_u8, 1_u8,
    1_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8,
  ]

  STANDARD_DC_LUMINANCE_VALUES = [
    0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8,
    8_u8, 9_u8, 10_u8, 11_u8,
  ]

  # Standard JPEG Huffman table for DC coefficients (chrominance)
  # From JPEG spec Annex K.3.2
  STANDARD_DC_CHROMINANCE_BITS = [
    0_u8, 3_u8, 1_u8, 1_u8, 1_u8, 1_u8, 1_u8, 1_u8,
    1_u8, 1_u8, 1_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8,
  ]

  STANDARD_DC_CHROMINANCE_VALUES = [
    0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8,
    8_u8, 9_u8, 10_u8, 11_u8,
  ]

  # Standard JPEG Huffman table for AC coefficients (luminance)
  # From JPEG spec Annex K.3.1
  STANDARD_AC_LUMINANCE_BITS = [
    0_u8, 2_u8, 1_u8, 3_u8, 3_u8, 2_u8, 4_u8, 3_u8,
    5_u8, 5_u8, 4_u8, 4_u8, 0_u8, 0_u8, 1_u8, 125_u8,
  ]

  STANDARD_AC_LUMINANCE_VALUES = [
    0x01_u8, 0x02_u8, 0x03_u8, 0x00_u8, 0x04_u8, 0x11_u8, 0x05_u8, 0x12_u8,
    0x21_u8, 0x31_u8, 0x41_u8, 0x06_u8, 0x13_u8, 0x51_u8, 0x61_u8, 0x07_u8,
    0x22_u8, 0x71_u8, 0x14_u8, 0x32_u8, 0x81_u8, 0x91_u8, 0xa1_u8, 0x08_u8,
    0x23_u8, 0x42_u8, 0xb1_u8, 0xc1_u8, 0x15_u8, 0x52_u8, 0xd1_u8, 0xf0_u8,
    0x24_u8, 0x33_u8, 0x62_u8, 0x72_u8, 0x82_u8, 0x09_u8, 0x0a_u8, 0x16_u8,
    0x17_u8, 0x18_u8, 0x19_u8, 0x1a_u8, 0x25_u8, 0x26_u8, 0x27_u8, 0x28_u8,
    0x29_u8, 0x2a_u8, 0x34_u8, 0x35_u8, 0x36_u8, 0x37_u8, 0x38_u8, 0x39_u8,
    0x3a_u8, 0x43_u8, 0x44_u8, 0x45_u8, 0x46_u8, 0x47_u8, 0x48_u8, 0x49_u8,
    0x4a_u8, 0x53_u8, 0x54_u8, 0x55_u8, 0x56_u8, 0x57_u8, 0x58_u8, 0x59_u8,
    0x5a_u8, 0x63_u8, 0x64_u8, 0x65_u8, 0x66_u8, 0x67_u8, 0x68_u8, 0x69_u8,
    0x6a_u8, 0x73_u8, 0x74_u8, 0x75_u8, 0x76_u8, 0x77_u8, 0x78_u8, 0x79_u8,
    0x7a_u8, 0x83_u8, 0x84_u8, 0x85_u8, 0x86_u8, 0x87_u8, 0x88_u8, 0x89_u8,
    0x8a_u8, 0x92_u8, 0x93_u8, 0x94_u8, 0x95_u8, 0x96_u8, 0x97_u8, 0x98_u8,
    0x99_u8, 0x9a_u8, 0xa2_u8, 0xa3_u8, 0xa4_u8, 0xa5_u8, 0xa6_u8, 0xa7_u8,
    0xa8_u8, 0xa9_u8, 0xaa_u8, 0xb2_u8, 0xb3_u8, 0xb4_u8, 0xb5_u8, 0xb6_u8,
    0xb7_u8, 0xb8_u8, 0xb9_u8, 0xba_u8, 0xc2_u8, 0xc3_u8, 0xc4_u8, 0xc5_u8,
    0xc6_u8, 0xc7_u8, 0xc8_u8, 0xc9_u8, 0xca_u8, 0xd2_u8, 0xd3_u8, 0xd4_u8,
    0xd5_u8, 0xd6_u8, 0xd7_u8, 0xd8_u8, 0xd9_u8, 0xda_u8, 0xe1_u8, 0xe2_u8,
    0xe3_u8, 0xe4_u8, 0xe5_u8, 0xe6_u8, 0xe7_u8, 0xe8_u8, 0xe9_u8, 0xea_u8,
    0xf1_u8, 0xf2_u8, 0xf3_u8, 0xf4_u8, 0xf5_u8, 0xf6_u8, 0xf7_u8, 0xf8_u8,
    0xf9_u8, 0xfa_u8,
  ]

  # Standard JPEG Huffman table for AC coefficients (chrominance)
  # From JPEG spec Annex K.3.2
  STANDARD_AC_CHROMINANCE_BITS = [
    0_u8, 2_u8, 1_u8, 2_u8, 4_u8, 4_u8, 3_u8, 4_u8,
    7_u8, 5_u8, 4_u8, 4_u8, 0_u8, 1_u8, 2_u8, 119_u8,
  ]

  STANDARD_AC_CHROMINANCE_VALUES = [
    0x00_u8, 0x01_u8, 0x02_u8, 0x03_u8, 0x11_u8, 0x04_u8, 0x05_u8, 0x21_u8,
    0x31_u8, 0x06_u8, 0x12_u8, 0x41_u8, 0x51_u8, 0x07_u8, 0x61_u8, 0x71_u8,
    0x13_u8, 0x22_u8, 0x32_u8, 0x81_u8, 0x08_u8, 0x14_u8, 0x42_u8, 0x91_u8,
    0xa1_u8, 0xb1_u8, 0xc1_u8, 0x09_u8, 0x23_u8, 0x33_u8, 0x52_u8, 0xf0_u8,
    0x15_u8, 0x62_u8, 0x72_u8, 0xd1_u8, 0x0a_u8, 0x16_u8, 0x24_u8, 0x34_u8,
    0xe1_u8, 0x25_u8, 0xf1_u8, 0x17_u8, 0x18_u8, 0x19_u8, 0x1a_u8, 0x26_u8,
    0x27_u8, 0x28_u8, 0x29_u8, 0x2a_u8, 0x35_u8, 0x36_u8, 0x37_u8, 0x38_u8,
    0x39_u8, 0x3a_u8, 0x43_u8, 0x44_u8, 0x45_u8, 0x46_u8, 0x47_u8, 0x48_u8,
    0x49_u8, 0x4a_u8, 0x53_u8, 0x54_u8, 0x55_u8, 0x56_u8, 0x57_u8, 0x58_u8,
    0x59_u8, 0x5a_u8, 0x63_u8, 0x64_u8, 0x65_u8, 0x66_u8, 0x67_u8, 0x68_u8,
    0x69_u8, 0x6a_u8, 0x73_u8, 0x74_u8, 0x75_u8, 0x76_u8, 0x77_u8, 0x78_u8,
    0x79_u8, 0x7a_u8, 0x82_u8, 0x83_u8, 0x84_u8, 0x85_u8, 0x86_u8, 0x87_u8,
    0x88_u8, 0x89_u8, 0x8a_u8, 0x92_u8, 0x93_u8, 0x94_u8, 0x95_u8, 0x96_u8,
    0x97_u8, 0x98_u8, 0x99_u8, 0x9a_u8, 0xa2_u8, 0xa3_u8, 0xa4_u8, 0xa5_u8,
    0xa6_u8, 0xa7_u8, 0xa8_u8, 0xa9_u8, 0xaa_u8, 0xb2_u8, 0xb3_u8, 0xb4_u8,
    0xb5_u8, 0xb6_u8, 0xb7_u8, 0xb8_u8, 0xb9_u8, 0xba_u8, 0xc2_u8, 0xc3_u8,
    0xc4_u8, 0xc5_u8, 0xc6_u8, 0xc7_u8, 0xc8_u8, 0xc9_u8, 0xca_u8, 0xd2_u8,
    0xd3_u8, 0xd4_u8, 0xd5_u8, 0xd6_u8, 0xd7_u8, 0xd8_u8, 0xd9_u8, 0xda_u8,
    0xe2_u8, 0xe3_u8, 0xe4_u8, 0xe5_u8, 0xe6_u8, 0xe7_u8, 0xe8_u8, 0xe9_u8,
    0xea_u8, 0xf2_u8, 0xf3_u8, 0xf4_u8, 0xf5_u8, 0xf6_u8, 0xf7_u8, 0xf8_u8,
    0xf9_u8, 0xfa_u8,
  ]

  # BitReader for reading bits from an IO stream
  # Handles JPEG byte stuffing (0xFF 0x00 sequences)
  class BitReader
    @buffer : UInt32   # Bit buffer
    @bits_left : Int32 # Number of valid bits in buffer
    @io : IO
    @end_of_scan : Bool # Flag to indicate we've hit a marker

    def initialize(@io : IO)
      @buffer = 0_u32
      @bits_left = 0
      @end_of_scan = false
    end

    # Read a single bit from the stream
    def read_bit : UInt8
      if @bits_left == 0
        fill_buffer
      end

      @bits_left -= 1
      bit = (@buffer >> @bits_left) & 1
      bit.to_u8
    end

    # Read n bits from the stream as a UInt16
    # n must be between 1 and 16
    def read_bits(n : Int32) : UInt16
      raise ArgumentError.new("n must be between 1 and 16") unless n >= 1 && n <= 16

      result = 0_u16
      n.times do
        result = (result << 1) | read_bit
      end
      result
    end

    # Read a byte-stuffed byte from the stream
    # Returns nil if we hit a marker (0xFF followed by non-0x00)
    private def read_byte_stuffed : UInt8?
      byte = @io.read_byte
      return nil if byte.nil?

      # If not 0xFF, return as-is
      return byte if byte != 0xFF

      # We have 0xFF, check next byte
      next_byte = @io.read_byte
      return nil if next_byte.nil?

      # 0xFF 0x00 is byte stuffing for 0xFF
      return 0xFF_u8 if next_byte == 0x00

      # 0xFF followed by non-0x00 is a marker - end of scan data
      # We don't consume the marker, but we can't "unread" it in Crystal
      # So we mark end of scan and return nil
      @end_of_scan = true
      nil
    end

    # Fill the bit buffer with the next byte from the stream
    # Handles JPEG byte stuffing: 0xFF 0x00 -> 0xFF
    private def fill_buffer : Nil
      # If we've hit end of scan, just fill with 1s to allow
      # decoding to complete with remaining bits
      if @end_of_scan
        @buffer = (@buffer << 8) | 0xFF
        @bits_left += 8
        return
      end

      byte = read_byte_stuffed

      if byte.nil?
        # Hit end of scan or end of stream
        # Fill with 1s to allow decoding to complete
        @end_of_scan = true
        @buffer = (@buffer << 8) | 0xFF
        @bits_left += 8
      else
        @buffer = (@buffer << 8) | byte
        @bits_left += 8
      end
    end

    # Align to byte boundary by discarding remaining bits
    def align_to_byte : Nil
      @bits_left = 0
      @buffer = 0_u32
    end
  end

  # BitWriter for writing bits to an IO stream
  # Handles JPEG byte stuffing (0xFF -> 0xFF 0x00)
  class BitWriter
    @buffer : UInt32   # Bit buffer
    @bits_used : Int32 # Number of bits currently in buffer
    @io : IO

    def initialize(@io : IO)
      @buffer = 0_u32
      @bits_used = 0
    end

    # Write a single bit to the stream
    def write_bit(bit : UInt8) : Nil
      @buffer = (@buffer << 1) | (bit & 1)
      @bits_used += 1

      if @bits_used == 8
        flush_byte
      end
    end

    # Write n bits from value to the stream
    # n must be between 1 and 16
    def write_bits(value : UInt16, n : Int32) : Nil
      raise ArgumentError.new("n must be between 1 and 16") unless n >= 1 && n <= 16

      # Write bits from most significant to least significant
      (n - 1).downto(0) do |i|
        bit = ((value >> i) & 1).to_u8
        write_bit(bit)
      end
    end

    # Flush remaining bits to the stream with padding
    # Pads with 1s as per JPEG spec
    def flush : Nil
      if @bits_used > 0
        # Pad with 1s to complete the byte
        while @bits_used < 8
          @buffer = (@buffer << 1) | 1
          @bits_used += 1
        end
        flush_byte
      end
    end

    # Flush a complete byte from the buffer to the stream
    # Handles JPEG byte stuffing: 0xFF -> 0xFF 0x00
    private def flush_byte : Nil
      byte = (@buffer & 0xFF).to_u8
      @io.write_byte(byte)

      # Handle byte stuffing in JPEG
      # If we write 0xFF, we must follow it with 0x00
      if byte == 0xFF
        @io.write_byte(0x00_u8)
      end

      @buffer = 0_u32
      @bits_used = 0
    end
  end
end
