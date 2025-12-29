require "compress/zlib"
require "./png"
require "./paeth"

module CrImage::PNG
  # Implements PNG Write functionality.
  # Sample
  #
  # ```
  # img = CrImage::NRGBA.new(CrImage.rect(0, 0, 256, 256))
  # 0.upto(255) do |y|
  #   0.upto(255) do |x|
  #     img[x, y] = Color::NRGBA.new(
  #       (x + y) & 255,
  #       (x + y) << 1 & 255,
  #       (x + y) << 2 & 255,
  #       255
  #     )
  #   end
  # end
  # PNG::Writer.write("test.png", img)
  # ```
  class Writer
    private getter cb : ColorBit

    private def initialize(@io : IO, @image : CrImage::Image, @level = CompressionLevel::Default)
      @cb = ColorBit::Invalid
    end

    # write the Image to file in PNG format
    def self.write(path : String, image : CrImage::Image, level = CompressionLevel::Default) : Nil
      File.open(path, "wb") do |file|
        write(file, image, level)
      end
    end

    # write the Image to IO in PNG format
    def self.write(io : IO, image : CrImage::Image, level = CompressionLevel::Default) : Nil
      self.validate(image)

      png = new(io, image, level)
      png.encode
    end

    protected def encode
      # P8 encoding needs PalettedImage's color_at_index method.
      pal : Color::Palette? = nil
      if (@image.is_a?(CrImage::PalettedImage)) && (pal = @image.color_model.as?(Color::Palette))
        case pal.size
        when .<= 2  then @cb = ColorBit::P1
        when .<= 4  then @cb = ColorBit::P2
        when .<= 16 then @cb = ColorBit::P4
        else
          @cb = ColorBit::P8
        end
      else
        case @image.color_model.name
        when "GRAY"   then @cb = ColorBit::G8
        when "GRAY16" then @cb = ColorBit::G16
        when "RGBA", "NRGBA", "ALPHA"
          @cb = opaque? ? ColorBit::TC8 : ColorBit::TCA8
        else
          @cb = opaque? ? ColorBit::TC16 : ColorBit::TCA16
        end
      end
      @io.write(PNG_HEADER)
      write_ihdr
      write_plte_trns(pal) unless pal.nil?
      write_idat
      write_end
    end

    private def self.validate(image : CrImage::Image)
      # Obviously, negative widths and heights are invalid. Furthermore, the PNG
      # spec section 11.2.2 says that zero is invalid. Excessively large images are
      # also rejected.
      mw, mh = image.bounds.width.to_i64, image.bounds.height.to_i64
      max_size = 1_i64 << 32
      if mw <= 0 || mh <= 0 || mw >= max_size || mh >= max_size
        FormatError.new("Invalid Image size: #{mw} x #{mh}")
      end
    end

    private def write_chunk(buf, name)
      n = buf.size.to_u32
      FormatError.new("#{name} chunk is too large") unless n.to_i == buf.size
      header = Bytes.new(8)

      IO::ByteFormat::BigEndian.encode(n, header[0..4])
      header[4..].copy_from(name.to_unsafe, name.size)
      crc = CRC.new
      crc.write(header[4..])
      crc.write(buf)

      @io.write header
      @io.write buf
      @io.write_bytes(crc.sum32, IO::ByteFormat::BigEndian)
    end

    private def write_ihdr
      b = @image.bounds
      buf = Bytes.new(13)

      # write width and height
      # io.write_bytes(b.width.to_u32, IO::ByteFormat::BigEndian)
      # io.write_bytes(b.height.to_u32, IO::ByteFormat::BigEndian)
      IO::ByteFormat::BigEndian.encode(b.width.to_u32, buf[0..4])
      IO::ByteFormat::BigEndian.encode(b.height.to_u32, buf[4..8])

      # Set bit depth and color type
      case cb
      when .g8?
        buf[8] = 8_u8
        buf[9] = ColorType::Grayscale.value.to_u8
      when .tc8?
        buf[8] = 8_u8
        buf[9] = ColorType::TrueColor.value.to_u8
      when .p8?
        buf[8] = 8_u8
        buf[9] = ColorType::Paletted.value.to_u8
      when .p4?
        buf[8] = 4_u8
        buf[9] = ColorType::Paletted.value.to_u8
      when .p2?
        buf[8] = 2_u8
        buf[9] = ColorType::Paletted.value.to_u8
      when .p1?
        buf[8] = 1_u8
        buf[9] = ColorType::Paletted.value.to_u8
      when .tca8?
        buf[8] = 8_u8
        buf[9] = ColorType::TrueColorAlpha.value.to_u8
      when .g16?
        buf[8] = 16_u8
        buf[9] = ColorType::Grayscale.value.to_u8
      when .tc16?
        buf[8] = 16_u8
        buf[9] = ColorType::TrueColor.value.to_u8
      when .tca16?
        buf[8] = 16_u8
        buf[9] = ColorType::TrueColorAlpha.value.to_u8
      else
        #
      end

      buf[10] = 0_u8 # default compression method
      buf[11] = 0_u8 # default filter method
      buf[12] = 0_u8 # non-interlaced

      write_chunk(buf, "IHDR")
    end

    private def write_plte_trns(pal : Color::Palette)
      raise FormatError.new("bad palette length: #{pal.size}") if pal.size < 1 || pal.size > 256
      last = -1
      tmp = Bytes.new(4 * 256)
      pal.each_with_index do |color, idx|
        c1 = Color.nrgba_model.convert(color).as(Color::NRGBA)
        tmp[3*idx + 0] = c1.r
        tmp[3*idx + 1] = c1.g
        tmp[3*idx + 2] = c1.b
        last = idx unless c1.a == 0xff
        tmp[3*256 + idx] = c1.a
      end
      write_chunk(tmp[...3*pal.size], "PLTE")
      write_chunk(tmp[3*256...3*256 + 1 + last], "tRNS")
    end

    private def write_idat
      buf = IO::Memory.new
      Compress::Zlib::Writer.open(buf, level: level_to_zlib) do |zlib_writer|
        bits_per_pixel = case cb
                         when .g8?    then 8
                         when .tc8?   then 24
                         when .p8?    then 8
                         when .p4?    then 4
                         when .p2?    then 2
                         when .p1?    then 1
                         when .tca8?  then 32
                         when .tc16?  then 48
                         when .tca16? then 64
                         when .g16?   then 16
                         else
                           0
                         end
        # cr[*] and pr are the bytes for the current and previous row.
        # cr[0] is unfiltered (or equivalently, filtered with the None filter).
        # cr[ft], for non-zero filter types ft, are buffers for transforming cr[0] under the
        # other PNG filter types. These buffers are allocated once and re-used for each row.
        # The +1 is for the per-row filter type, which is at cr[*][0].
        b : CrImage::Rectangle = @image.bounds
        sz = 1 + ((bits_per_pixel*b.width + 7)/8).to_i
        cr = [] of Bytes
        0.upto(4) do |i|
          bytes = Bytes.new(sz)
          bytes[0] = i.to_u8
          cr << bytes
        end

        pr = Bytes.new(sz)

        b.min.y.upto(b.max.y - 1) do |y|
          # Convert from colors to bytes.
          i = 1
          case cb
          when .g8?
            if gray = @image.as?(CrImage::Gray)
              offset = (y - b.min.y) * gray.stride
              gray.pix[offset...offset + b.width].copy_to(cr[0][1..])
            else
              b.min.x.upto(b.max.x - 1) do |x|
                c = Color.gray_model.convert(@image.at(x, y)).as(Color::Gray)
                cr[0][i] = c.y
                i += 1
              end
            end
          when .tc8?
            # We have previously verified that the alpha value is fully opaque.
            cr0 = cr[0]
            stride, pix = 0, Bytes.empty
            if rgba = @image.as?(CrImage::RGBA)
              stride, pix = rgba.stride, rgba.pix
            elsif nrgba = @image.as?(CrImage::NRGBA)
              stride, pix = nrgba.stride, nrgba.pix
            end
            if stride != 0
              j0 = (y - b.min.y) * stride
              j1 = j0 + b.width*4

              j0.step(to: j1 - 1, by: 4) do |j|
                cr0[i + 0] = pix[j + 0]
                cr0[i + 1] = pix[j + 1]
                cr0[i + 2] = pix[j + 2]
                i += 3
              end
            else
              b.min.x.upto(b.max.x - 1) do |x|
                r, g, blue, _ = @image.at(x, y).rgba
                cr0[i + 0] = (r >> 8).to_u8
                cr0[i + 1] = (g >> 8).to_u8
                cr0[i + 2] = (blue >> 8).to_u8
                i += 3
              end
            end
          when .p8?
            if paletted = @image.as?(CrImage::Paletted)
              offset = (y - b.min.y) * paletted.stride
              paletted.pix[offset...offset + b.width].copy_to(cr[0][1..])
            else
              pi = @image.as(CrImage::PalettedImage)
              b.min.x.upto(b.max.x - 1) do |x|
                cr[0][i] = pi.color_index_at(x, y)
                i += 1
              end
            end
          when .p4?, .p2?, .p1?
            pi = @image.as(CrImage::PalettedImage)
            pixels_per_byte = (8 / bits_per_pixel).to_i
            a = 0_u8
            c = 0
            b.min.x.upto(b.max.x - 1) do |x|
              a = a << bits_per_pixel.to_u8 | pi.color_index_at(x, y)
              c += 1
              if c == pixels_per_byte
                cr[0][i] = a
                i += 1
                a = 0_u8
                c = 0
              end
            end
            unless c == 0
              while c != pixels_per_byte
                a = a << bits_per_pixel.to_u8
                c += 1
              end
              cr[0][i] = a
            end
          when .tca8?
            if nrgba = @image.as?(CrImage::NRGBA)
              offset = (y - b.min.y) * nrgba.stride
              nrgba.pix[offset...offset + b.width*4].copy_to(cr[0][1..])
            else
              # Convert from CrImage::Image (which is alpha-premultiplied) to PNG's non-alpha-premultiplied.
              b.min.x.upto(b.max.x - 1) do |x|
                c = Color.nrgba_model.convert(@image.at(x, y)).as(Color::NRGBA)
                cr[0][i + 0] = c.r
                cr[0][i + 1] = c.g
                cr[0][i + 2] = c.b
                cr[0][i + 3] = c.a
                i += 4
              end
            end
          when .g16?
            b.min.x.upto(b.max.x - 1) do |x|
              c = Color.gray16_model.convert(@image.at(x, y)).as(Color::Gray16)
              cr[0][i + 0] = (c.y >> 8).to_u8
              cr[0][i + 1] = (c.y & 0xFF).to_u8
              i += 2
            end
          when .tc16?
            # We have previously verified that the alpha value is fully opaque
            b.min.x.upto(b.max.x - 1) do |x|
              r, g, blue, _ = @image.at(x, y).rgba
              cr[0][i + 0] = (r >> 8).to_u8
              cr[0][i + 1] = (r & 0xFF).to_u8
              cr[0][i + 2] = (g >> 8).to_u8
              cr[0][i + 3] = (g & 0xFF).to_u8
              cr[0][i + 4] = (blue >> 8).to_u8
              cr[0][i + 5] = (blue & 0xFF).to_u8
              i += 6
            end
          when .tca16?
            # Convert from CrImage::Image (which is alpha-premultiplied) to PNG's non-alpha-premultiplied
            b.min.x.upto(b.max.x - 1) do |x|
              c = Color.nrgba64_model.convert(@image.at(x, y)).as(Color::NRGBA64)
              cr[0][i + 0] = (c.r >> 8).to_u8
              cr[0][i + 1] = (c.r & 0xFF).to_u8
              cr[0][i + 2] = (c.g >> 8).to_u8
              cr[0][i + 3] = (c.g & 0xFF).to_u8
              cr[0][i + 4] = (c.b >> 8).to_u8
              cr[0][i + 5] = (c.b & 0xFF).to_u8
              cr[0][i + 6] = (c.a >> 8).to_u8
              cr[0][i + 7] = (c.a & 0xFF).to_u8
              i += 8
            end
          else
            #
          end

          # Apply the filter.
          # Skip filter for NoCompression and paletted images (P8) as
          # "filters are rarely useful on palette images" and will result
          # in larger files (see http://www.libpng.org/pub/png/book/chapter09.html).
          f = FilterType::None
          if @level != CompressionLevel::NoCompression && !(ColorBit::P1..ColorBit::P8).includes?(cb)
            # Since we skip paletted images we dont' have to worry about
            # bits_per_pixel not being a multiple of 8
            bpp = bits_per_pixel // 8
            f = filter(cr, pr, bpp)
          end

          # Write the compressed bytes
          zlib_writer.write(cr[f.value])

          # The current row for y is the previous row for y + 1
          pr, cr[0] = cr[0], pr
        end
      end
      buf.rewind
      write_chunk(buf.to_slice, "IDAT")
      buf.close
    end

    private def write_end
      write_chunk(Bytes.empty, "IEND")
    end

    # The absolute value of a byte interpreted as a singed Int8
    private def abs8(d : UInt8)
      return d.to_i if d < 128
      256 - d.to_i
    end

    # Chooses the filter to use for encoding the current row, and applies it.
    # The return value is the filter type and also of the row in cr that has had it applied.
    private def filter(cr, pr, bpp)
      # We try all five filter types, and pick the one that minimizes the sum of absolute differences.
      # This is the same heuristic that libpng uses, although the filters are attempted in order of
      # estimated most likely to be minimal (Up, Paeth, None, Sub, Average), rather than
      # in their enumeration order (None, Sub, Up, Average, Paeth).
      cdat0 = cr[0][1..]
      cdat1 = cr[1][1..]
      cdat2 = cr[2][1..]
      cdat3 = cr[3][1..]
      cdat4 = cr[4][1..]
      pdat = pr[1..]
      n = cdat0.size

      # The Up filter
      sum = 0
      0.upto(n - 1) do |i|
        cdat2[i] = cdat0[i] &- pdat[i]
        sum += abs8 cdat2[i]
      end
      best = sum
      filter = FilterType::Up

      # THe Paeth filter.
      sum = 0
      0.upto(bpp - 1) do |i|
        cdat4[i] = cdat0[i] &- pdat[i]
        sum += abs8 cdat4[i]
      end
      bpp.upto(n - 1) do |i|
        cdat4[i] = cdat0[i] &- PNG.paeth(cdat0[i - bpp], pdat[i], pdat[i - bpp])
        sum += abs8 cdat4[i]
        break if sum >= best
      end
      if sum < best
        best = sum
        filter = FilterType::Paeth
      end

      # The None filter
      sum = 0
      0.upto(n - 1) do |i|
        sum += abs8 cdat0[i]
        break if sum >= best
      end
      if sum < best
        best = sum
        filter = FilterType::None
      end

      # The Sub filter
      0.upto(bpp - 1) do |i|
        cdat1[i] = cdat0[i]
        sum += abs8 cdat1[i]
      end
      bpp.upto(n - 1) do |i|
        cdat1[i] = cdat0[i] &- cdat0[i - bpp]
        sum += abs8 cdat1[i]
        break if sum >= best
      end
      if sum < best
        best = sum
        filter = FilterType::Sub
      end

      # The Average filter.
      sum = 0
      0.upto(bpp - 1) do |i|
        cdat3[i] = cdat0[i] &- (pdat[i]/2).to_u8
        sum += abs8 cdat3[i]
      end
      bpp.upto(n - 1) do |i|
        cdat3[i] = cdat0[i] &- ((cdat0[i - bpp].to_i + pdat[i].to_i) / 2).to_u8
        sum += abs8 cdat3[i]
        break if sum >= best
      end
      filter = FilterType::Average if sum < best

      filter
    end

    # whether or not the image is fully opaque
    private def opaque?
      if (o = @image).responds_to?(:opaque)
        return o.opaque
      end
      b = @image.bounds
      b.min.y.upto(b.max.y - 1) do |y|
        b.min.x.upto(b.max.x - 1) do |x|
          _, _, _, a = @image.at(x, y).rgba
          return false unless a == 0xffff
        end
      end
      true
    end

    private def level_to_zlib
      case @level
      when .no_compression?   then Compress::Zlib::NO_COMPRESSION
      when .default?          then Compress::Zlib::DEFAULT_COMPRESSION
      when .best_compression? then Compress::Zlib::BEST_COMPRESSION
      when .best_speed?       then Compress::Zlib::BEST_SPEED
      else
        Compress::Zlib::DEFAULT_COMPRESSION
      end
    end
  end
end

# png = PNG::Reader.read("testdata/benchGray.png")
# if (m = png.img)
#   PNG::Writer.write("test.png", m)
# else
#   puts "can't load image"
# end
# img = CrImage::NRGBA.new(CrImage.rect(0, 0, 256, 256))
# 0.upto(255) do |y|
#   0.upto(255) do |x|
#     img[x, y] = Color::NRGBA.new(
#       (x + y) & 255,
#       (x + y) << 1 & 255,
#       (x + y) << 2 & 255,
#       255
#     )
#   end
# end
# PNG::Writer.write("test.png", img)
