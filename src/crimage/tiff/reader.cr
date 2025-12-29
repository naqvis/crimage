require "compress/zlib"
require "./tiff"
require "../image"
require "./lzw"

module CrImage::TIFF
  # TIFF (Tagged Image File Format) image decoder
  #
  # Implements TIFF decoding with support for various compression methods.
  class Reader
    MAX_CHUNK_SIZE = 10 << 20 # 10MB

    getter width : Int32
    getter height : Int32
    getter config : CrImage::Config

    @io : IO
    @byte_order : IO::ByteFormat
    @mode : ImageMode
    @bpp : UInt32
    @features : Hash(Tag, Array(UInt32))
    @palette : Color::Palette
    @buf : Bytes
    @off : Int32
    @v : UInt32
    @nbits : UInt32

    private def initialize(@io : IO)
      @byte_order = IO::ByteFormat::LittleEndian
      @width = 0
      @height = 0
      @mode = ImageMode::RGB
      @bpp = 0_u32
      @features = Hash(Tag, Array(UInt32)).new
      @palette = Color::Palette.new
      @buf = Bytes.new(0)
      @off = 0
      @v = 0_u32
      @nbits = 0_u32
      @config = CrImage::Config.new(Color.rgba_model, 0, 0)

      parse_header
    end

    def self.read(path : String) : CrImage::Image
      File.open(path, "rb") do |file|
        read(file)
      end
    end

    def self.read(io : IO) : CrImage::Image
      new(io).decode
    end

    def self.read_config(path : String) : CrImage::Config
      File.open(path, "rb") do |file|
        read_config(file)
      end
    end

    def self.read_config(io : IO) : CrImage::Config
      new(io).config
    end

    private def parse_header
      header = Bytes.new(8)
      @io.read_fully(header)

      case header[0, 4]
      when LE_HEADER
        @byte_order = IO::ByteFormat::LittleEndian
      when BE_HEADER
        @byte_order = IO::ByteFormat::BigEndian
      else
        raise FormatError.new("Invalid TIFF header: unrecognized byte order marker")
      end

      ifd_offset = @byte_order.decode(Int32, header[4, 4])
      parse_ifd(ifd_offset.to_i64)
      setup_config
    end

    private def parse_ifd(offset : Int64)
      @io.seek(offset)
      num_items_bytes = Bytes.new(2)
      @io.read_fully(num_items_bytes)
      num_items = @byte_order.decode(UInt16, num_items_bytes).to_i

      ifd_data = Bytes.new(IFD_LEN * num_items)
      @io.read_fully(ifd_data)

      prev_tag = -1
      num_items.times do |i|
        entry = ifd_data[i * IFD_LEN, IFD_LEN]
        tag_value = @byte_order.decode(UInt16, entry[0, 2])

        begin
          tag = Tag.from_value(tag_value)
        rescue
          next
        end

        raise FormatError.new("Invalid TIFF: tags not sorted in ascending order (tag #{tag.value} after #{prev_tag})") if tag.value <= prev_tag
        prev_tag = tag.value

        parse_ifd_entry(entry, tag)
      end

      @width = first_val(Tag::ImageWidth).to_i
      @height = first_val(Tag::ImageLength).to_i

      unless @features.has_key?(Tag::BitsPerSample)
        @features[Tag::BitsPerSample] = [1_u32]
      end

      @bpp = first_val(Tag::BitsPerSample)

      case @bpp
      when 0
        raise FormatError.new("Invalid TIFF: BitsPerSample must not be 0")
      when 1, 8, 16
        # Accepted
      else
        raise UnsupportedError.new("Unsupported TIFF BitsPerSample: #{@bpp} (supported: 1, 8, 16)")
      end
    end

    private def parse_ifd_entry(entry : Bytes, tag : Tag)
      case tag
      when .bits_per_sample?, .extra_samples?, .photometric_interpretation?,
           .compression?, .predictor?, .strip_offsets?, .strip_byte_counts?,
           .rows_per_strip?, .tile_width?, .tile_length?, .tile_offsets?,
           .tile_byte_counts?, .image_length?, .image_width?, .fill_order?,
           .t4_options?, .t6_options?
        val = ifd_uint(entry)
        @features[tag] = val
      when .color_map?
        val = ifd_uint(entry)
        num_colors = val.size // 3
        raise FormatError.new("Invalid TIFF ColorMap: length #{val.size} (must be multiple of 3, with 1-256 colors)") if val.size % 3 != 0 || num_colors <= 0 || num_colors > 256

        colors = Array(Color::Color).new(num_colors)
        num_colors.times do |i|
          colors << Color::RGBA64.new(
            val[i].to_u16,
            val[i + num_colors].to_u16,
            val[i + 2 * num_colors].to_u16,
            0xffff_u16
          )
        end
        @palette = Color::Palette.new(colors)
      when .sample_format?
        val = ifd_uint(entry)
        val.each do |v|
          raise UnsupportedError.new("Unsupported TIFF sample format: #{v} (only unsigned integer format 1 is supported)") if v != 1
        end
      end
    end

    private def ifd_uint(entry : Bytes) : Array(UInt32)
      datatype = @byte_order.decode(UInt16, entry[2, 2]).to_i
      raise UnsupportedError.new("Invalid TIFF IFD entry datatype: #{datatype} (valid range: 1-#{DATA_TYPE_LENGTHS.size - 1})") if datatype <= 0 || datatype >= DATA_TYPE_LENGTHS.size

      count = @byte_order.decode(UInt32, entry[4, 4])
      raise FormatError.new("TIFF IFD data too large: count=#{count}, max=#{Int32::MAX // DATA_TYPE_LENGTHS[datatype]}") if count > Int32::MAX // DATA_TYPE_LENGTHS[datatype]

      datalen = DATA_TYPE_LENGTHS[datatype] * count
      raw : Bytes

      if datalen > 4
        offset = @byte_order.decode(UInt32, entry[8, 4])
        raw = safe_read_at(datalen.to_u64, offset.to_i64)
      else
        raw = entry[8, datalen]
      end

      result = Array(UInt32).new(count.to_i)
      case datatype
      when 1 # Byte
        count.times { |i| result << raw[i].to_u32 }
      when 3 # Short
        count.times { |i| result << @byte_order.decode(UInt16, raw[i * 2, 2]).to_u32 }
      when 4 # Long
        count.times { |i| result << @byte_order.decode(UInt32, raw[i * 4, 4]) }
      else
        raise UnsupportedError.new("Unsupported TIFF data type: #{datatype}")
      end

      result
    end

    private def safe_read_at(n : UInt64, off : Int64) : Bytes
      raise IO::EOFError.new if n.to_i64 < 0 || n != n.to_i.to_u64

      if n < MAX_CHUNK_SIZE
        buf = Bytes.new(n.to_i)
        @io.seek(off)
        @io.read_fully(buf)
        return buf
      end

      result = Bytes.new(0)
      buf_chunk = Bytes.new(MAX_CHUNK_SIZE)
      remaining = n
      current_off = off

      while remaining > 0
        chunk_size = [remaining, MAX_CHUNK_SIZE.to_u64].min.to_i
        @io.seek(current_off)
        @io.read_fully(buf_chunk[0, chunk_size])
        result += buf_chunk[0, chunk_size]
        remaining -= chunk_size
        current_off += chunk_size
      end

      result
    end

    private def first_val(tag : Tag) : UInt32
      f = @features[tag]?
      return 0_u32 if f.nil? || f.empty?
      f[0]
    end

    private def setup_config
      case first_val(Tag::PhotometricInterpretation)
      when 2 # RGB
        setup_rgb_mode
      when 3 # Paletted
        @mode = ImageMode::Paletted
        @config = CrImage::Config.new(@palette, @width, @height)
      when 0 # WhiteIsZero
        @mode = ImageMode::GrayInvert
        @config = CrImage::Config.new(@bpp == 16 ? Color.gray16_model : Color.gray_model, @width, @height)
      when 1 # BlackIsZero
        @mode = ImageMode::Gray
        @config = CrImage::Config.new(@bpp == 16 ? Color.gray16_model : Color.gray_model, @width, @height)
      else
        raise UnsupportedError.new("Unsupported TIFF color model: PhotometricInterpretation=#{first_val(Tag::PhotometricInterpretation)}")
      end

      if first_val(Tag::PhotometricInterpretation) != 2
        bits_per_sample = @features[Tag::BitsPerSample]?
        raise UnsupportedError.new("TIFF extra samples not supported for non-RGB images (BitsPerSample count: #{bits_per_sample.size})") if bits_per_sample && bits_per_sample.size != 1
      end
    end

    private def setup_rgb_mode
      bits_per_sample = @features[Tag::BitsPerSample]?
      return unless bits_per_sample

      if @bpp == 16
        bits_per_sample.each do |b|
          raise FormatError.new("Invalid TIFF 16-bit RGB: expected 16 bits per sample, got #{b}") if b != 16
        end
      else
        bits_per_sample.each do |b|
          raise FormatError.new("Invalid TIFF 8-bit RGB: expected 8 bits per sample, got #{b}") if b != 8
        end
      end

      case bits_per_sample.size
      when 3
        @mode = ImageMode::RGB
        @config = CrImage::Config.new(@bpp == 16 ? Color.rgba64_model : Color.rgba_model, @width, @height)
      when 4
        extra = first_val(Tag::ExtraSamples)
        case extra
        when 1
          @mode = ImageMode::RGBA
          @config = CrImage::Config.new(@bpp == 16 ? Color.rgba64_model : Color.rgba_model, @width, @height)
        when 2
          @mode = ImageMode::NRGBA
          @config = CrImage::Config.new(@bpp == 16 ? Color.nrgba64_model : Color.nrgba_model, @width, @height)
        else
          raise FormatError.new("Invalid TIFF RGB format: unsupported ExtraSamples value #{extra} (expected 1 or 2)")
        end
      else
        raise FormatError.new("Invalid TIFF RGB format: expected 3 or 4 samples, got #{bits_per_sample.size}")
      end
    end

    protected def decode : CrImage::Image
      block_padding = false
      block_width = @width
      block_height = @height
      blocks_across = 1
      blocks_down = 1

      blocks_across = 0 if @width == 0
      blocks_down = 0 if @height == 0

      block_offsets = [] of UInt32
      block_counts = [] of UInt32

      if first_val(Tag::TileWidth) != 0
        block_padding = true
        block_width = first_val(Tag::TileWidth).to_i
        block_height = first_val(Tag::TileLength).to_i

        raise FormatError.new("TIFF tile size too small: #{block_width}x#{block_height} (minimum 8x8)") if block_width < 8 || block_height < 8

        blocks_across = (@width + block_width - 1) // block_width if block_width != 0
        blocks_down = (@height + block_height - 1) // block_height if block_height != 0

        block_counts = @features[Tag::TileByteCounts]? || [] of UInt32
        block_offsets = @features[Tag::TileOffsets]? || [] of UInt32
      else
        if first_val(Tag::RowsPerStrip) != 0
          block_height = first_val(Tag::RowsPerStrip).to_i
        end

        blocks_down = (@height + block_height - 1) // block_height if block_height != 0

        block_offsets = @features[Tag::StripOffsets]? || [] of UInt32
        block_counts = @features[Tag::StripByteCounts]? || [] of UInt32
      end

      n = blocks_across * blocks_down
      raise FormatError.new("Inconsistent TIFF header: expected #{n} blocks, got #{block_offsets.size} offsets and #{block_counts.size} counts") if block_offsets.size < n || block_counts.size < n

      img = create_image

      return img if blocks_across == 0 || blocks_down == 0

      blocks_across.times do |i|
        blk_w = block_width
        if !block_padding && i == blocks_across - 1 && @width % block_width != 0
          blk_w = @width % block_width
        end

        blocks_down.times do |j|
          blk_h = block_height
          if !block_padding && j == blocks_down - 1 && @height % block_height != 0
            blk_h = @height % block_height
          end

          offset = block_offsets[j * blocks_across + i].to_i64
          n = block_counts[j * blocks_across + i].to_i64

          @buf = read_block(offset, n, blk_w, blk_h)

          xmin = i * block_width
          ymin = j * block_height
          xmax = xmin + blk_w
          ymax = ymin + blk_h

          decode_block(img, xmin, ymin, xmax, ymax)
        end
      end

      img
    end

    private def create_image : CrImage::Image
      img_rect = CrImage.rect(0, 0, @width, @height)

      case @mode
      when .gray?, .gray_invert?
        @bpp == 16 ? CrImage::Gray16.new(img_rect) : CrImage::Gray.new(img_rect)
      when .paletted?
        CrImage::Paletted.new(img_rect, @palette)
      when .nrgba?
        @bpp == 16 ? CrImage::NRGBA64.new(img_rect) : CrImage::NRGBA.new(img_rect)
      when .rgb?, .rgba?
        @bpp == 16 ? CrImage::RGBA64.new(img_rect) : CrImage::RGBA.new(img_rect)
      else
        raise UnsupportedError.new("Unsupported TIFF image mode: #{@mode}")
      end
    end

    private def read_block(offset : Int64, n : Int64, blk_w : Int32, blk_h : Int32) : Bytes
      compression = first_val(Tag::Compression)

      case compression
      when 0, 1 # None
        safe_read_at(n.to_u64, offset)
      when 5 # LZW
        compressed_data = safe_read_at(n.to_u64, offset)
        # TIFF LZW uses 8-bit literal width, MSB-first bit ordering, and early code width change
        TIFF::LZW.decompress(compressed_data, 8)
      when 8, 32946 # Deflate
        @io.seek(offset)
        limited_io = IO::Sized.new(@io, n)
        reader = Compress::Zlib::Reader.new(limited_io)
        result = IO::Memory.new
        IO.copy(reader, result)
        reader.close
        result.to_slice
      else
        raise UnsupportedError.new("compression value #{compression}")
      end
    end

    private def decode_block(img : CrImage::Image, xmin : Int32, ymin : Int32, xmax : Int32, ymax : Int32)
      @off = 0

      apply_predictor(xmin, ymin, xmax, ymax) if first_val(Tag::Predictor) == 2

      r_max_x = [xmax, img.bounds.max.x].min
      r_max_y = [ymax, img.bounds.max.y].min

      case @mode
      when .gray?, .gray_invert?
        decode_gray(img, xmin, ymin, r_max_x, r_max_y, xmax)
      when .paletted?
        decode_paletted(img, xmin, ymin, r_max_x, r_max_y)
      when .rgb?
        decode_rgb(img, xmin, ymin, r_max_x, r_max_y, xmax)
      when .nrgba?
        decode_nrgba(img, xmin, ymin, r_max_x, r_max_y, xmax)
      when .rgba?
        decode_rgba(img, xmin, ymin, r_max_x, r_max_y, xmax)
      end
    end

    private def apply_predictor(xmin : Int32, ymin : Int32, xmax : Int32, ymax : Int32)
      bits_per_sample = @features[Tag::BitsPerSample]?
      return unless bits_per_sample

      case @bpp
      when 16
        off = 0
        n = 2 * bits_per_sample.size
        (ymin...ymax).each do |y|
          off += n
          ((xmax - xmin - 1) * n).times do |x|
            return if off + 2 > @buf.size
            v0 = @byte_order.decode(UInt16, @buf[off - n, 2])
            v1 = @byte_order.decode(UInt16, @buf[off, 2])
            @byte_order.encode(v1 &+ v0, @buf[off, 2])
            off += 2
          end
        end
      when 8
        off = 0
        n = bits_per_sample.size
        (ymin...ymax).each do |y|
          off += n
          ((xmax - xmin - 1) * n).times do |x|
            return if off >= @buf.size
            @buf[off] = @buf[off] &+ @buf[off - n]
            off += 1
          end
        end
      end
    end

    private def read_bits(n : UInt32) : {UInt32, Bool}
      while @nbits < n
        return {0_u32, false} if @off >= @buf.size
        @v = (@v << 8) | @buf[@off].to_u32
        @off += 1
        @nbits += 8
      end

      @nbits -= n
      rv = @v >> @nbits
      @v &= ~(rv << @nbits)
      {rv, true}
    end

    private def flush_bits
      @v = 0_u32
      @nbits = 0_u32
    end

    private def decode_gray(img : CrImage::Image, xmin : Int32, ymin : Int32, r_max_x : Int32, r_max_y : Int32, xmax : Int32)
      if @bpp == 16
        gray16 = img.as(CrImage::Gray16)
        (ymin...r_max_y).each do |y|
          (xmin...r_max_x).each do |x|
            return if @off + 2 > @buf.size
            v = @byte_order.decode(UInt16, @buf[@off, 2])
            @off += 2
            v = 0xffff_u16 - v if @mode.gray_invert?
            gray16.set_gray16(x, y, Color::Gray16.new(v))
          end
          @off += 2 * (xmax - gray16.bounds.max.x) if r_max_x == gray16.bounds.max.x
        end
      else
        gray = img.as(CrImage::Gray)
        max = (1_u32 << @bpp) - 1
        (ymin...r_max_y).each do |y|
          (xmin...r_max_x).each do |x|
            v, ok = read_bits(@bpp)
            return unless ok
            v = v * 0xff // max
            v = 0xff - v if @mode.gray_invert?
            gray.set_gray(x, y, Color::Gray.new(v.to_u8))
          end
          flush_bits
        end
      end
    end

    private def decode_paletted(img : CrImage::Image, xmin : Int32, ymin : Int32, r_max_x : Int32, r_max_y : Int32)
      paletted = img.as(CrImage::Paletted)
      p_len = @palette.size

      (ymin...r_max_y).each do |y|
        (xmin...r_max_x).each do |x|
          v, ok = read_bits(@bpp)
          return unless ok
          idx = v.to_u8
          raise FormatError.new("invalid color index") if idx.to_i >= p_len
          paletted.set_color_index(x, y, idx)
        end
        flush_bits
      end
    end

    private def decode_rgb(img : CrImage::Image, xmin : Int32, ymin : Int32, r_max_x : Int32, r_max_y : Int32, xmax : Int32)
      if @bpp == 16
        rgba64 = img.as(CrImage::RGBA64)
        (ymin...r_max_y).each do |y|
          (xmin...r_max_x).each do |x|
            return if @off + 6 > @buf.size
            r = @byte_order.decode(UInt16, @buf[@off, 2])
            g = @byte_order.decode(UInt16, @buf[@off + 2, 2])
            b = @byte_order.decode(UInt16, @buf[@off + 4, 2])
            @off += 6
            rgba64.set_rgba64(x, y, Color::RGBA64.new(r, g, b, 0xffff_u16))
          end
        end
      else
        rgba = img.as(CrImage::RGBA)
        (ymin...r_max_y).each do |y|
          min = rgba.pixel_offset(xmin, y)
          max = rgba.pixel_offset(r_max_x, y)
          off = (y - ymin) * (xmax - xmin) * 3
          i = min
          while i < max
            return if off + 3 > @buf.size
            rgba.pix[i] = @buf[off]
            rgba.pix[i + 1] = @buf[off + 1]
            rgba.pix[i + 2] = @buf[off + 2]
            rgba.pix[i + 3] = 0xff_u8
            off += 3
            i += 4
          end
        end
      end
    end

    private def decode_nrgba(img : CrImage::Image, xmin : Int32, ymin : Int32, r_max_x : Int32, r_max_y : Int32, xmax : Int32)
      if @bpp == 16
        nrgba64 = img.as(CrImage::NRGBA64)
        (ymin...r_max_y).each do |y|
          (xmin...r_max_x).each do |x|
            return if @off + 8 > @buf.size
            r = @byte_order.decode(UInt16, @buf[@off, 2])
            g = @byte_order.decode(UInt16, @buf[@off + 2, 2])
            b = @byte_order.decode(UInt16, @buf[@off + 4, 2])
            a = @byte_order.decode(UInt16, @buf[@off + 6, 2])
            @off += 8
            nrgba64.set_nrgba64(x, y, Color::NRGBA64.new(r, g, b, a))
          end
        end
      else
        nrgba = img.as(CrImage::NRGBA)
        (ymin...r_max_y).each do |y|
          min = nrgba.pixel_offset(xmin, y)
          max = nrgba.pixel_offset(r_max_x, y)
          i0 = (y - ymin) * (xmax - xmin) * 4
          i1 = (y - ymin + 1) * (xmax - xmin) * 4
          return if i1 > @buf.size
          nrgba.pix[min...max].copy_from(@buf[i0...i1].to_unsafe, max - min)
        end
      end
    end

    private def decode_rgba(img : CrImage::Image, xmin : Int32, ymin : Int32, r_max_x : Int32, r_max_y : Int32, xmax : Int32)
      if @bpp == 16
        rgba64 = img.as(CrImage::RGBA64)
        (ymin...r_max_y).each do |y|
          (xmin...r_max_x).each do |x|
            return if @off + 8 > @buf.size
            r = @byte_order.decode(UInt16, @buf[@off, 2])
            g = @byte_order.decode(UInt16, @buf[@off + 2, 2])
            b = @byte_order.decode(UInt16, @buf[@off + 4, 2])
            a = @byte_order.decode(UInt16, @buf[@off + 6, 2])
            @off += 8
            rgba64.set_rgba64(x, y, Color::RGBA64.new(r, g, b, a))
          end
        end
      else
        rgba = img.as(CrImage::RGBA)
        (ymin...r_max_y).each do |y|
          min = rgba.pixel_offset(xmin, y)
          max = rgba.pixel_offset(r_max_x, y)
          i0 = (y - ymin) * (xmax - xmin) * 4
          i1 = (y - ymin + 1) * (xmax - xmin) * 4
          return if i1 > @buf.size
          rgba.pix[min...max].copy_from(@buf[i0...i1].to_unsafe, max - min)
        end
      end
    end
  end
end
