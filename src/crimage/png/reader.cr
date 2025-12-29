require "compress/zlib"
require "./png"
require "./paeth"
require "../image"
require "../decompression_guard"

module CrImage::PNG
  # InterlaceScan defines the placement and size of a pass for Adam7 interlacing.
  private record InterlaceScan, x_factor : Int32, y_factor : Int32, x_offset : Int32, y_offset : Int32

  # INTERLACING defines Adam7 interlacing, with 7 passes of reduced images.
  # See https://www.w3.org/TR/PNG/#8Interlace
  private INTERLACING = [
    InterlaceScan.new(8, 8, 0, 0),
    InterlaceScan.new(8, 8, 4, 0),
    InterlaceScan.new(4, 8, 0, 4),
    InterlaceScan.new(4, 4, 2, 0),
    InterlaceScan.new(2, 4, 0, 2),
    InterlaceScan.new(2, 2, 1, 0),
    InterlaceScan.new(1, 2, 0, 1),
  ]

  # Decoding stage.
  # The PNG specification says that the IHDR, PLTE (if present), tRNS (if
  # present), IDAT and IEND chunks must appear in that order. There may be
  # multiple IDAT chunks, and IDAT chunks must be sequential (i.e. they may not
  # have any other chunks between them).
  # https://www.w3.org/TR/PNG/#5ChunkOrdering

  enum DecodingStage
    START = 0
    IHDR
    PLTE
    TRNS
    IDAT
    IEND
    SKIP
  end

  # PNG image format decoder
  #
  # Implements PNG (Portable Network Graphics) decoding according to the PNG specification.
  # Supports all color types, bit depths, interlacing, and transparency modes.
  class Reader < IO
    getter io : IO
    getter image : CrImage::Image?

    getter width : Int32
    getter height : Int32
    getter depth : Int32

    private def initialize(@io, @decompression_config : DecompressionGuard::Config? = nil)
      @crc = CRC.new
      @width = 0
      @height = 0
      @depth = 0
      @palette = Color::Palette.new
      @cb = ColorBit::Invalid
      @stage = DecodingStage::START
      @idat_len = 0_u32
      @buffer = Bytes.new(3 * 256)
      @interlace = InterlaceType::None
      # use_transparent and transparent are used for grayscale and truecolor
      # transparency, as opposed to palette transparency
      @use_transparent = false
      @transparent = Bytes.new(8)
      @image = nil
      @decompression_guard = DecompressionGuard.create("PNG", @decompression_config)
      @compressed_bytes_read = 0_i64
      check_header
    end

    # read and decode the entire image
    def self.read(path : String) : CrImage::Image
      File.open(path) do |file|
        read(file)
      end
    end

    def self.read(io : IO) : CrImage::Image
      new(io).parse
    end

    # read and decode the configurations like color model, dimensions and
    # does not decode entire image. This returns CrImage::Config instead.
    def self.read_config(path : String) : CrImage::Config
      File.open(path) do |file|
        png = new(file)
        png.parse_config
      end
    end

    def self.read_config(io : IO) : CrImage::Config
      new(io).parse_config
    end

    def read(slice : Bytes)
      return 0 if slice.empty?
      while @idat_len == 0
        # We have exhausted an IDAT chunk. Verify the checksum of the chunk.
        verify_checksum

        # Read the length and chunk type of the next chunk, and check that
        # it is an IDAT chunk.
        io.read_fully(@buffer[...8])
        @idat_len = IO::ByteFormat::BigEndian.decode(UInt32, @buffer[0, 4])
        raise FormatError.new("not enough pixel data") unless String.new(@buffer[4...8]) == "IDAT"
        @crc.reset
        @crc.write(@buffer[4...8])
      end
      raise FormatError.new("IDAT chunk length overflow") if @idat_len.to_i < 0
      n = io.read(slice[...::Math.min(slice.size, @idat_len.to_i)])
      @crc.write(slice[...n])
      @idat_len -= n.to_u32

      # Track compressed bytes for decompression bomb detection
      @compressed_bytes_read += n.to_i64
      @decompression_guard.add_compressed(n)

      n
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("Can't write to PNG::Reader")
    end

    private def check_header
      size = io.read(@buffer[...PNG_HEADER.size])
      raise FormatError.new("Invalid file. Expecting header but got only #{size} bytes") unless size >= PNG_HEADER.size
      raise FormatError.new("Not a png file") unless @buffer[...size] == PNG_HEADER
    end

    protected def parse : CrImage::Image
      loop do
        break if @stage == DecodingStage::IEND
        parse_chunk
      end
      if m = @image
        m
      else
        raise FormatError.new("Unable to decode PNG")
      end
    end

    protected def parse_config : CrImage::Config
      loop do
        parse_chunk
        break if @stage == DecodingStage::IHDR && !@cb.paletted?
        break if @stage == DecodingStage::PLTE && @cb.paletted?
      end
      cm = case @cb
           when .g1?, .g2?, .g4?, .g8?
             Color.gray_model
           when .ga8?
             Color.nrgba_model
           when .tc8?
             Color.rgba_model
           when .p1?, .p2?, .p4?, .p8?
             @palette
           when .tca8?
             Color.nrgba_model
           when .g16?
             Color.gray16_model
           when .ga16?
             Color.nrgba64_model
           when .tc16?
             Color.rgba64_model
           when .tca16?
             Color.nrgba64_model
           else
             raise FormatError.new("Invalid combination of color type and bit depth")
           end
      CrImage::Config.new(cm, width, height)
    end

    private def parse_chunk
      read_bytes(8)
      length = IO::ByteFormat::BigEndian.decode(UInt32, @buffer[0, 4])
      tag = read_tag
      @crc.reset
      @crc.write(@buffer[4...8])
      case tag
      when .ihdr?
        raise FormatError.new("png： chunk out of order") unless @stage == DecodingStage::START
        @stage = DecodingStage::IHDR
        return parse_ihdr(length)
      when .plte?
        raise FormatError.new("png： chunk out of order") unless @stage == DecodingStage::IHDR
        @stage = DecodingStage::PLTE
        return parse_plte(length)
      when .trns?
        if @cb.paletted?
          raise FormatError.new("png： chunk out of order") unless @stage == DecodingStage::PLTE
        else
          raise FormatError.new("png： chunk out of order") unless @stage == DecodingStage::IHDR
        end
        @stage = DecodingStage::TRNS
        return parse_trns(length)
      when .idat?
        if (@stage == DecodingStage::IHDR && @cb.paletted?) ||
           (tag.value < DecodingStage::IHDR.value || tag.value > DecodingStage::IDAT.value)
          raise FormatError.new("png： chunk out of order")
        elsif @stage == DecodingStage::IDAT
          # Ignore trailing zero-length or garbage IDAT chunks.
          #
          # This does not affect valid PNG images that contain multiple IDAT
          # chunks, since the first call to parse_idat below will consume all
          # consecutive IDAT chunks required for decoding the image.

          # do nothing
        else
          @stage = DecodingStage::IDAT
          return parse_idat(length)
        end
      when .iend?
        raise FormatError.new("png： chunk out of order") unless @stage == DecodingStage::IDAT
        @stage = DecodingStage::IEND
        return parse_iend(length)
      else
        # Just skip
      end
      raise FormatError.new("Bad chunk length: #{length}") if length > 0x7fffffff

      # Ignore this chunk (of a known length).
      ignored = Bytes.new(4096)
      while length > 0
        n = io.read_fully(ignored[...::Math.min(length, ignored.size)])
        @crc.write(ignored[...n])
        length -= n
      end
      verify_checksum
    end

    private def read_tag
      tag = String.new(@buffer[4...8])
      begin
        DecodingStage.parse(tag)
      rescue ArgumentError
        DecodingStage::SKIP
      end
    end

    private def read_string(n : Int32)
      r = read_bytes(n)
      String.new(@buffer[...r])
    end

    def read_bytes(n)
      return 0 if n <= 0
      @buffer.to_unsafe.clear(@buffer.size)
      r = io.read(@buffer[...n])
      raise FormatError.new("Invalid file. Required to read #{n} bytes, but got #{r}") unless r == n
      r
    end

    private def valid_interlace(val)
      InterlaceType.from_value(val)
      true
    rescue
      false
    end

    private def parse_ihdr(length)
      raise FormatError.new("PNG: invalid IHDR length #{length}, expected 13") unless length == 13
      read_bytes(13)
      @crc.write(@buffer[...13])
      raise FormatError.new("PNG: unsupported compression method #{@buffer[10]}, only deflate (0) is supported") unless @buffer[10] == 0_u8
      raise FormatError.new("PNG: unsupported filter method #{@buffer[11]}, only adaptive filtering (0) is supported") unless @buffer[11] == 0_u8
      raise FormatError.new("PNG: invalid interlace method #{@buffer[12]}, must be 0 (none) or 1 (Adam7)") unless valid_interlace(@buffer[12])
      @interlace = InterlaceType.from_value(@buffer[12])

      w = IO::ByteFormat::BigEndian.decode(Int32, @buffer[0...4])
      h = IO::ByteFormat::BigEndian.decode(Int32, @buffer[4...8])
      raise FormatError.new("PNG: invalid dimensions #{w}x#{h}, width and height must be positive") unless w >= 0 && h >= 0
      n_pixels = w.to_i64 * h.to_i64
      raise FormatError.new("PNG: image too large, #{w}x#{h} exceeds maximum safe pixel count") if n_pixels > Int32::MAX.to_i64
      # There can be up to 8 bytes per pixel, for 16 bits per channel RGBA
      total_bytes = n_pixels * 8
      raise FormatError.new("PNG: image dimensions would cause buffer overflow") if total_bytes > Int64::MAX // 2

      @depth = @buffer[8].to_i32
      color_type = ColorType.from_value(@buffer[9])

      case depth
      when 1
        case color_type
        when .grayscale?
          @cb = ColorBit::G1
        when .paletted?
          @cb = ColorBit::P1
        else
          #
        end
      when 2
        case color_type
        when .grayscale?
          @cb = ColorBit::G2
        when .paletted?
          @cb = ColorBit::P2
        else
          #
        end
      when 4
        case color_type
        when .grayscale?
          @cb = ColorBit::G4
        when .paletted?
          @cb = ColorBit::P4
        else
          #
        end
      when 8
        case color_type
        when .grayscale?
          @cb = ColorBit::G8
        when .true_color?
          @cb = ColorBit::TC8
        when .paletted?
          @cb = ColorBit::P8
        when .grayscale_alpha?
          @cb = ColorBit::GA8
        when .true_color_alpha?
          @cb = ColorBit::TCA8
        else
          #
        end
      when 16
        case color_type
        when .grayscale?
          @cb = ColorBit::G16
        when .true_color?
          @cb = ColorBit::TC16
        when .grayscale_alpha?
          @cb = ColorBit::GA16
        when .true_color_alpha?
          @cb = ColorBit::TCA16
        else
          #
        end
      else
        @cb = ColorBit::Invalid
      end

      raise FormatError.new("PNG: unsupported format - bit depth #{@buffer[8]} with color type #{@buffer[9]} is not supported") if @cb == ColorBit::Invalid
      @width, @height = w.to_i32, h.to_i32
      verify_checksum
    end

    private def parse_plte(length)
      np = (length / 3).to_i # The number of palette entries
      if length % 3 != 0 || np <= 0 || np > 256 || np > 1 << depth.to_u32
        raise FormatError.new("PNG: invalid PLTE chunk length #{length}, must be divisible by 3 and contain 1-256 entries (max #{1 << depth.to_u32} for bit depth #{depth})")
      end
      n = read_bytes(3*np)
      @crc.write(@buffer[...n])
      case @cb
      when .p1?, .p2?, .p4?, .p8?
        colors = Array(Color::Color).new
        0.upto(np - 1) do |i|
          colors << Color::RGBA.new(@buffer[3*i + 0], @buffer[3*i + 1], @buffer[3*i + 2], 0xff)
        end
        @palette = Color::Palette.new(colors)
      when .tc8?, .tca8?, .tc16?, .tca16?
        # As per the PNG spec, a PLTE chunk is optional (and for practical purposes, ignorable)
        # for the TrueColor and TrueColorAlpha color types (section 4.1.2)
      else
        raise FormatError.new("PLTE, color type mismatch")
      end
      verify_checksum
    end

    private def parse_trns(length)
      case @cb
      when .g1?, .g2?, .g4?, .g8?, .g16?
        raise FormatError.new("bad tRNS length") unless length == 2
        n = read_bytes(length)
        @crc.write(@buffer[...n])
        @transparent[..].copy_from(@buffer[...length].to_unsafe, length)
        case @cb
        when .g1? then @transparent[1] &*= 0xff_u8
        when .g2? then @transparent[1] &*= 0x55_u8
        when .g4? then @transparent[1] &*= 0x11_u8
        else
          #
        end
        @use_transparent = true
      when .tc8?, .tc16?
        raise FormatError.new("bad tRNS length") unless length == 6
        n = read_bytes(length)
        @crc.write(@buffer[...n])
        @transparent[..].copy_from(@buffer[...length].to_unsafe, length)
        @use_transparent = true
      when .p1?, .p2?, .p4?, .p8?
        raise FormatError.new("bad tRNS legnth") if length > 256
        n = read_bytes(length)
        @crc.write(@buffer[...n])
        if @palette.size < n
          @pallete = Color::Palette.new(@palette[...n])
        end
        0.upto(n - 1) do |i|
          color = @palette[i]
          next unless color.is_a?(Color::RGBA)
          @palette[i] = Color::NRGBA.new(color.r, color.g, color.b, @buffer[i])
        end
      else
        raise FormatError.new("tRNS, color type mismatch")
      end
      verify_checksum
    end

    private def parse_idat(length)
      @idat_len = length

      # Validate expected decompressed size before starting decompression
      bytes_per_pixel = case @cb
                        when .g1?, .g2?, .g4?, .g8?, .p1?, .p2?, .p4?, .p8?
                          1
                        when .ga8?, .g16?
                          2
                        when .tc8?
                          3
                        when .tca8?, .ga16?, .tc16?
                          4
                        when .tca16?
                          8
                        else
                          4 # Conservative estimate
                        end

      @decompression_guard.validate_expected_size(@width, @height, bytes_per_pixel)

      reader = Compress::Zlib::Reader.new(self)

      if @interlace == InterlaceType::None
        img = self.read_image_pass(reader, 0, false)
      elsif @interlace == InterlaceType::Adam7
        # Allocate a blank image of the full size
        img = read_image_pass(reader, 0, true)

        0.upto(6) do |pass|
          image_pass = self.read_image_pass(reader, pass, false)
          if pimg = image_pass
            merge_pass_into(img, pimg, pass)
          end
        end
      end

      # Check for EOF, to verify the zlib checksum.
      n = 0
      i = 0
      while n == 0
        raise FormatError.new("Multiple reads returned no data") if i == 100
        n = reader.read_byte
        break if n.nil?
        i += 1
      end
      raise FormatError.new("too much pixel data") if @idat_len != 0
      verify_checksum
      @image = img
    end

    private def parse_iend(length)
      raise FormatError.new("bad IEND length") unless length == 0
      verify_checksum
    end

    private def verify_checksum
      chk = UInt32.from_io(io, IO::ByteFormat::BigEndian)
      raise FormatError.new("invalid checksum") unless chk == @crc.sum32
    end

    private def get_pass_image(l_width, l_height)
      case @cb
      when .g1?, .g2?, .g4?, .g8?
        {self.depth, @use_transparent ? CrImage::NRGBA.new(CrImage.rect(0, 0, l_width, l_height)) : CrImage::Gray.new(CrImage.rect(0, 0, l_width, l_height))}
      when .ga8?
        {16, CrImage::NRGBA.new(CrImage.rect(0, 0, l_width, l_height))}
      when .tc8?
        {24, @use_transparent ? CrImage::NRGBA.new(CrImage.rect(0, 0, l_width, l_height)) : CrImage::RGBA.new(CrImage.rect(0, 0, l_width, l_height))}
      when .p1?, .p2?, .p4?, .p8?
        {self.depth, CrImage::Paletted.new(CrImage.rect(0, 0, l_width, l_height), @palette)}
      when .tca8?
        {32, CrImage::NRGBA.new(CrImage.rect(0, 0, l_width, l_height))}
      when .g16?
        {16, @use_transparent ? CrImage::NRGBA64.new(CrImage.rect(0, 0, l_width, l_height)) : CrImage::Gray16.new(CrImage.rect(0, 0, l_width, l_height))}
      when .ga16?
        {32, CrImage::NRGBA64.new(CrImage.rect(0, 0, l_width, l_height))}
      when .tc16?
        {48, @use_transparent ? CrImage::NRGBA64.new(CrImage.rect(0, 0, l_width, l_height)) : CrImage::RGBA64.new(CrImage.rect(0, 0, l_width, l_height))}
      when .tca16?
        {64, CrImage::NRGBA64.new(CrImage.rect(0, 0, l_width, l_height))}
      else
        {0, nil}
      end
    end

    # reads a single image pass, sized according to the pass number
    private def read_image_pass(reader : IO, pass : Int32, allocate_only : Bool)
      l_width, l_height = width, height
      if @interlace == InterlaceType::Adam7 && !allocate_only
        p = INTERLACING[pass]
        # Add the multiplication factor and subtract one, effectively rounding up.
        l_width = ((l_width - p.x_offset + p.x_factor - 1) / p.x_factor).to_i
        l_height = ((l_height - p.y_offset + p.y_factor - 1) / p.y_factor).to_i

        # A PNG image can't have zero width or height, but for an interlaced image,
        # an individual pass might have zero width or height. If so, we shouldn't even
        # read a per-row filter type byte, so return early
        return nil if l_width == 0 || l_height == 0
      end
      pix_offset = 0
      bits_per_pixel, image = get_pass_image(l_width, l_height)
      raise FormatError.new("INvalid Color bit combination") if image.nil?

      return image if allocate_only

      bytes_per_pixel = ((bits_per_pixel + 7) / 8).to_i

      # The +1 is for the per-row filter type, which is at cr[0].
      row_size = 1 + ((bits_per_pixel * l_width + 7)/8).to_i

      # cr and pr are the bytes for the current and previous row
      cr = Bytes.new(row_size)
      pr = Bytes.new(row_size)

      0.upto(l_height - 1) do |y|
        # Read the decompressed bytes
        reader.read_fully(cr)

        # Track decompressed bytes for bomb detection
        @decompression_guard.add_decompressed(cr.size)

        # Apply the filter
        cdat = cr[1..]
        pdat = pr[1..]
        filter = FilterType.from_value(cr[0])

        case filter
        when .none?
          # No-op
        when .sub?
          bytes_per_pixel.upto(cdat.size - 1) do |i|
            cdat[i] &+= cdat[i - bytes_per_pixel]
          end
        when .up?
          pdat.each_with_index do |prev_data, idx|
            cdat[idx] &+= prev_data
          end
        when .average?
          # The first column has no column to the left of it, so it is a
          # special case. WE know that the first column exists because we
          # check above that width != 0 and so cdat.szie != 0
          0.upto(bytes_per_pixel - 1) do |i|
            cdat[i] &+= (pdat[i] // 2).to_u8
          end

          bytes_per_pixel.upto(cdat.size - 1) do |i|
            cdat[i] &+= ((cdat[i - bytes_per_pixel].to_i + pdat[i].to_i) / 2).to_u8
          end
        when .paeth?
          PNG.filter_paeth(cdat, pdat, bytes_per_pixel)
        end

        # Convert from bytes to colors.

        case @cb
        when .g1?
          convert_g1(image, cdat, y, l_width)
        when .g2?
          convert_g2(image, cdat, y, l_width)
        when .g4?
          convert_g4(image, cdat, y, l_width)
        when .g8?
          if @use_transparent
            ty = @transparent[1]
            img = image.as(CrImage::NRGBA)
            0.upto(l_width - 1) do |x|
              ycol = cdat[x]
              acol = 0xff_u8
              acol = 0x00_u8 if ycol == ty
              img.set_nrgba(x, y, Color::NRGBA.new(ycol, ycol, ycol, acol))
            end
          else
            gray = image.as(CrImage::Gray)
            gray.pix[pix_offset..].copy_from(cdat.to_unsafe, cdat.size)
            pix_offset += gray.stride
          end
        when .ga8?
          img = image.as(CrImage::NRGBA)
          0.upto(l_width - 1) do |x|
            ycol = cdat[2*x + 0]
            img.set_nrgba(x, y, Color::NRGBA.new(ycol, ycol, ycol, cdat[2*x + 1]))
          end
        when .tc8?
          pix_offset += convert_tc8(image, cdat, pix_offset, l_width)
        when .p1?
          paletted = image.as(CrImage::Paletted)
          0.step(to: l_width - 1, by: 8) do |x|
            b = cdat[(x/8).to_i]
            x2 = 0
            while x2 < 8 && x + x2 < l_width
              idx = b >> 7
              if paletted.palette.size <= idx.to_i
                # Initialize the rest of the palette to opaque black. The spec (section 11.2.3) says that
                # "any out-of-range pixel value found in the image data is an error", but some real-world PNG
                # files have out-of-range pixel values. We fall back to opaque black, the same as libpng 1.5.13;
                # ImageMagick 6.5.7 returns an error.
                paletted.palette.size.upto(idx) do |_|
                  paletted.palette << Color::RGBA.new(0x00, 0x00, 0x00, 0xff)
                end
              end
              paletted.set_color_index(x + x2, y, idx)
              b <<= 1
              x2 += 1
            end
          end
        when .p2?
          paletted = image.as(CrImage::Paletted)
          0.step(to: l_width - 1, by: 4) do |x|
            b = cdat[(x/4).to_i]
            x2 = 0
            while x2 < 4 && x + x2 < l_width
              idx = b >> 6
              if paletted.palette.size <= idx.to_i
                # Initialize the rest of the palette to opaque black. The spec (section 11.2.3) says that
                # "any out-of-range pixel value found in the image data is an error", but some real-world PNG
                # files have out-of-range pixel values. We fall back to opaque black, the same as libpng 1.5.13;
                # ImageMagick 6.5.7 returns an error.
                paletted.palette.size.upto(idx) do |_|
                  paletted.palette << Color::RGBA.new(0x00, 0x00, 0x00, 0xff)
                end
              end
              paletted.set_color_index(x + x2, y, idx)
              b <<= 2
              x2 += 1
            end
          end
        when .p4?
          paletted = image.as(CrImage::Paletted)
          0.step(to: l_width - 1, by: 2) do |x|
            b = cdat[(x/2).to_i]
            x2 = 0
            while x2 < 2 && x + x2 < l_width
              idx = b >> 4
              if paletted.palette.size <= idx.to_i
                # Initialize the rest of the palette to opaque black. The spec (section 11.2.3) says that
                # "any out-of-range pixel value found in the image data is an error", but some real-world PNG
                # files have out-of-range pixel values. We fall back to opaque black, the same as libpng 1.5.13;
                # ImageMagick 6.5.7 returns an error.
                paletted.palette.size.upto(idx) do |_|
                  paletted.palette << Color::RGBA.new(0x00, 0x00, 0x00, 0xff)
                end
              end
              paletted.set_color_index(x + x2, y, idx)
              b <<= 4
              x2 += 1
            end
          end
        when .p8?
          paletted = image.as(CrImage::Paletted)
          if paletted.palette.size != 256
            0.upto(l_width - 1) do |x|
              if paletted.palette.size <= cdat[x].to_i
                # Initialize the rest of the palette to opaque black. The spec (section 11.2.3) says that
                # "any out-of-range pixel value found in the image data is an error", but some real-world PNG
                # files have out-of-range pixel values. We fall back to opaque black, the same as libpng 1.5.13;
                # ImageMagick 6.5.7 returns an error.
                paletted.palette.size.upto(cdat[x].to_i) do |_|
                  paletted.palette << Color::RGBA.new(0x00, 0x00, 0x00, 0xff)
                end
              end
            end
          end
          paletted.pix[pix_offset..].copy_from(cdat.to_unsafe, cdat.size)
          pix_offset += paletted.stride
        when .tca8?
          nrgba = image.as(CrImage::NRGBA)
          nrgba.pix[pix_offset..].copy_from(cdat.to_unsafe, cdat.size)
          pix_offset += nrgba.stride
        when .g16?
          convert_g16(image, cdat, y, l_width)
        when .ga16?
          img = image.as(CrImage::NRGBA64)
          0.upto(l_width - 1) do |x|
            ycol = cdat[4*x + 0].to_u16 << 8 | cdat[4*x + 1].to_u16
            acol = cdat[4*x + 2].to_u16 << 8 | cdat[4*x + 3].to_u16
            img.set_nrgba64(x, y, Color::NRGBA64.new(ycol, ycol, ycol, acol))
          end
        when .tc16?
          if @use_transparent
            tr = @transparent[0].to_u16 << 8 | @transparent[1].to_u16
            tg = @transparent[2].to_u16 << 8 | @transparent[3].to_u16
            tb = @transparent[4].to_u16 << 8 | @transparent[5].to_u16
            img = image.as(CrImage::NRGBA64)
            0.upto(l_width - 1) do |x|
              rcol = cdat[6*x + 0].to_u16 << 8 | cdat[6*x + 1].to_u16
              gcol = cdat[6*x + 2].to_u16 << 8 | cdat[6*x + 3].to_u16
              bcol = cdat[6*x + 4].to_u16 << 8 | cdat[6*x + 5].to_u16
              acol = 0xffff_u16
              acol = 0x0000_u16 if rcol == tr && gcol == tg && bcol == tb
              img.set_nrgba64(x, y, Color::NRGBA64.new(rcol, gcol, bcol, acol))
            end
          else
            img = image.as(CrImage::RGBA64)
            0.upto(l_width - 1) do |x|
              rcol = cdat[6*x + 0].to_u16 << 8 | cdat[6*x + 1].to_u16
              gcol = cdat[6*x + 2].to_u16 << 8 | cdat[6*x + 3].to_u16
              bcol = cdat[6*x + 4].to_u16 << 8 | cdat[6*x + 5].to_u16

              img.set_rgba64(x, y, Color::RGBA64.new(rcol, gcol, bcol, 0xffff_u16))
            end
          end
        when .tca16?
          img = image.as(CrImage::NRGBA64)
          0.upto(l_width - 1) do |x|
            rcol = cdat[8*x + 0].to_u16 << 8 | cdat[8*x + 1].to_u16
            gcol = cdat[8*x + 2].to_u16 << 8 | cdat[8*x + 3].to_u16
            bcol = cdat[8*x + 4].to_u16 << 8 | cdat[8*x + 5].to_u16
            acol = cdat[8*x + 6].to_u16 << 8 | cdat[8*x + 7].to_u16
            img.set_nrgba64(x, y, Color::NRGBA64.new(rcol, gcol, bcol, acol))
          end
        else
          #
        end

        # The current row for y is the previous row for y+1.
        pr, cr = cr, pr
      end
      image
    end

    private def convert_g1(image, cdat, y, l_width)
      if @use_transparent
        ty = @transparent[1]
        0.step(to: l_width - 1, by: 8) do |x|
          b = cdat[(x/8).to_i]
          x2 = 0
          img = image.as(CrImage::NRGBA)
          while x2 < 8 && x + x2 < l_width
            ycol = (b >> 7).to_i * 0xff
            acol = 0xff_u8
            acol = 0x00_u8 if ycol == ty
            img.set_nrgba(x + x2, y, Color::NRGBA.new(ycol, ycol, ycol, acol))
            b <<= 1
            x2 += 1
          end
        end
      else
        0.step(to: l_width - 1, by: 8) do |x|
          b = cdat[(x / 8).to_i]
          x2 = 0
          img = image.as(CrImage::Gray)
          while x2 < 8 && x + x2 < l_width
            img.set_gray(x + x2, y, Color::Gray.new((b >> 7) * 0xff))
            b <<= 1
            x2 += 1
          end
        end
      end
    end

    private def convert_g2(image, cdat, y, l_width)
      if @use_transparent
        ty = @transparent[1]
        img = image.as(CrImage::NRGBA)
        0.step(to: l_width - 1, by: 4) do |x|
          b = cdat[(x/4).to_i]
          x2 = 0
          while x2 < 4 && x + x2 < l_width
            ycol = (b >> 6).to_i * 0x55
            acol = 0xff_u8
            acol = 0x00_u8 if ycol == ty
            img.set_nrgba(x + x2, y, Color::NRGBA.new(ycol, ycol, ycol, acol))
            b <<= 2
            x2 += 1
          end
        end
      else
        img = image.as(CrImage::Gray)
        0.step(to: l_width - 1, by: 4) do |x|
          b = cdat[(x / 4).to_i]
          x2 = 0
          while x2 < 4 && x + x2 < l_width
            img.set_gray(x + x2, y, Color::Gray.new((b >> 6) * 0x55))
            b <<= 2
            x2 += 1
          end
        end
      end
    end

    private def convert_g4(image, cdat, y, l_width)
      if @use_transparent
        ty = @transparent[1]
        img = image.as(CrImage::NRGBA)
        0.step(to: l_width - 1, by: 2) do |x|
          b = cdat[(x/2).to_i]
          x2 = 0
          while x2 < 2 && x + x2 < l_width
            ycol = (b >> 4).to_i * 0x11
            acol = 0xff_u8
            acol = 0x00_u8 if ycol == ty
            img.set_nrgba(x + x2, y, Color::NRGBA.new(ycol, ycol, ycol, acol))
            b <<= 4
            x2 += 1
          end
        end
      else
        img = image.as(CrImage::Gray)
        0.step(to: l_width - 1, by: 2) do |x|
          b = cdat[(x / 2).to_i]
          x2 = 0
          while x2 < 2 && x + x2 < l_width
            img.set_gray(x + x2, y, Color::Gray.new((b >> 4) * 0x11))
            b <<= 4
            x2 += 1
          end
        end
      end
    end

    private def convert_g16(image, cdat, y, l_width)
      if @use_transparent
        ty = @transparent[0].to_u16 << 8 | @transparent[1].to_u16
        img = image.as(CrImage::NRGBA64)
        0.upto(l_width - 1) do |x|
          ycol = cdat[2*x + 0].to_u16 << 8 | cdat[2*x + 1].to_u16
          acol = 0xffff_u16
          acol = 0x0000_u16 if ycol == ty
          img.set_nrgba64(x, y, Color::NRGBA64.new(ycol, ycol, ycol, acol))
        end
      else
        img = image.as(CrImage::Gray16)
        0.upto(l_width - 1) do |x|
          ycol = cdat[2*x + 0].to_u16 << 8 | cdat[2*x + 1].to_u16
          img.set_gray16(x, y, Color::Gray16.new(ycol))
        end
      end
    end

    private def convert_tc8(image, cdat, pix_offset, l_width)
      if @use_transparent
        nrgba = image.as(CrImage::NRGBA)
        pix, i, j = nrgba.pix, pix_offset, 0
        tr, tg, tb = @transparent[1], @transparent[3], @transparent[5]
        0.upto(l_width - 1) do |_|
          r = cdat[j + 0]
          g = cdat[j + 1]
          b = cdat[j + 2]
          a = 0xff_u8
          a = 0x00_u8 if r == tr && g == tg && b == tb
          pix[i + 0] = r
          pix[i + 1] = g
          pix[i + 2] = b
          pix[i + 3] = a
          i += 4
          j += 3
        end
        nrgba.stride
      else
        rgba = image.as(CrImage::RGBA)
        pix, i, j = rgba.pix, pix_offset, 0

        0.upto(l_width - 1) do |_|
          raise FormatError.new("PNG: pixel data buffer overflow") if j + 2 >= cdat.size || i + 3 >= pix.size
          pix[i + 0] = cdat[j + 0]
          pix[i + 1] = cdat[j + 1]
          pix[i + 2] = cdat[j + 2]
          pix[i + 3] = 0xff_u8
          i += 4
          j += 3
        end
        rgba.stride
      end
    end

    # merges a single pass into a full sized image.
    private def merge_pass_into(dst_img, src_img, pass)
      if (dst = dst_img) && (src = src_img)
        p = INTERLACING[pass]

        target = dst
        case target
        when CrImage::Alpha
          src_pix = src.as(CrImage::Alpha).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 1
        when CrImage::Alpha16
          src_pix = src.as(CrImage::Alpha16).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 2
        when CrImage::Gray
          src_pix = src.as(CrImage::Gray).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 1
        when CrImage::Gray16
          src_pix = src.as(CrImage::Gray16).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 2
        when CrImage::NRGBA
          src_pix = src.as(CrImage::NRGBA).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 4
        when CrImage::NRGBA64
          src_pix = src.as(CrImage::NRGBA64).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 8
        when CrImage::Paletted
          src_pix = src.as(CrImage::Paletted).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 1
        when CrImage::RGBA
          src_pix = src.as(CrImage::RGBA).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 4
        when CrImage::RGBA64
          src_pix = src.as(CrImage::RGBA64).pix
          dst_pix, stride, rect = target.pix, target.stride, target.rect
          bytes_per_pixel = 8
        else
          src_pix = Bytes.empty
          dst_pix = Bytes.empty
          stride = 0
          rect = CrImage::Rectangle.zero
          bytes_per_pixel = 0
        end

        s, bounds = 0, src.bounds
        bounds.min.y.upto(bounds.max.y - 1) do |y|
          dbase = (y*p.y_factor + p.y_offset - rect.min.y)*stride + (p.x_offset - rect.min.x)*bytes_per_pixel
          bounds.min.x.upto(bounds.max.x - 1) do |x|
            d = dbase + x*p.x_factor*bytes_per_pixel
            src_pix[s...s + bytes_per_pixel].copy_to(dst_pix[d...])
            s += bytes_per_pixel
          end
        end
      end
    end
  end
end
