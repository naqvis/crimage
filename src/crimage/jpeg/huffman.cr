module CrImage::JPEG
  # Huffman table for JPEG encoding/decoding
  struct HuffmanTable
    FAST_BITS = 12
    FAST_SIZE = 1 << FAST_BITS

    property bits : Array(UInt8)    # Number of codes of each length (1-16)
    property values : Array(UInt8)  # Symbol values in order
    property codes : Array(UInt16)  # Generated Huffman codes
    property sizes : Array(UInt8)   # Code lengths for each symbol
    property maxcode : Array(Int32) # Largest code of each length
    property mincode : Array(Int32) # Smallest code of each length
    property valptr : Array(Int32)  # Index into values array
    property look_fast : Slice(UInt16)
    property encode_codes : StaticArray(UInt16, 256)
    property encode_sizes : StaticArray(UInt8, 256)

    def initialize(@bits : Array(UInt8), @values : Array(UInt8))
      @codes = [] of UInt16
      @sizes = [] of UInt8
      @maxcode = Array(Int32).new(17, -1)
      @mincode = Array(Int32).new(17, -1)
      @valptr = Array(Int32).new(17, 0)
      @look_fast = Slice(UInt16).new(FAST_SIZE, 0_u16)
      @encode_codes = StaticArray(UInt16, 256).new(0_u16)
      @encode_sizes = StaticArray(UInt8, 256).new(0_u8)
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

      code = 0_u16
      @bits.each_with_index do |num, idx|
        size = (idx + 1).to_u8
        num.times do
          @codes << code
          @sizes << size
          value = @values[@codes.size - 1]
          @encode_codes[value] = code
          @encode_sizes[value] = size

          if size <= FAST_BITS
            base = (code << (FAST_BITS - size)).to_i
            limit = 1 << (FAST_BITS - size)
            packed = ((size.to_u16 << 8) | value.to_u16)
            limit.times do |suffix|
              slot = base | suffix
              @look_fast[slot] = packed
            end
          end

          code += 1
        end
        code <<= 1
      end
    end

    # Decode the next Huffman symbol from the BitReader
    # Returns the decoded symbol value (0-255)
    @[AlwaysInline]
    def decode(reader : BitReader) : UInt8
      bits = reader.available_bits
      if bits >= FAST_BITS || reader.ensure_available_bits(FAST_BITS)
        packed = @look_fast[reader.peek_bits(FAST_BITS)]
        if packed != 0
          reader.skip_bits((packed >> 8).to_i32)
          return (packed & 0xFF).to_u8
        end
      elsif bits >= 8 || reader.ensure_available_bits(8)
        packed = @look_fast[reader.peek_bits(8) << (FAST_BITS - 8)]
        if packed != 0 && (packed >> 8) <= 8
          reader.skip_bits((packed >> 8).to_i32)
          return (packed & 0xFF).to_u8
        end
      end

      code = 0_i32
      0.upto(15) do |i|
        code = (code << 1) | reader.read_bit.to_i32

        # Check if this code length has any codes
        # i is 0-indexed, tables are 1-indexed (index 0 is unused)
        table_idx = i + 1
        if code <= @maxcode[table_idx]
          # Found a valid code
          index = @valptr[table_idx] + code - @mincode[table_idx]
          return @values[index]
        end
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
    @buffer : UInt64   # Bit buffer
    @bits_left : Int32 # Number of valid bits in buffer
    @io : IO
    @memory : IO::Memory?
    @mem_bytes : Bytes
    @mem_pos : Int32
    @end_of_scan : Bool # Flag to indicate we've hit a marker
    @saved_marker : UInt8?

    def initialize(@io : IO)
      @buffer = 0_u64
      @bits_left = 0
      @memory = @io.is_a?(IO::Memory) ? @io.as(IO::Memory) : nil
      @mem_bytes = @memory ? @memory.not_nil!.to_slice : Bytes.empty
      @mem_pos = @memory ? @memory.not_nil!.pos.to_i32 : 0
      @end_of_scan = false
      @saved_marker = nil
    end

    # Read a single bit from the stream
    @[AlwaysInline]
    def read_bit : UInt8
      ensure_bits(1) if @bits_left == 0
      @bits_left -= 1
      ((@buffer >> @bits_left) & 1).to_u8
    end

    # Read n bits from the stream as a UInt16
    # n must be between 1 and 16
    @[AlwaysInline]
    def read_bits(n : Int32) : UInt16
      ensure_bits(n) if @bits_left < n
      @bits_left -= n
      ((@buffer >> @bits_left) & ((1_u64 << n) - 1)).to_u16
    end

    @[AlwaysInline]
    def peek_bits(n : Int32) : Int32
      ensure_bits(n) if @bits_left < n
      ((@buffer >> (@bits_left - n)) & ((1_u64 << n) - 1)).to_i32
    end

    @[AlwaysInline]
    def skip_bits(n : Int32) : Nil
      ensure_bits(n) if @bits_left < n
      @bits_left -= n
    end

    @[AlwaysInline]
    def available_bits : Int32
      @bits_left
    end

    def saved_marker : UInt8?
      @saved_marker
    end

    def finish : Nil
      if memory = @memory
        memory.pos = @mem_pos
      end
    end

    @[AlwaysInline]
    def ensure_available_bits(n : Int32) : Bool
      return true if @bits_left >= n
      ensure_bits(n)
      @bits_left >= n
    end

    # Read a byte-stuffed byte from the stream
    # Returns nil if we hit a marker (0xFF followed by non-0x00)
    @[AlwaysInline]
    private def read_byte_stuffed : UInt8?
      if @memory
        return nil if @mem_pos >= @mem_bytes.size

        byte = @mem_bytes[@mem_pos]
        @mem_pos += 1

        return byte if byte != 0xFF

        return nil if @mem_pos >= @mem_bytes.size

        next_byte = @mem_bytes[@mem_pos]
        @mem_pos += 1

        return 0xFF_u8 if next_byte == 0x00

        @end_of_scan = true
        @saved_marker = next_byte
        return nil
      end

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
      # Save the marker byte so the parser can resume from the correct segment.
      @end_of_scan = true
      @saved_marker = next_byte
      nil
    end

    # Fill the bit buffer with the next byte from the stream
    # Handles JPEG byte stuffing: 0xFF 0x00 -> 0xFF
    @[AlwaysInline]
    private def fill_buffer : Nil
      # If we've hit end of scan, just fill with 1s to allow
      # decoding to complete with remaining bits
      if @end_of_scan
        @buffer = (@buffer << 8) | 0xFF_u64
        @bits_left += 8
        return
      end

      byte = read_byte_stuffed

      if byte.nil?
        # Hit end of scan or end of stream
        # Fill with 1s to allow decoding to complete
        @end_of_scan = true
        @buffer = (@buffer << 8) | 0xFF_u64
        @bits_left += 8
      else
        @buffer = (@buffer << 8) | byte
        @bits_left += 8
      end
    end

    @[AlwaysInline]
    private def ensure_bits(n : Int32) : Nil
      if @memory
        if @end_of_scan
          while @bits_left < n
            @buffer = (@buffer << 8) | 0xFF_u64
            @bits_left += 8
          end
          return
        end

        bytes = @mem_bytes
        pos = @mem_pos
        size = bytes.size

        while @bits_left < n && @bits_left <= 56 && pos < size
          byte = bytes[pos]
          pos += 1

          if byte == 0xFF
            if pos >= size
              @end_of_scan = true
              break
            end

            next_byte = bytes[pos]
            pos += 1

            if next_byte == 0x00
              byte = 0xFF_u8
            else
              @end_of_scan = true
              @saved_marker = next_byte
              break
            end
          end

          @buffer = (@buffer << 8) | byte
          @bits_left += 8
        end

        @mem_pos = pos
        @end_of_scan = true if pos >= size && @bits_left < n

        if @end_of_scan
          while @bits_left < n
            @buffer = (@buffer << 8) | 0xFF_u64
            @bits_left += 8
          end
        end
        return
      end

      while @bits_left < n
        fill_buffer
        break if @end_of_scan
      end
    end

    # Align to byte boundary by discarding remaining bits
    def align_to_byte : Nil
      @bits_left = 0
      @buffer = 0_u64
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
      masked = if n == 16
                 value.to_u32
               else
                 (value & ((1_u16 << n) &- 1_u16)).to_u32
               end

      @buffer = (@buffer << n) | masked
      @bits_used += n

      while @bits_used >= 8
        shift = @bits_used - 8
        byte = ((@buffer >> shift) & 0xFF).to_u8
        @io.write_byte(byte)
        @io.write_byte(0x00_u8) if byte == 0xFF
        @bits_used -= 8
        if @bits_used == 0
          @buffer = 0_u32
        else
          @buffer &= (1_u32 << @bits_used) &- 1_u32
        end
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
