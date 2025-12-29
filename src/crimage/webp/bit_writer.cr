module CrImage::WEBP
  # BitWriter provides low-level utility for writing variable-length bit sequences
  # to a byte stream in little-endian order. It accumulates bits in a buffer and
  # flushes complete bytes to the output.
  #
  # This is used for writing VP8L bitstreams and Huffman-encoded data.
  class BitWriter
    # Internal buffer for accumulating output bytes
    @buffer : IO::Memory

    # Accumulates bits before writing complete bytes
    @bit_buffer : UInt64

    # Number of bits currently in bit_buffer
    @bit_buffer_size : Int32

    def initialize
      @buffer = IO::Memory.new
      @bit_buffer = 0_u64
      @bit_buffer_size = 0
    end

    # Write n bits from value in little-endian order.
    # n must be between 0 and 64.
    # value must fit within n bits.
    def write_bits(value : UInt64, n : Int32) : Nil
      raise ArgumentError.new("Invalid bit count: must be between 1 and 64") if n < 0 || n > 64

      # Validate value fits in n bits (this will catch n=0 with value > 0)
      raise ArgumentError.new("too many bits for the given value") if value >= (1_u64 << n)

      # Add bits to buffer
      @bit_buffer |= (value << @bit_buffer_size)
      @bit_buffer_size += n

      # Flush complete bytes
      write_through
    end

    # Write a byte array directly to the buffer.
    # Each byte is written as 8 bits.
    def write_bytes(bytes : Bytes) : Nil
      bytes.each do |byte|
        write_bits(byte.to_u64, 8)
      end
    end

    # Write a Huffman code with bit reversal.
    # WebP uses reversed Huffman codes, so we reverse the bits before writing.
    def write_code(code : HuffmanCode) : Nil
      # Skip if depth is 0 or negative
      return if code.depth <= 0

      raise ArgumentError.new("Code depth must be between 1 and 64, got #{code.depth}") unless code.depth >= 1 && code.depth <= 64

      # Reverse the bits
      reversed = reverse_bits(code.bits.to_u64, code.depth)

      # Write the reversed code
      write_bits(reversed, code.depth)
    end

    # Align to byte boundary by padding with zeros.
    # Rounds up to next multiple of 8 bits.
    def align_byte : Nil
      @bit_buffer_size = (@bit_buffer_size + 7) & ~7
      write_through
    end

    # Get the accumulated bytes as a Bytes slice
    # Note: This does NOT align to byte boundary automatically
    # Call align_byte explicitly if needed before calling this
    def to_slice : Bytes
      # Flush any complete bytes that haven't been written yet
      write_through

      @buffer.to_slice
    end

    # Internal method to flush complete bytes from bit_buffer to buffer
    private def write_through : Nil
      while @bit_buffer_size >= 8
        @buffer.write_byte((@bit_buffer & 0xFF).to_u8)
        @bit_buffer = @bit_buffer >> 8
        @bit_buffer_size = @bit_buffer_size - 8
      end
    end

    # Reverse the lowest n bits of value
    private def reverse_bits(value : UInt64, n : Int32) : UInt64
      result = 0_u64
      n.times do |i|
        if (value & (1_u64 << i)) != 0
          result |= (1_u64 << (n - 1 - i))
        end
      end
      result
    end
  end
end
