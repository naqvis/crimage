require "../image"

module CrImage::BMP
  # BMP Writer encodes images to Windows Bitmap format.
  #
  # Automatically selects optimal bit depth:
  # - 8-bit for Gray and Paletted images (with 256-color palette)
  # - 24-bit for opaque RGB images (no alpha channel)
  # - 32-bit for images with transparency (RGBA)
  #
  # Features:
  # - RGB to BGR byte order conversion
  # - Bottom-up row storage (standard BMP orientation)
  # - 4-byte row alignment padding
  # - Premultiplied to non-premultiplied alpha conversion for RGBA
  # - Palette generation for grayscale images
  class Writer
    private getter io : IO

    def initialize(@io : IO)
    end

    # Writes an image to a file in BMP format.
    #
    # Parameters:
    # - `path` : Output file path
    # - `image` : Image to encode
    #
    # Example:
    # ```
    # img = CrImage.rgba(400, 300)
    # CrImage::BMP::Writer.write("output.bmp", img)
    # ```
    def self.write(path : String, image : CrImage::Image) : Nil
      File.open(path, "wb") do |file|
        write(file, image)
      end
    end

    # Writes an image to an IO stream in BMP format.
    #
    # Parameters:
    # - `io` : Output IO stream
    # - `image` : Image to encode
    #
    # Example:
    # ```
    # File.open("output.bmp", "wb") do |file|
    #   CrImage::BMP::Writer.write(file, img)
    # end
    # ```
    def self.write(io : IO, image : CrImage::Image) : Nil
      bmp = new(io)
      bmp.encode(image)
    end

    protected def encode(image : CrImage::Image)
      d = image.bounds.size
      raise FormatError.new("negative bounds") if d.x < 0 || d.y < 0
      h = Header.new
      h.file_size = 14_u32 + 40_u32
      h.pix_offset = 14_u32 + 40_u32
      h.dib_header_size = 40_u32
      h.width = d.x.to_u32
      h.height = d.y.to_u32
      h.color_plane = 1_u16

      palette = Bytes.empty
      opaque = false
      case image
      when CrImage::Gray
        step = (d.x + 3) & ~3
        palette = Bytes.new(1024)
        0.upto(255) do |i|
          palette[i*4 + 0] = i.to_u8
          palette[i*4 + 1] = i.to_u8
          palette[i*4 + 2] = i.to_u8
          palette[i*4 + 3] = 0xFF_u8
        end
        h.image_size = (d.y * step).to_u32
        h.file_size += palette.size.to_u32 + h.image_size
        h.pix_offset += palette.size.to_u32
        h.bpp = 8_u16
      when CrImage::Paletted
        step = (d.x + 3) & ~3
        palette = Bytes.new(1024)
        i = 0
        pimage = image.as(CrImage::Paletted)
        while i < pimage.palette.size && i < 256
          r, g, b, _ = pimage.palette[i].rgba
          palette[i*4 + 0] = (b >> 8).to_u8
          palette[i*4 + 1] = (g >> 8).to_u8
          palette[i*4 + 2] = (r >> 8).to_u8
          palette[i*4 + 3] = 0xFF_u8
          i += 1
        end
        h.image_size = (d.y * step).to_u32
        h.file_size += palette.size.to_u32 + h.image_size
        h.pix_offset += palette.size.to_u32
        h.bpp = 8
      when CrImage::RGBA, CrImage::NRGBA
        opaque = image.opaque?
        if opaque
          step = (3*d.x + 3) & ~3
          h.bpp = 24_u16
        else
          step = 4 * d.x
          h.bpp = 32_u16
        end
        h.image_size = (d.y &* step).to_u32
        h.file_size += h.image_size
      else
        step = (3*d.x + 3) & ~3
        h.image_size = (d.y &* step).to_u32
        h.file_size += h.image_size
        h.bpp = 24_u16
      end
      h.write(io)
      # io.write_bytes(palette, IO::ByteFormat::LittleEndian) if palette.size > 0
      io.write(palette) if palette.size > 0

      return if d.x == 0 || d.y == 0

      case image
      when CrImage::Gray
        img = image.as(CrImage::Gray)
        encode_paletted(img.pix, d.x, d.y, img.stride, step)
      when CrImage::Paletted
        img = image.as(CrImage::Paletted)
        encode_paletted(img.pix, d.x, d.y, img.stride, step)
      when CrImage::RGBA
        img = image.as(CrImage::RGBA)
        encode_rgba(img.pix, d.x, d.y, img.stride, step, opaque)
      when CrImage::NRGBA
        img = image.as(CrImage::NRGBA)
        encode_nrgba(img.pix, d.x, d.y, img.stride, step, opaque)
      else
        encode(image, step)
      end
    end

    # Encodes paletted or grayscale image data.
    #
    # Writes pixel indices row by row from bottom to top (BMP standard).
    # Adds padding bytes to align each row to 4-byte boundary.
    #
    # Parameters:
    # - `pix` : Pixel data (palette indices)
    # - `dx` : Image width
    # - `dy` : Image height
    # - `stride` : Bytes per row in source data
    # - `step` : Bytes per row with padding
    private def encode_paletted(pix, dx, dy, stride, step) : Nil
      padding = Bytes.empty
      padding = Bytes.new(step - dx) if dx < step
      (dy - 1).downto(0) do |y|
        min = y*stride + 0
        max = y*stride + dx
        io.write(pix[min...max])
        io.write(padding) if padding.size > 0
      end
    end

    # Encodes RGBA image data with premultiplied alpha.
    #
    # Handles:
    # - RGB to BGR byte order conversion
    # - Premultiplied to non-premultiplied alpha conversion
    # - 24-bit encoding for opaque images (no alpha channel)
    # - 32-bit encoding for transparent images (BGRA format)
    # - Bottom-up row storage
    #
    # Parameters:
    # - `pix` : RGBA pixel data (premultiplied)
    # - `dx` : Image width
    # - `dy` : Image height
    # - `stride` : Bytes per row in source data
    # - `step` : Bytes per row in output
    # - `opaque` : True if image has no transparency
    private def encode_rgba(pix, dx, dy, stride, step, opaque) : Nil
      buf = Bytes.new(step)
      if opaque
        (dy - 1).downto(0) do |y|
          min = y * stride + 0
          max = y * stride + dx*4
          off = 0
          min.step(to: max - 1, by: 4) do |i|
            buf[off + 2] = pix[i + 0]
            buf[off + 1] = pix[i + 1]
            buf[off + 0] = pix[i + 2]
            off += 3
          end
          io.write(buf)
        end
      else
        (dy - 1).downto(0) do |y|
          min = y * stride + 0
          max = y * stride + dx*4
          off = 0
          min.step(to: max - 1, by: 4) do |i|
            a = pix[i + 3].to_u32
            if a == 0
              buf[off + 2] = 0
              buf[off + 1] = 0
              buf[off + 0] = 0
              buf[off + 3] = 0
              off += 4
              next
            elsif a == 0xff
              buf[off + 2] = pix[i + 0]
              buf[off + 1] = pix[i + 1]
              buf[off + 0] = pix[i + 2]
              buf[off + 3] = 0xff_u8
              off += 4
              next
            end
            # Convert from premultiplied to non-premultiplied alpha
            buf[off + 2] = ((pix[i + 0].to_u32 * 0xff) // a).clamp(0, 255).to_u8
            buf[off + 1] = ((pix[i + 1].to_u32 * 0xff) // a).clamp(0, 255).to_u8
            buf[off + 0] = ((pix[i + 2].to_u32 * 0xff) // a).clamp(0, 255).to_u8
            buf[off + 3] = a.to_u8
            off += 4
          end
          io.write(buf)
        end
      end
    end

    # Encodes NRGBA image data with non-premultiplied alpha.
    #
    # Handles:
    # - RGB to BGR byte order conversion
    # - 24-bit encoding for opaque images (no alpha channel)
    # - 32-bit encoding for transparent images (BGRA format)
    # - Bottom-up row storage
    #
    # Parameters:
    # - `pix` : NRGBA pixel data (non-premultiplied)
    # - `dx` : Image width
    # - `dy` : Image height
    # - `stride` : Bytes per row in source data
    # - `step` : Bytes per row in output
    # - `opaque` : True if image has no transparency
    private def encode_nrgba(pix, dx, dy, stride, step, opaque) : Nil
      buf = Bytes.new(step)
      if opaque
        (dy - 1).downto(0) do |y|
          min = y * stride + 0
          max = y * stride + dx*4
          off = 0
          min.step(to: max - 1, by: 4) do |i|
            buf[off + 2] = pix[i + 0]
            buf[off + 1] = pix[i + 1]
            buf[off + 0] = pix[i + 2]
            off += 3
          end
          io.write(buf)
        end
      else
        (dy - 1).downto(0) do |y|
          min = y * stride + 0
          max = y * stride + dx*4
          off = 0
          min.step(to: max - 1, by: 4) do |i|
            buf[off + 2] = pix[i + 0]
            buf[off + 1] = pix[i + 1]
            buf[off + 0] = pix[i + 2]
            buf[off + 3] = pix[i + 3]
            off += 4
          end
          io.write(buf)
        end
      end
    end

    # Encodes generic image types by converting pixels to 24-bit RGB.
    #
    # Fallback encoder for image types that don't have optimized encoding.
    # Converts each pixel using the image's color model and writes as BGR.
    #
    # Parameters:
    # - `image` : Source image
    # - `step` : Bytes per row with padding
    private def encode(image : CrImage::Image, step : Int32)
      d = image.bounds
      buf = Bytes.new(step)
      y = d.max.y - 1
      while y >= d.min.y
        off = 0
        d.min.x.step(to: d.max.x - 1, by: 1) do |x|
          r, g, b, _ = image.at(x, y).rgba
          buf[off + 2] = (r >> 8).to_u8
          buf[off + 1] = (g >> 8).to_u8
          buf[off + 0] = (b >> 8).to_u8
          off += 3
        end
        io.write(buf)
        y -= 1
      end
    end
  end

  # BMP file header structure.
  #
  # Contains:
  # - File signature ("BM")
  # - File size
  # - Pixel data offset
  # - DIB header size and image properties
  # - Compression and color information
  #
  # All fields are written in little-endian byte order.
  private class Header
    property sig : Bytes = "BM".to_slice
    property file_size : UInt32 = 0_u32
    property reserved : Slice(UInt16) = Slice(UInt16).new(2)
    property pix_offset : UInt32 = 0_u32
    property dib_header_size : UInt32 = 0_u32
    property width : UInt32 = 0_u32
    property height : UInt32 = 0_u32
    property color_plane : UInt16 = 0_u16
    property bpp : UInt16 = 8_u16
    property compression : UInt32 = 0_u32
    property image_size : UInt32 = 0_u32
    property xpixel_per_meter : UInt32 = 0_u32
    property ypixel_per_meter : UInt32 = 0_u32
    property color_use : UInt32 = 0_u32
    property color_important : UInt32 = 0_u32

    def write(io : IO)
      IO::ByteFormat::LittleEndian.encode(sig[0], io)
      IO::ByteFormat::LittleEndian.encode(sig[1], io)
      IO::ByteFormat::LittleEndian.encode(file_size, io)
      IO::ByteFormat::LittleEndian.encode(reserved[0], io)
      IO::ByteFormat::LittleEndian.encode(reserved[1], io)
      IO::ByteFormat::LittleEndian.encode(pix_offset, io)
      IO::ByteFormat::LittleEndian.encode(dib_header_size, io)
      IO::ByteFormat::LittleEndian.encode(width, io)
      IO::ByteFormat::LittleEndian.encode(height, io)
      IO::ByteFormat::LittleEndian.encode(color_plane, io)
      IO::ByteFormat::LittleEndian.encode(bpp, io)
      IO::ByteFormat::LittleEndian.encode(compression, io)
      IO::ByteFormat::LittleEndian.encode(image_size, io)
      IO::ByteFormat::LittleEndian.encode(xpixel_per_meter, io)
      IO::ByteFormat::LittleEndian.encode(ypixel_per_meter, io)
      IO::ByteFormat::LittleEndian.encode(color_use, io)
      IO::ByteFormat::LittleEndian.encode(color_important, io)
    end
  end
end
