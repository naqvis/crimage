module CrImage::GIF
  # LZW compression and decompression for GIF images.
  # Uses LSB (Least Significant Bits first) ordering as per GIF specification.
  module LZW
    MAX_WIDTH            =         12
    DECODER_INVALID_CODE = 0xffff_u16
    FLUSH_BUFFER         = 1 << MAX_WIDTH

    # Compresses data using LZW algorithm for GIF format
    def self.compress(data : Bytes, lit_width : Int32) : Bytes
      Writer.new(lit_width).write(data)
    end

    # Decompresses LZW compressed data from GIF format
    def self.decompress(data : Bytes, lit_width : Int32) : Bytes
      Reader.new(data, lit_width).read_all
    end

    # LZW Reader (Decompressor)
    private class Reader
      @r : Bytes
      @pos : Int32
      @bits : UInt32
      @n_bits : UInt32
      @width : UInt32
      @lit_width : Int32

      @clear : UInt16
      @eof : UInt16
      @hi : UInt16
      @overflow : UInt16
      @last : UInt16

      @suffix : Slice(UInt8)
      @prefix : Slice(UInt16)
      @output : Slice(UInt8)
      @o : Int32

      def initialize(@r : Bytes, @lit_width : Int32)
        @pos = 0
        @bits = 0_u32
        @n_bits = 0_u32
        @width = (1 + lit_width).to_u32

        @clear = (1_u16 << lit_width)
        @eof = @clear + 1
        @hi = @eof
        @overflow = (1_u16 << @width)
        @last = DECODER_INVALID_CODE

        @suffix = Slice(UInt8).new(4096, 0_u8)
        @prefix = Slice(UInt16).new(4096, 0_u16)
        @output = Slice(UInt8).new(8192, 0_u8)
        @o = 0
      end

      def read_all : Bytes
        result = IO::Memory.new

        loop do
          n = decode_chunk
          break if n == 0
          result.write(@output.to_slice[0, n])
          @o = 0
        end

        result.to_slice
      end

      private def decode_chunk : Int32
        loop do
          code = read_lsb
          return @o if code.nil?

          case
          when code < @clear
            # Literal code
            @output[@o] = (code & 0xFF).to_u8
            @o += 1
            if @last != DECODER_INVALID_CODE
              @suffix[@hi] = (code & 0xFF).to_u8
              @prefix[@hi] = @last
            end
          when code == @clear
            # Clear code - reset
            @width = (1 + @lit_width).to_u32
            @hi = @eof
            @overflow = (1_u16 << @width)
            @last = DECODER_INVALID_CODE
            next
          when code == @eof
            # EOF code
            return @o
          when code <= @hi
            # Code in table
            c = code
            i = @output.size - 1

            if code == @hi && @last != DECODER_INVALID_CODE
              # Special case: code == hi
              # This expands to the last expansion followed by the head of the last expansion
              c = @last
              while c >= @clear
                c = @prefix[c]
              end
              @output[i] = (c & 0xFF).to_u8
              i -= 1
              c = @last
            end

            # Copy the suffix chain into output
            while c >= @clear
              @output[i] = @suffix[c]
              i -= 1
              c = @prefix[c]
            end
            @output[i] = (c & 0xFF).to_u8

            # Copy to output buffer
            length = @output.size - i
            (0...length).each do |offset|
              @output[@o + offset] = @output[i + offset]
            end
            @o += length

            if @last != DECODER_INVALID_CODE
              @suffix[@hi] = (c & 0xFF).to_u8
              @prefix[@hi] = @last
            end
          else
            raise "LZW: invalid code #{code}"
          end

          @last = code
          @hi += 1

          # Check if we need to increase code width
          if @hi >= @overflow
            if @width == MAX_WIDTH
              @last = DECODER_INVALID_CODE
              # Undo the hi++ to maintain invariant that hi < overflow
              @hi -= 1
            else
              @width += 1
              @overflow = (1_u16 << @width)
            end
          end

          # Flush if buffer is getting full
          if @o >= FLUSH_BUFFER
            return @o
          end
        end
      end

      private def read_lsb : UInt16?
        # LSB first (GIF)
        while @n_bits < @width && @pos < @r.size
          @bits |= @r[@pos].to_u32 << @n_bits
          @n_bits += 8
          @pos += 1
        end

        return nil if @n_bits < @width

        code = (@bits & ((1 << @width) - 1)).to_u16
        @bits >>= @width
        @n_bits -= @width
        code
      end
    end

    # LZW Writer (Compressor)
    private class Writer
      MAX_CODE      = (1 << 12) - 1
      INVALID_CODE  = 0xffffffff_u32
      TABLE_SIZE    = 4 * (1 << 12)
      TABLE_MASK    = TABLE_SIZE - 1
      INVALID_ENTRY = 0_u32

      @lit_width : UInt32
      @width : UInt32
      @bits : UInt32
      @n_bits : Int32 # Changed to Int32 to avoid overflow issues
      @hi : UInt32
      @overflow : UInt32
      @saved_code : UInt32
      @table : Slice(UInt32)
      @output : IO::Memory

      def initialize(lit_width : Int32)
        @lit_width = lit_width.to_u32
        @width = 1_u32 + @lit_width
        @bits = 0_u32
        @n_bits = 0
        @hi = (1_u32 << @lit_width) + 1_u32
        @overflow = 1_u32 << (@lit_width + 1_u32)
        @saved_code = INVALID_CODE
        @table = Slice(UInt32).new(TABLE_SIZE, INVALID_ENTRY)
        @output = IO::Memory.new
      end

      def write(data : Bytes) : Bytes
        return Bytes.new(0) if data.size == 0

        code = @saved_code

        if code == INVALID_CODE
          # First write - send clear code
          clear = 1_u32 << @lit_width
          write_lsb(clear)
          # After clear code, next code is always a literal
          code = data[0].to_u32
          data = data[1..]
        end

        data.each do |byte|
          literal = byte.to_u32
          key = (code << 8) | literal

          # Check hash table for this key
          hash = ((key >> 12) ^ key) & TABLE_MASK
          found = false

          loop do
            t = @table[hash]
            if t == INVALID_ENTRY
              break
            end
            if key == (t >> 12)
              code = t & MAX_CODE
              found = true
              break
            end
            hash = (hash + 1) & TABLE_MASK
          end

          next if found

          # Write current code
          write_lsb(code)
          code = literal

          # Increment hi and check for overflow
          if inc_hi
            next
          end

          # Insert key -> hi into table
          hash = ((key >> 12) ^ key) & TABLE_MASK
          loop do
            if @table[hash] == INVALID_ENTRY
              @table[hash] = (key << 12) | @hi
              break
            end
            hash = (hash + 1) & TABLE_MASK
          end
        end

        @saved_code = code

        # Write final code and EOF
        if @saved_code != INVALID_CODE
          write_lsb(@saved_code)
          # inc_hi might send a clear code, ignore that error
          inc_hi
        else
          # Write clear code if no data was written
          clear = 1_u32 << @lit_width
          write_lsb(clear)
        end

        # Write EOF code
        eof = (1_u32 << @lit_width) + 1_u32
        write_lsb(eof)

        # Flush remaining bits
        # if @n_bits > 0
        #   @output.write_byte((@bits & 0xFF).to_u8)
        #   @bits = 0_u32
        #   @n_bits = 0
        # end

        @output.to_slice
      end

      private def inc_hi : Bool
        @hi += 1
        if @hi == @overflow
          @width += 1
          @overflow <<= 1
        end
        if @hi == MAX_CODE
          # Send clear code and reset
          clear = 1_u32 << @lit_width
          write_lsb(clear)
          @width = @lit_width + 1
          @hi = clear + 1
          @overflow = clear << 1
          @table.fill(INVALID_ENTRY)
          return true # Signal that we reset
        end
        false
      end

      private def write_lsb(code : UInt32)
        @bits |= (code << @n_bits).to_u32
        @n_bits += @width.to_i

        while @n_bits >= 8
          byte = (@bits & 0xFF).to_u8
          @output.write_byte(byte)
          @bits >>= 8
          @n_bits -= 8
        end
      end
    end
  end
end
