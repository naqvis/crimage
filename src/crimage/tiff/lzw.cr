module CrImage::TIFF
  # LZW compression and decompression for TIFF images.
  # TIFF uses MSB-first bit ordering and "early change" code width increase.
  module LZW
    MAX_WIDTH = 12
    MAX_CODE  = 1 << MAX_WIDTH # 4096

    def self.compress(data : Bytes, lit_width : Int32) : Bytes
      Writer.new(lit_width).write(data)
    end

    def self.decompress(data : Bytes, lit_width : Int32) : Bytes
      Reader.new(data, lit_width).read_all
    end

    # LZW Reader (Decompressor) for TIFF
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

      @suffix : StaticArray(UInt8, 4096)
      @prefix : StaticArray(UInt16, 4096)
      @output : StaticArray(UInt8, 8192)
      @o : Int32

      INVALID_CODE = 0xffff_u16

      def initialize(@r : Bytes, @lit_width : Int32)
        @pos = 0
        @bits = 0_u32
        @n_bits = 0_u32
        @width = (1 + lit_width).to_u32

        @clear = (1_u16 << lit_width)
        @eof = @clear + 1
        @hi = @eof
        @overflow = (1_u16 << @width)
        @last = INVALID_CODE

        @suffix = StaticArray(UInt8, 4096).new(0_u8)
        @prefix = StaticArray(UInt16, 4096).new(0_u16)
        @output = StaticArray(UInt8, 8192).new(0_u8)
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
          code = read_code
          if code.nil?
            result = @o
            @o = 0
            return result
          end

          case
          when code < @clear
            # Literal code
            @output[@o] = (code & 0xFF).to_u8
            @o += 1
            if @last != INVALID_CODE
              @suffix[@hi] = (code & 0xFF).to_u8
              @prefix[@hi] = @last
            end
          when code == @clear
            # Reset
            @width = (1 + @lit_width).to_u32
            @hi = @eof
            @overflow = (1_u16 << @width)
            @last = INVALID_CODE
            next
          when code == @eof
            # End of data
            result = @o
            @o = 0
            return result
          when code <= @hi
            # Code in table
            c = code
            i = @output.size - 1

            if code == @hi && @last != INVALID_CODE
              # Special case: code == hi
              c = @last
              while c >= @clear
                c = @prefix[c]
              end
              @output[i] = (c & 0xFF).to_u8
              i -= 1
              c = @last
            end

            # Walk the prefix chain
            while c >= @clear
              @output[i] = @suffix[c]
              i -= 1
              c = @prefix[c]
            end
            @output[i] = (c & 0xFF).to_u8

            # Copy to output (must handle overlapping regions)
            length = @output.size - i
            (0...length).each do |offset|
              @output[@o + offset] = @output[i + offset]
            end
            @o += length

            if @last != INVALID_CODE
              @suffix[@hi] = (c & 0xFF).to_u8
              @prefix[@hi] = @last
            end
          else
            raise "LZW: invalid code #{code}"
          end

          @last = code
          @hi += 1

          # TIFF uses "early change": increase width when hi+1 >= overflow
          if @hi + 1 >= @overflow
            if @width == MAX_WIDTH
              @last = INVALID_CODE
            else
              @width += 1
              @overflow <<= 1
            end
          end

          # Flush if buffer is getting full
          if @o >= 4096
            result = @o
            @o = 0
            return result
          end
        end
      end

      private def read_code : UInt16?
        # MSB first (TIFF)
        while @n_bits < @width && @pos < @r.size
          @bits |= @r[@pos].to_u32 << (24 - @n_bits)
          @n_bits += 8
          @pos += 1
        end

        return nil if @n_bits < @width

        code = (@bits >> (32 - @width)).to_u16
        @bits <<= @width
        @n_bits -= @width
        code
      end
    end

    # LZW Writer (Compressor) for TIFF
    private class Writer
      @lit_width : Int32
      @clear : UInt16
      @eof : UInt16
      @hi : UInt16
      @overflow : UInt16
      @width : UInt32

      @table : Hash(Bytes, UInt16)
      @output : IO::Memory
      @bits : UInt32
      @n_bits : UInt32

      def initialize(@lit_width : Int32)
        @clear = (1_u16 << lit_width)
        @eof = @clear + 1
        @hi = @eof + 1 # First new code is eof + 1
        @overflow = (1_u16 << (lit_width + 1))
        @width = (lit_width + 1).to_u32

        @table = Hash(Bytes, UInt16).new
        @output = IO::Memory.new
        @bits = 0_u32
        @n_bits = 0_u32

        init_table
      end

      def write(data : Bytes) : Bytes
        write_code(@clear)

        buffer = Bytes.new(256)
        buffer_len = 0

        data.each do |byte|
          # Try to extend the buffer
          buffer[buffer_len] = byte
          extended_key = buffer[0, buffer_len + 1]

          if @table.has_key?(extended_key)
            # Extended pattern is in table, keep it
            buffer_len += 1
          else
            # Extended pattern not in table
            # Output code for current buffer (before adding this byte)
            if buffer_len > 0
              write_code(@table[buffer[0, buffer_len]])
            end

            # Add extended pattern to table
            if @hi < MAX_CODE - 1
              @table[extended_key.dup] = @hi
              @hi += 1

              # TIFF uses "early change": increase width when hi >= overflow
              if @hi >= @overflow && @width < MAX_WIDTH
                @width += 1
                @overflow <<= 1
              end
            end

            # Start new buffer with current byte
            buffer[0] = byte
            buffer_len = 1
          end
        end

        # Output remaining buffer
        if buffer_len > 0
          write_code(@table[buffer[0, buffer_len]])
        end

        write_code(@eof)
        flush_bits

        @output.to_slice
      end

      private def init_table
        @table.clear
        (0...@clear).each do |i|
          @table[Bytes[i.to_u8]] = i.to_u16
        end
      end

      private def write_code(code : UInt16)
        # MSB first (TIFF)
        @bits = (@bits << @width) | code.to_u32
        @n_bits += @width

        while @n_bits >= 8
          @n_bits -= 8
          @output.write_byte(((@bits >> @n_bits) & 0xFF).to_u8)
        end
      end

      private def flush_bits
        if @n_bits > 0
          @output.write_byte(((@bits << (8 - @n_bits)) & 0xFF).to_u8)
        end
      end
    end
  end
end
