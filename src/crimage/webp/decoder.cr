module CrImage::WEBP
  # Main WEBP decoder.
  #
  # Handles decoding of WebP images including:
  # - RIFF container parsing
  # - VP8X extended format support
  # - VP8L lossless decoding
  # - Alpha channel handling (ALPH chunks)
  # - VP8 lossy format (not yet implemented)
  module Decoder
    FCC_ALPH = FourCC.new("ALPH")
    FCC_VP8  = FourCC.new("VP8 ")
    FCC_VP8L = FourCC.new("VP8L")
    FCC_VP8X = FourCC.new("VP8X")
    FCC_WEBP = FourCC.new("WEBP")

    def self.decode(io : IO) : CrImage::Image
      decode_internal(io, config_only: false).as(CrImage::Image)
    end

    def self.decode_config(io : IO) : CrImage::Config
      decode_internal(io, config_only: true).as(CrImage::Config)
    end

    private def self.decode_internal(io : IO, config_only : Bool) : CrImage::Image | CrImage::Config
      form_type, riff_reader = CrImage::WEBP.new_riff_reader(io)

      raise FormatError.new("Not a WEBP file") unless form_type == FCC_WEBP

      alpha : Bytes? = nil
      alpha_stride = 0
      want_alpha = false
      seen_vp8x = false
      width_minus_one = 0_u32
      height_minus_one = 0_u32

      loop do
        chunk = riff_reader.next
        break unless chunk

        chunk_id, chunk_len, chunk_data = chunk

        case chunk_id
        when FCC_ALPH
          raise FormatError.new("Unexpected ALPH chunk") unless want_alpha
          want_alpha = false

          # Read preprocessing/filter/compression byte
          filter_byte = chunk_data.read_byte
          raise FormatError.new("Invalid ALPH chunk") unless filter_byte

          alpha, alpha_stride = read_alpha(
            chunk_data,
            width_minus_one,
            height_minus_one,
            filter_byte & 0x03
          )
          unfilter_alpha(alpha, alpha_stride, (filter_byte >> 2) & 0x03)
        when FCC_VP8
          raise FormatError.new("Invalid VP8 chunk") if want_alpha

          # TODO: VP8 lossy format is not yet implemented
          # The VP8 lossy decoder requires implementing the VP8 bitstream parser,
          # DCT/IDCT transforms, motion compensation, and loop filtering.
          raise NotImplementedError.new("VP8 lossy WebP decoding is not yet supported")
        when FCC_VP8L
          raise FormatError.new("Invalid VP8L chunk") if want_alpha || alpha

          if config_only
            return VP8L.decode_config(chunk_data)
          end

          # Pass chunk_data directly to VP8L decoder
          return VP8L.decode(chunk_data)
        when FCC_VP8X
          raise FormatError.new("Duplicate VP8X chunk") if seen_vp8x
          seen_vp8x = true
          raise FormatError.new("Invalid VP8X chunk size") unless chunk_len == 10

          buf = Bytes.new(10)
          chunk_data.read_fully(buf)

          flags = buf[0]
          want_alpha = (flags & 0x10) != 0

          width_minus_one = buf[4].to_u32 |
                            (buf[5].to_u32 << 8) |
                            (buf[6].to_u32 << 16)

          height_minus_one = buf[7].to_u32 |
                             (buf[8].to_u32 << 8) |
                             (buf[9].to_u32 << 16)

          if config_only
            color_model = want_alpha ? CrImage::Color.nrgba_model : CrImage::Color.ycbcr_model
            return CrImage::Config.new(
              color_model: color_model,
              width: (width_minus_one + 1).to_i32,
              height: (height_minus_one + 1).to_i32
            )
          end
        end
      end

      raise FormatError.new("Invalid WEBP format")
    end

    # Reads alpha channel data from ALPH chunk.
    #
    # Supports both uncompressed and VP8L-compressed alpha data.
    # Returns alpha bytes and stride.
    private def self.read_alpha(io : IO, width_minus_one : UInt32,
                                height_minus_one : UInt32,
                                compression : UInt8) : Tuple(Bytes, Int32)
      case compression
      when 0
        # Uncompressed
        w = (width_minus_one + 1).to_i32
        h = (height_minus_one + 1).to_i32
        alpha = Bytes.new(w * h)
        io.read_fully(alpha)
        {alpha, w}
      when 1
        # VP8L compressed alpha
        # Validate dimensions fit in 14 bits
        raise FormatError.new("Invalid alpha dimensions") if width_minus_one > 0x3fff || height_minus_one > 0x3fff

        # Synthesize a 5-byte VP8L header:
        # - 1 byte: magic number (0x2f)
        # - 14 bits: widthMinusOne
        # - 14 bits: heightMinusOne
        # - 1 bit: alphaIsUsed (ignored, zero)
        # - 3 bits: version (zero)
        header = Bytes.new(5)
        header[0] = 0x2f_u8 # VP8L magic number
        header[1] = (width_minus_one & 0xff).to_u8
        header[2] = (((width_minus_one >> 8) & 0x3f) | ((height_minus_one & 0x03) << 6)).to_u8
        header[3] = ((height_minus_one >> 2) & 0xff).to_u8
        header[4] = ((height_minus_one >> 10) & 0x0f).to_u8

        # Create a combined IO that reads the header first, then the chunk data
        combined_io = IO::Memory.new
        combined_io.write(header)
        IO.copy(io, combined_io)
        combined_io.rewind

        # Decode using VP8L decoder
        alpha_image = VP8L.decode(combined_io)

        # Extract green channel from NRGBA as alpha values
        # The green values of the inner NRGBA image are the alpha values
        nrgba = alpha_image.as(CrImage::NRGBA)
        pix = nrgba.pix
        w = (width_minus_one + 1).to_i32
        h = (height_minus_one + 1).to_i32
        alpha = Bytes.new(w * h)

        # Extract green channel (offset 1 in RGBA layout)
        (0...alpha.size).each do |i|
          alpha[i] = pix[4 * i + 1]
        end

        {alpha, w}
      else
        raise FormatError.new("Invalid alpha compression")
      end
    end

    # Applies inverse filtering to alpha channel data.
    #
    # WebP alpha channels can use prediction filters (horizontal, vertical,
    # gradient) to improve compression. This reverses those filters.
    #
    # Filter types:
    # - 0: None
    # - 1: Horizontal
    # - 2: Vertical
    # - 3: Gradient
    private def self.unfilter_alpha(alpha : Bytes, stride : Int32, filter : UInt8)
      return if alpha.empty? || stride == 0

      case filter
      when 0
        # No filter
      when 1
        # Horizontal filter
        # First row: horizontal filter
        (1...stride).each do |i|
          alpha[i] = alpha[i] &+ alpha[i - 1]
        end

        # Subsequent rows
        i = stride
        while i < alpha.size
          # First column uses vertical filter
          alpha[i] = alpha[i] &+ alpha[i - stride]

          # Rest of row uses horizontal filter
          (1...stride).each do |j|
            alpha[i + j] = alpha[i + j] &+ alpha[i + j - 1]
          end

          i += stride
        end
      when 2
        # Vertical filter
        # First row is equivalent to horizontal filter
        (1...stride).each do |i|
          alpha[i] = alpha[i] &+ alpha[i - 1]
        end

        # All remaining pixels use vertical filter
        (stride...alpha.size).each do |i|
          alpha[i] = alpha[i] &+ alpha[i - stride]
        end
      when 3
        # Gradient filter
        # First row is equivalent to horizontal filter
        (1...stride).each do |i|
          alpha[i] = alpha[i] &+ alpha[i - 1]
        end

        # Subsequent rows
        i = stride
        while i < alpha.size
          # First column is equivalent to vertical filter
          alpha[i] = alpha[i] &+ alpha[i - stride]

          # Interior is predicted on the three top/left pixels
          (1...stride).each do |j|
            c = alpha[i + j - stride - 1].to_i32
            b = alpha[i + j - stride].to_i32
            a = alpha[i + j - 1].to_i32
            x = a + b - c
            if x < 0
              x = 0
            elsif x > 255
              x = 255
            end
            alpha[i + j] = alpha[i + j] &+ x.to_u8
          end

          i += stride
        end
      end
    end
  end
end
