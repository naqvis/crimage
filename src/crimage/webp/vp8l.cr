module CrImage::WEBP
  # VP8L lossless decoder for WEBP.
  #
  # Implements the VP8L lossless image format used in WebP. Handles:
  # - Bitstream parsing
  # - Huffman decoding
  # - LZ77 backward references
  # - Color cache
  # - Transform decoding (predictor, color, subtract green, palette)
  module VP8L
    COLOR_CACHE_MULTIPLIER = 0x1e35a7bd_u32

    # Huffman alphabet sizes
    N_LITERAL_CODES  = 256
    N_LENGTH_CODES   =  24
    N_DISTANCE_CODES =  40

    # Distance map table for LZ77 backwards references
    DISTANCE_MAP_TABLE = StaticArray[
      0x18_u8, 0x07, 0x17, 0x19, 0x28, 0x06, 0x27, 0x29, 0x16, 0x1a,
      0x26, 0x2a, 0x38, 0x05, 0x37, 0x39, 0x15, 0x1b, 0x36, 0x3a,
      0x25, 0x2b, 0x48, 0x04, 0x47, 0x49, 0x14, 0x1c, 0x35, 0x3b,
      0x46, 0x4a, 0x24, 0x2c, 0x58, 0x45, 0x4b, 0x34, 0x3c, 0x03,
      0x57, 0x59, 0x13, 0x1d, 0x56, 0x5a, 0x23, 0x2d, 0x44, 0x4c,
      0x55, 0x5b, 0x33, 0x3d, 0x68, 0x02, 0x67, 0x69, 0x12, 0x1e,
      0x66, 0x6a, 0x22, 0x2e, 0x54, 0x5c, 0x43, 0x4d, 0x65, 0x6b,
      0x32, 0x3e, 0x78, 0x01, 0x77, 0x79, 0x53, 0x5d, 0x11, 0x1f,
      0x64, 0x6c, 0x42, 0x4e, 0x76, 0x7a, 0x21, 0x2f, 0x75, 0x7b,
      0x31, 0x3f, 0x63, 0x6d, 0x52, 0x5e, 0x00, 0x74, 0x7c, 0x41,
      0x4f, 0x10, 0x20, 0x62, 0x6e, 0x30, 0x73, 0x7d, 0x51, 0x5f,
      0x40, 0x72, 0x7e, 0x61, 0x6f, 0x50, 0x71, 0x7f, 0x60, 0x70,
    ]

    # Maps distance code to pixel offset.
    #
    # VP8L uses special distance codes for nearby pixels to improve
    # compression. Specified in section 4.2.2 of the VP8L spec.
    def self.distance_map(width : Int32, code : UInt32) : Int32
      if code.to_i32 > DISTANCE_MAP_TABLE.size
        return code.to_i32 - DISTANCE_MAP_TABLE.size
      end
      dist_code = DISTANCE_MAP_TABLE[code - 1].to_i32
      y_offset = dist_code >> 4
      x_offset = 8 - (dist_code & 0xf)
      d = y_offset * width + x_offset
      d >= 1 ? d : 1
    end

    # Calculates number of tiles needed to cover size pixels.
    #
    # Used for transform metadata (predictor, color transform).
    def self.n_tiles(size : Int32, bits : UInt32) : Int32
      (size + (1 << bits) - 1) >> bits
    end

    # Buffered IO wrapper for efficient byte reading.
    #
    # Reduces IO calls by reading chunks into a buffer.
    class BufferedReader
      @io : IO
      @buffer : Bytes
      @pos : Int32
      @limit : Int32

      def initialize(@io : IO, buffer_size : Int32 = 4096)
        @buffer = Bytes.new(buffer_size)
        @pos = 0
        @limit = 0
      end

      def read_byte : UInt8?
        if @pos >= @limit
          # Refill buffer
          @pos = 0
          @limit = @io.read(@buffer)
          return nil if @limit == 0
        end
        byte = @buffer[@pos]
        @pos += 1
        byte
      end
    end

    # Bit reader for VP8L bitstream.
    #
    # Reads variable-length bit sequences from byte stream in little-endian
    # order. Maintains bit buffer for efficient access.
    class BitReader
      @io : IO
      @buffered_reader : BufferedReader
      @bits : UInt32
      @n_bits : UInt32
      @bytes_read : Int32

      def initialize(@io : IO)
        @buffered_reader = BufferedReader.new(@io)
        @bits = 0_u32
        @n_bits = 0_u32
        @bytes_read = 0
      end

      def bytes_read
        @bytes_read
      end

      def read(n : UInt32) : UInt32
        while @n_bits < n
          byte = @buffered_reader.read_byte
          if byte.nil?
            raise FormatError.new("Unexpected EOF in read(#{n})")
          end
          @bits |= byte.to_u32 << @n_bits
          @n_bits += 8
          @bytes_read += 1
        end

        result = @bits & ((1_u32 << n) - 1)
        @bits >>= n
        @n_bits -= n
        result
      end

      # Tries to ensure we have at least n bits available.
      #
      # Returns false if EOF reached before n bits available.
      def ensure_bits(n : UInt32) : Bool
        while @n_bits < n
          byte = @buffered_reader.read_byte
          return false unless byte
          @bits |= byte.to_u32 << @n_bits
          @n_bits += 8
          @bytes_read += 1
        end
        true
      end

      # Peeks at the next n bits without consuming them.
      #
      # Returns the next n bits from the buffer without advancing position.
      def peek(n : UInt32) : UInt32
        @bits & ((1_u32 << n) - 1)
      end

      # Consume n bits
      def consume(n : UInt32)
        @bits >>= n
        @n_bits = @n_bits > n ? @n_bits - n : 0_u32
      end

      # Get current bit count
      def available_bits : UInt32
        @n_bits
      end
    end

    # Decodes VP8L configuration (dimensions and color model).
    #
    # Reads only the VP8L header to extract image metadata without
    # decoding the full image data.
    #
    # Returns: Config with dimensions and NRGBA color model
    def self.decode_config(io : IO) : CrImage::Config
      reader = BitReader.new(io)

      # Read magic byte
      magic = reader.read(8)
      raise FormatError.new("Invalid VP8L header") unless magic == 0x2f

      # Read dimensions
      width = reader.read(14) + 1
      height = reader.read(14) + 1

      # Read and ignore alpha hint
      reader.read(1)

      # Read version
      version = reader.read(3)
      raise FormatError.new("Invalid VP8L version") unless version == 0

      CrImage::Config.new(
        color_model: CrImage::Color.nrgba_model,
        width: width.to_i32,
        height: height.to_i32
      )
    end

    # Decodes VP8L image from IO stream.
    #
    # Parses VP8L bitstream, decodes transforms, Huffman codes, and
    # reconstructs the image.
    #
    # Returns: Decoded NRGBA image
    def self.decode(io : IO) : CrImage::Image
      decoder = Decoder.new(io)
      decoder.decode
    end
  end
end

require "./vp8l/*"
