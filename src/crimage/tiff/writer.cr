require "compress/zlib"
require "./tiff"
require "./lzw"

module CrImage::TIFF
  class Writer
    private record IFDEntry, tag : Tag, datatype : DataType, data : Array(UInt32)

    @io : IO
    @image : CrImage::Image
    @compression : CompressionType

    private def initialize(@io : IO, @image : CrImage::Image, @compression : CompressionType)
    end

    private def encode_u16_le(buf : Bytes, offset : Int32, value : UInt16)
      buf[offset] = (value & 0xff).to_u8
      buf[offset + 1] = (value >> 8).to_u8
    end

    private def encode_u32_le(buf : Bytes, offset : Int32, value : UInt32)
      buf[offset] = (value & 0xff).to_u8
      buf[offset + 1] = ((value >> 8) & 0xff).to_u8
      buf[offset + 2] = ((value >> 16) & 0xff).to_u8
      buf[offset + 3] = (value >> 24).to_u8
    end

    def self.write(path : String, image : CrImage::Image, compression = CompressionType::Uncompressed) : Nil
      File.open(path, "wb") do |file|
        write(file, image, compression)
      end
    end

    def self.write(io : IO, image : CrImage::Image, compression = CompressionType::Uncompressed) : Nil
      new(io, image, compression).encode
    end

    protected def encode
      d = @image.bounds.size

      # Write little-endian header
      @io.write(LE_HEADER)

      # Prepare image data
      buf = IO::Memory.new
      image_len = encode_image(buf, d)

      # Write IFD offset (after header + image data)
      ifd_offset = 8 + image_len
      @io.write_bytes(ifd_offset.to_u32, IO::ByteFormat::LittleEndian)

      # Write image data
      buf.rewind
      IO.copy(buf, @io)

      # Write IFD
      write_ifd(ifd_offset, d)
    end

    private def encode_image(buf : IO, d : CrImage::Point) : Int32
      # For LZW compression, we need to compress the entire image data at once
      if @compression.lzw?
        temp_buf = IO::Memory.new
        encode_image_data(temp_buf, d)
        temp_buf.rewind
        uncompressed = temp_buf.to_slice
        # TIFF uses MSB-first bit ordering and early code width change
        compressed = TIFF::LZW.compress(uncompressed, 8)
        buf.write(compressed)
        return compressed.size
      end

      dst : IO = buf

      if @compression.deflate?
        dst = Compress::Zlib::Writer.new(buf)
      end

      encode_image_data(dst, d)

      if @compression.deflate?
        dst.as(Compress::Zlib::Writer).close
      end

      buf.pos.to_i
    end

    private def encode_image_data(dst : IO, d : CrImage::Point)
      case @image
      when CrImage::Paletted
        encode_paletted(dst, @image.as(CrImage::Paletted), d)
      when CrImage::Gray
        encode_gray(dst, @image.as(CrImage::Gray), d)
      when CrImage::Gray16
        encode_gray16(dst, @image.as(CrImage::Gray16), d)
      when CrImage::NRGBA
        encode_nrgba(dst, @image.as(CrImage::NRGBA), d)
      when CrImage::NRGBA64
        encode_nrgba64(dst, @image.as(CrImage::NRGBA64), d)
      when CrImage::RGBA
        encode_rgba(dst, @image.as(CrImage::RGBA), d)
      when CrImage::RGBA64
        encode_rgba64(dst, @image.as(CrImage::RGBA64), d)
      else
        encode_generic(dst, @image, d)
      end
    end

    private def encode_gray(dst : IO, img : CrImage::Gray, d : CrImage::Point)
      (0...d.y).each do |y|
        offset = y * img.stride
        dst.write(img.pix[offset, d.x])
      end
    end

    private def encode_gray16(dst : IO, img : CrImage::Gray16, d : CrImage::Point)
      buf = Bytes.new(d.x * 2)
      (0...d.y).each do |y|
        offset = y * img.stride
        (0...d.x).each do |x|
          idx = offset + x * 2
          # Convert from big-endian to little-endian
          v = (img.pix[idx].to_u16 << 8) | img.pix[idx + 1].to_u16
          encode_u16_le(buf, x * 2, v)
        end
        dst.write(buf)
      end
    end

    private def encode_paletted(dst : IO, img : CrImage::Paletted, d : CrImage::Point)
      (0...d.y).each do |y|
        offset = y * img.stride
        dst.write(img.pix[offset, d.x])
      end
    end

    private def encode_rgba(dst : IO, img : CrImage::RGBA, d : CrImage::Point)
      (0...d.y).each do |y|
        offset = y * img.stride
        dst.write(img.pix[offset, d.x * 4])
      end
    end

    private def encode_rgba64(dst : IO, img : CrImage::RGBA64, d : CrImage::Point)
      buf = Bytes.new(d.x * 8)
      (0...d.y).each do |y|
        offset = y * img.stride
        (0...d.x).each do |x|
          idx = offset + x * 8
          # Convert from big-endian to little-endian
          r = (img.pix[idx].to_u16 << 8) | img.pix[idx + 1].to_u16
          g = (img.pix[idx + 2].to_u16 << 8) | img.pix[idx + 3].to_u16
          b = (img.pix[idx + 4].to_u16 << 8) | img.pix[idx + 5].to_u16
          a = (img.pix[idx + 6].to_u16 << 8) | img.pix[idx + 7].to_u16

          encode_u16_le(buf, x * 8, r)
          encode_u16_le(buf, x * 8 + 2, g)
          encode_u16_le(buf, x * 8 + 4, b)
          encode_u16_le(buf, x * 8 + 6, a)
        end
        dst.write(buf)
      end
    end

    private def encode_nrgba(dst : IO, img : CrImage::NRGBA, d : CrImage::Point)
      (0...d.y).each do |y|
        offset = y * img.stride
        dst.write(img.pix[offset, d.x * 4])
      end
    end

    private def encode_nrgba64(dst : IO, img : CrImage::NRGBA64, d : CrImage::Point)
      buf = Bytes.new(d.x * 8)
      (0...d.y).each do |y|
        offset = y * img.stride
        (0...d.x).each do |x|
          idx = offset + x * 8
          # Convert from big-endian to little-endian
          r = (img.pix[idx].to_u16 << 8) | img.pix[idx + 1].to_u16
          g = (img.pix[idx + 2].to_u16 << 8) | img.pix[idx + 3].to_u16
          b = (img.pix[idx + 4].to_u16 << 8) | img.pix[idx + 5].to_u16
          a = (img.pix[idx + 6].to_u16 << 8) | img.pix[idx + 7].to_u16

          encode_u16_le(buf, x * 8, r)
          encode_u16_le(buf, x * 8 + 2, g)
          encode_u16_le(buf, x * 8 + 4, b)
          encode_u16_le(buf, x * 8 + 6, a)
        end
        dst.write(buf)
      end
    end

    private def encode_generic(dst : IO, img : CrImage::Image, d : CrImage::Point)
      buf = Bytes.new(d.x * 4)
      bounds = img.bounds
      (bounds.min.y...bounds.max.y).each do |y|
        off = 0
        (bounds.min.x...bounds.max.x).each do |x|
          r, g, b, a = img.at(x, y).rgba
          buf[off] = (r >> 8).to_u8
          buf[off + 1] = (g >> 8).to_u8
          buf[off + 2] = (b >> 8).to_u8
          buf[off + 3] = (a >> 8).to_u8
          off += 4
        end
        dst.write(buf)
      end
    end

    private def write_ifd(offset : Int32, d : CrImage::Point)
      compression_value = case @compression
                          when .deflate?
                            Compression::Deflate.value.to_u32
                          when .lzw?
                            Compression::LZW.value.to_u32
                          else
                            Compression::None.value.to_u32
                          end

      photometric = Photometric::RGB.value.to_u32
      samples_per_pixel = 4_u32
      bits_per_sample = [8_u32, 8_u32, 8_u32, 8_u32]
      extra_samples = 0_u32
      color_map = [] of UInt32

      case @image
      when CrImage::Paletted
        paletted = @image.as(CrImage::Paletted)
        photometric = Photometric::Paletted.value.to_u32
        samples_per_pixel = 1_u32
        bits_per_sample = [8_u32]

        # Build color map - TIFF requires 256 entries for 8-bit paletted images
        # Color map is stored as three separate arrays: all reds, then all greens, then all blues
        num_colors = 256
        color_map = Array(UInt32).new(num_colors * 3, 0_u32)

        paletted.palette.each_with_index do |color, i|
          r, g, b, a = color.rgba
          # Store as 16-bit values in separate R, G, B arrays
          color_map[i] = r.to_u32
          color_map[i + num_colors] = g.to_u32
          color_map[i + num_colors * 2] = b.to_u32
        end
      when CrImage::Gray
        photometric = Photometric::BlackIsZero.value.to_u32
        samples_per_pixel = 1_u32
        bits_per_sample = [8_u32]
      when CrImage::Gray16
        photometric = Photometric::BlackIsZero.value.to_u32
        samples_per_pixel = 1_u32
        bits_per_sample = [16_u32]
      when CrImage::NRGBA
        extra_samples = 2_u32
      when CrImage::NRGBA64
        extra_samples = 2_u32
        bits_per_sample = [16_u32, 16_u32, 16_u32, 16_u32]
      when CrImage::RGBA
        extra_samples = 1_u32
      when CrImage::RGBA64
        extra_samples = 1_u32
        bits_per_sample = [16_u32, 16_u32, 16_u32, 16_u32]
      else
        extra_samples = 1_u32
      end

      image_len = offset - 8

      ifd = [
        IFDEntry.new(Tag::ImageWidth, DataType::Short, [d.x.to_u32]),
        IFDEntry.new(Tag::ImageLength, DataType::Short, [d.y.to_u32]),
        IFDEntry.new(Tag::BitsPerSample, DataType::Short, bits_per_sample),
        IFDEntry.new(Tag::Compression, DataType::Short, [compression_value]),
        IFDEntry.new(Tag::PhotometricInterpretation, DataType::Short, [photometric]),
        IFDEntry.new(Tag::StripOffsets, DataType::Long, [8_u32]),
        IFDEntry.new(Tag::SamplesPerPixel, DataType::Short, [samples_per_pixel]),
        IFDEntry.new(Tag::RowsPerStrip, DataType::Short, [d.y.to_u32]),
        IFDEntry.new(Tag::StripByteCounts, DataType::Long, [image_len.to_u32]),
        IFDEntry.new(Tag::XResolution, DataType::Rational, [72_u32, 1_u32]),
        IFDEntry.new(Tag::YResolution, DataType::Rational, [72_u32, 1_u32]),
        IFDEntry.new(Tag::ResolutionUnit, DataType::Short, [ResolutionUnit::PerInch.value.to_u32]),
      ]

      ifd << IFDEntry.new(Tag::ColorMap, DataType::Short, color_map) unless color_map.empty?
      ifd << IFDEntry.new(Tag::ExtraSamples, DataType::Short, [extra_samples]) if extra_samples > 0

      ifd.sort_by! { |e| e.tag.value }

      # Write number of entries
      @io.write_bytes(ifd.size.to_u16, IO::ByteFormat::LittleEndian)

      # Pointer area for data > 4 bytes
      parea = IO::Memory.new
      pstart = offset + IFD_LEN * ifd.size + 6

      ifd.each do |entry|
        buf = Bytes.new(IFD_LEN)

        encode_u16_le(buf, 0, entry.tag.value.to_u16)
        encode_u16_le(buf, 2, entry.datatype.value.to_u16)

        count = entry.data.size.to_u32
        count //= 2 if entry.datatype.rational?
        encode_u32_le(buf, 4, count)

        datalen = count * DATA_TYPE_LENGTHS[entry.datatype.value]

        if datalen <= 4
          put_data(buf[8, 4], entry)
        else
          put_data_to_io(parea, entry)
          encode_u32_le(buf, 8, (pstart + parea.pos - datalen).to_u32)
        end

        @io.write(buf)
      end

      # Write offset to next IFD (0 = no more IFDs)
      @io.write_bytes(0_u32, IO::ByteFormat::LittleEndian)

      # Write pointer area
      parea.rewind
      IO.copy(parea, @io)
    end

    private def put_data(buf : Bytes, entry : IFDEntry)
      off = 0
      entry.data.each do |d|
        case entry.datatype
        when .byte?, .ascii?
          buf[off] = d.to_u8
          off += 1
        when .short?
          encode_u16_le(buf, off, d.to_u16)
          off += 2
        when .long?, .rational?
          encode_u32_le(buf, off, d)
          off += 4
        end
      end
    end

    private def put_data_to_io(io : IO, entry : IFDEntry)
      entry.data.each do |d|
        case entry.datatype
        when .byte?, .ascii?
          io.write_byte(d.to_u8)
        when .short?
          io.write_bytes(d.to_u16, IO::ByteFormat::LittleEndian)
        when .long?, .rational?
          io.write_bytes(d, IO::ByteFormat::LittleEndian)
        end
      end
    end
  end
end
