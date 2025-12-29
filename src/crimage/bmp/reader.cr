require "./bmp"
require "../image"

module CrImage::BMP
  # BMP Reader decodes Windows Bitmap files.
  #
  # Supports:
  # - BITMAPFILEHEADER + BITMAPINFOHEADER structure
  # - 8-bit paletted (256 colors with BGR palette)
  # - 24-bit RGB (BGR byte order)
  # - 32-bit RGBA (BGRA byte order)
  # - Top-down (negative height) and bottom-up orientation
  # - Uncompressed images only (compression = 0)
  # - 4-byte row alignment padding
  #
  # Does not support:
  # - Compressed formats (RLE, BITFIELDS with custom masks)
  # - Multiple color planes
  # - Bit depths other than 8, 24, 32
  class Reader
    # BMP header size constants
    private module Consts
      FILE_HEADER_LEN    =  14 # BITMAPFILEHEADER size
      INFO_HEADER_LEN    =  40 # BITMAPINFOHEADER size (Windows 3.x)
      V4_INFO_HEADER_LEN = 108 # BITMAPV4HEADER size
      V5_INFO_HEADER_LEN = 124 # BITMAPV5HEADER size
    end

    include Consts
    getter io : IO
    getter image : CrImage::Image?

    getter width : Int32
    getter height : Int32
    getter depth : Int32
    getter topdown : Bool

    private def initialize(@io)
      @height = 0
      @width = 0
      @depth = 0
      @topdown = false
    end

    # Reads and decodes a BMP image from a file.
    #
    # Parameters:
    # - `path` : Path to the BMP file
    #
    # Returns: Decoded image (Paletted for 8-bit, RGBA for 24-bit, NRGBA for 32-bit)
    def self.read(path : String) : CrImage::Image
      File.open(path) do |file|
        read(file)
      end
    end

    # Reads and decodes a BMP image from an IO stream.
    #
    # Parameters:
    # - `io` : IO stream containing BMP data
    #
    # Returns: Decoded image
    def self.read(io : IO) : CrImage::Image
      new(io).parse
    end

    # Reads BMP metadata without decoding pixel data.
    #
    # Parses the file header and info header to extract dimensions,
    # bit depth, and color palette (for 8-bit images).
    #
    # Parameters:
    # - `path` : Path to the BMP file
    #
    # Returns: Config with image metadata
    #
    # Raises: `FormatError` if format is invalid or unsupported
    def self.read_config(path : String) : CrImage::Config
      File.open(path) do |file|
        bmp = new(file)
        bmp.parse_config
      end
    end

    # Reads BMP metadata from an IO stream without decoding pixel data.
    #
    # Parameters:
    # - `io` : IO stream containing BMP data
    #
    # Returns: Config with image metadata
    def self.read_config(io : IO) : CrImage::Config
      new(io).parse_config
    end

    protected def parse : CrImage::Image
      c = parse_config
      case depth
      when  8 then decode_paletted(c)
      when 24 then decode_rgb(c)
      when 32 then decode_nrgba(c)
      else
        raise FormatError.new("Unsupported BMP depth for decoding: #{@depth}")
      end
    end

    protected def parse_config : CrImage::Config
      # We only support those BMP images that are a BITMAPFILEHEADER
      # immediately followed by a BITMAPINFOHEADER

      b = Bytes.new(1024)
      n = io.read_fully(b[...FILE_HEADER_LEN + 4])
      raise FormatError.new("Unexpected EOF encountered") unless n == FILE_HEADER_LEN + 4

      raise FormatError.new("Invalid BMP Format") unless String.new(b[...2]) == "BM"

      offset = IO::ByteFormat::LittleEndian.decode(UInt32, b[10...14])
      info_len = IO::ByteFormat::LittleEndian.decode(UInt32, b[14...18])

      raise FormatError.new("Invalid BMP info header length: #{info_len} (expected #{INFO_HEADER_LEN}, #{V4_INFO_HEADER_LEN}, or #{V5_INFO_HEADER_LEN})") if info_len != INFO_HEADER_LEN && info_len != V4_INFO_HEADER_LEN && info_len != V5_INFO_HEADER_LEN
      n = io.read_fully(b[FILE_HEADER_LEN + 4...FILE_HEADER_LEN + info_len])
      raise FormatError.new("Unexpected EOF encountered") unless n == info_len - 4

      # BMP stores width and height as signed 32-bit integers
      # Negative height indicates top-down orientation (DIB v3+)
      @width = IO::ByteFormat::LittleEndian.decode(Int32, b[18...22])
      @height = IO::ByteFormat::LittleEndian.decode(Int32, b[22...26])

      if height < 0
        @height, @topdown = -height, true
      end

      raise FormatError.new("Invalid BMP dimensions: width=#{width}, height=#{height} (must be positive after orientation adjustment)") if width <= 0 || height <= 0

      # We only support 1 plane and 8, 24 or 32 bits per pixel and no compression
      planes = IO::ByteFormat::LittleEndian.decode(UInt16, b[26...28])
      bpp = IO::ByteFormat::LittleEndian.decode(UInt16, b[28...30])
      compression = IO::ByteFormat::LittleEndian.decode(UInt16, b[30...34])

      # if compression is set to BITFIELDS, but the bitmask is set to default mask
      # that woulbe be used if compression was set to 0, we can continue as if compression was 0
      if compression == 3 && info_len > INFO_HEADER_LEN &&
         IO::ByteFormat::LittleEndian.decode(UInt32, b[54...58]) == 0xff0000 &&
         IO::ByteFormat::LittleEndian.decode(UInt32, b[58...62]) == 0xff00 &&
         IO::ByteFormat::LittleEndian.decode(UInt32, b[62...66]) == 0xff &&
         IO::ByteFormat::LittleEndian.decode(UInt32, b[66...70]) == 0xff000000
        compression = 0
      end

      raise FormatError.new("Unsupported BMP format: planes=#{planes} (expected 1), compression=#{compression} (expected 0)") unless planes == 1 && compression == 0

      case bpp
      when 8
        raise FormatError.new("Invalid BMP 8-bit offset: #{offset} (expected #{FILE_HEADER_LEN + info_len + 256*4})") unless offset == FILE_HEADER_LEN + info_len + 256*4
        n = io.read_fully(b[...256*4])
        raise FormatError.new("Unexpected EOF encountered") unless n == 256*4
        pcm = Color::Palette.new(Array(Color::Color).new(256) do |i|
          # BMP images are stored in BGR order rather than RGB order
          # Every 4th byte is padding
          Color::RGBA.new(b[4*i + 2], b[4*i + 1], b[4*i + 0], 0xFF_u8)
        end)
        @depth = 8
        CrImage::Config.new(pcm, width, height)
      when 24
        raise FormatError.new("Invalid BMP 24-bit offset: #{offset} (expected #{FILE_HEADER_LEN + info_len})") unless offset == FILE_HEADER_LEN + info_len
        @depth = 24
        CrImage::Config.new(Color.rgba_model, width, height)
      when 32
        raise FormatError.new("Invalid BMP 32-bit offset: #{offset} (expected #{FILE_HEADER_LEN + info_len})") unless offset == FILE_HEADER_LEN + info_len
        @depth = 32
        CrImage::Config.new(Color.rgba_model, width, height)
      else
        raise FormatError.new("Unsupported BMP bit depth: #{bpp} (supported: 8, 24, 32)")
      end
    end

    # Decodes an 8-bit paletted BMP image.
    #
    # Reads pixel data row by row, handling:
    # - Bottom-up orientation (default, rows stored from bottom to top)
    # - Top-down orientation (negative height in header)
    # - 4-byte row alignment padding
    #
    # Parameters:
    # - `c` : Config containing palette and dimensions
    #
    # Returns: Paletted image with 256-color palette
    private def decode_paletted(c : CrImage::Config)
      paletted = CrImage::Paletted.new(CrImage.rect(0, 0, c.width, c.height), c.color_model.as(Color::Palette))
      return paletted if c.width == 0 || c.height == 0
      tmp = Bytes.new(4)
      y0, y1, y_delta = c.height - 1, -1, -1
      if topdown
        y0, y1, y_delta = 0, c.height, 1
      end
      y = y0
      while y != y1
        p = paletted.pix[y*paletted.stride...y*paletted.stride + c.width]
        io.read_fully(p)

        # Each row is 4-byte aligned
        if c.width % 4 != 0
          io.read_fully(tmp[...4 - c.width % 4])
        end
        y += y_delta
      end
      paletted
    end

    # Decodes a 24-bit RGB BMP image.
    #
    # Reads pixel data row by row, handling:
    # - BGR to RGB byte order conversion
    # - Bottom-up or top-down orientation
    # - 4-byte row alignment padding (3 bytes per pixel)
    # - Alpha channel set to fully opaque (0xFF)
    #
    # Parameters:
    # - `c` : Config containing dimensions
    #
    # Returns: RGBA image with opaque alpha
    private def decode_rgb(c : CrImage::Config)
      rgba = CrImage::RGBA.new(CrImage.rect(0, 0, c.width, c.height))
      return rgba if c.width == 0 || c.height == 0
      # There are 3 bytes per pixel, and each row is 4-byte aligned.
      b = Bytes.new((3*c.width + 3) & ~3)
      y0, y1, y_delta = c.height - 1, -1, -1
      if topdown
        y0, y1, y_delta = 0, c.height, 1
      end
      y = y0
      while y != y1
        io.read_fully(b)
        p = rgba.pix[y*rgba.stride...y*rgba.stride + c.width*4]
        j = 0
        0.step(to: p.size - 1, by: 4) do |i|
          # BMP images are stored in BGR order rather than RGB order.
          p[i + 0] = b[j + 2]
          p[i + 1] = b[j + 1]
          p[i + 2] = b[j + 0]
          p[i + 3] = 0xFF_u8
          j += 3
        end
        y += y_delta
      end
      rgba
    end

    # Decodes a 32-bit RGBA BMP image.
    #
    # Reads pixel data row by row, handling:
    # - BGRA to RGBA byte order conversion (swap R and B channels)
    # - Bottom-up or top-down orientation
    # - No padding needed (4 bytes per pixel already aligned)
    # - Non-premultiplied alpha (NRGBA format)
    #
    # Parameters:
    # - `c` : Config containing dimensions
    #
    # Returns: NRGBA image with transparency support
    private def decode_nrgba(c : CrImage::Config)
      rgba = CrImage::NRGBA.new(CrImage.rect(0, 0, c.width, c.height))
      return rgba if c.width == 0 || c.height == 0
      y0, y1, y_delta = c.height - 1, -1, -1
      if topdown
        y0, y1, y_delta = 0, c.height, 1
      end
      y = y0
      while y != y1
        p = rgba.pix[y*rgba.stride...y*rgba.stride + c.width*4]
        io.read_fully(p)
        0.step(to: p.size - 1, by: 4) do |i|
          p[i + 0], p[i + 2] = p[i + 2], p[i + 0]
        end
        y += y_delta
      end
      rgba
    end
  end
end
