require "./ico"

module CrImage::ICO
  # Writes ICO (Windows Icon) files
  #
  # Encodes images as 32-bit BMP with alpha channel for maximum compatibility.
  # Supports writing single icons or multi-resolution ICO files.
  #
  # ## Limitations
  #
  # - Maximum 256 images per file
  # - All images encoded as 32-bit BGRA BMP
  # - Recommended sizes: 16, 32, 48, 64, 128, 256 pixels
  class Writer
    @io : IO
    @images : Array(CrImage::Image)

    private def initialize(@io, images)
      @images = images.map(&.as(CrImage::Image))
    end

    # Writes a single image as ICO file
    #
    # Creates an ICO containing one icon at the image's dimensions.
    def self.write(path : String, image : CrImage::Image) : Nil
      File.open(path, "wb") do |file|
        write(file, image)
      end
    end

    # Writes a single image to IO as ICO
    def self.write(io : IO, image : CrImage::Image) : Nil
      write_multi_internal(io, [image.as(CrImage::Image)])
    end

    # Writes multiple images as multi-resolution ICO file
    #
    # Creates an ICO containing multiple icon sizes. This is recommended
    # for favicons and application icons to support different display contexts.
    #
    # Raises `ArgumentError` if array is empty or contains more than 256 images.
    def self.write_multi(path : String, images : Array(CrImage::Image)) : Nil
      File.open(path, "wb") do |file|
        write_multi(file, images)
      end
    end

    # Writes multiple images to IO as multi-resolution ICO
    def self.write_multi(io : IO, images : Array(CrImage::Image)) : Nil
      write_multi_internal(io, images)
    end

    # Internal method to write ICO with validation
    private def self.write_multi_internal(io : IO, images : Array(CrImage::Image)) : Nil
      raise ArgumentError.new("At least one image required") if images.empty?
      raise ArgumentError.new("Maximum 256 images allowed") if images.size > 256

      writer = new(io, images)
      writer.write_ico
    end

    # Writes complete ICO file structure
    #
    # Writes header, directory entries, and all image data.
    protected def write_ico
      # Write ICONDIR header
      write_header

      # Calculate offsets for image data
      header_size = 6 + (@images.size * 16)
      offset = header_size

      # Write ICONDIRENTRY for each image
      image_data = [] of Bytes
      @images.each do |img|
        data = encode_image(img)
        image_data << data

        write_entry(img, data.size, offset)
        offset += data.size
      end

      # Write image data
      image_data.each do |data|
        @io.write(data)
      end
    end

    # Writes ICONDIR header (6 bytes)
    #
    # Contains file signature and image count.
    private def write_header
      # ICONDIR structure (6 bytes)
      @io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)               # Reserved (must be 0)
      @io.write_bytes(1_u16, IO::ByteFormat::LittleEndian)               # Type (1 = ICO)
      @io.write_bytes(@images.size.to_u16, IO::ByteFormat::LittleEndian) # Count
    end

    # Writes ICONDIRENTRY for one image (16 bytes)
    #
    # Contains metadata about the image: dimensions, bit depth, size, and offset.
    private def write_entry(img : CrImage::Image, size : Int32, offset : Int32)
      bounds = img.bounds
      width = bounds.width
      height = bounds.height

      # ICONDIRENTRY structure (16 bytes)
      # Width and height (0 means 256)
      @io.write_byte(width >= 256 ? 0_u8 : width.to_u8)
      @io.write_byte(height >= 256 ? 0_u8 : height.to_u8)

      # Color count (0 for true color)
      @io.write_byte(0_u8)

      # Reserved
      @io.write_byte(0_u8)

      # Color planes (0 or 1)
      @io.write_bytes(1_u16, IO::ByteFormat::LittleEndian)

      # Bits per pixel (32 for RGBA)
      @io.write_bytes(32_u16, IO::ByteFormat::LittleEndian)

      # Size of image data
      @io.write_bytes(size.to_u32, IO::ByteFormat::LittleEndian)

      # Offset to image data
      @io.write_bytes(offset.to_u32, IO::ByteFormat::LittleEndian)
    end

    # Encodes image as BMP data for ICO
    #
    # Uses 32-bit BGRA format with alpha channel for maximum compatibility.
    # ICO stores BMP without the 14-byte file header.
    #
    # Returns the encoded bytes including BITMAPINFOHEADER, XOR mask, and AND mask.
    private def encode_image(img : CrImage::Image) : Bytes
      # For modern ICO files, we can use PNG encoding
      # But for maximum compatibility, we'll use BMP format

      bounds = img.bounds
      width = bounds.width
      height = bounds.height

      buffer = IO::Memory.new

      # Write BITMAPINFOHEADER (40 bytes)
      buffer.write_bytes(40_u32, IO::ByteFormat::LittleEndian)              # Header size
      buffer.write_bytes(width.to_i32, IO::ByteFormat::LittleEndian)        # Width
      buffer.write_bytes((height * 2).to_i32, IO::ByteFormat::LittleEndian) # Height (doubled for AND mask)
      buffer.write_bytes(1_u16, IO::ByteFormat::LittleEndian)               # Planes
      buffer.write_bytes(32_u16, IO::ByteFormat::LittleEndian)              # Bit count
      buffer.write_bytes(0_u32, IO::ByteFormat::LittleEndian)               # Compression (0 = none)
      buffer.write_bytes(0_u32, IO::ByteFormat::LittleEndian)               # Image size (can be 0 for uncompressed)
      buffer.write_bytes(0_i32, IO::ByteFormat::LittleEndian)               # X pixels per meter
      buffer.write_bytes(0_i32, IO::ByteFormat::LittleEndian)               # Y pixels per meter
      buffer.write_bytes(0_u32, IO::ByteFormat::LittleEndian)               # Colors used
      buffer.write_bytes(0_u32, IO::ByteFormat::LittleEndian)               # Important colors

      # Write XOR mask (image data) - bottom-up
      row_size = ((width * 32 + 31) // 32) * 4
      padding = row_size - width * 4

      (height - 1).downto(0) do |y|
        width.times do |x|
          color = img.at(x + bounds.min.x, y + bounds.min.y)
          r, g, b, a = color.rgba

          # Write as BGRA
          buffer.write_byte((b >> 8).to_u8)
          buffer.write_byte((g >> 8).to_u8)
          buffer.write_byte((r >> 8).to_u8)
          buffer.write_byte((a >> 8).to_u8)
        end
        # Write padding
        padding.times { buffer.write_byte(0_u8) }
      end

      # Write AND mask (transparency mask) - all zeros since we use alpha channel
      and_mask_row_size = ((width + 31) // 32) * 4
      height.times do
        and_mask_row_size.times { buffer.write_byte(0_u8) }
      end

      buffer.to_slice
    end
  end
end
