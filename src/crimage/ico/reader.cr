require "./ico"

module CrImage::ICO
  # Reads ICO (Windows Icon) files
  #
  # Supports both BMP and PNG encoded icons within ICO containers.
  # Handles multi-resolution files and various bit depths (1, 4, 8, 24, 32-bit).
  class Reader
    @io : IO
    @entries : Array(IconEntry)

    private def initialize(@io)
      @entries = [] of IconEntry
    end

    # Reads ICO file and returns the largest icon
    #
    # This is the standard read method that returns a single image.
    # If the ICO contains multiple sizes, the largest is returned.
    def self.read(path : String) : CrImage::Image
      File.open(path, "rb") do |file|
        read(file)
      end
    end

    # Reads ICO from IO and returns the largest icon
    def self.read(io : IO) : CrImage::Image
      icon = read_all_internal(io)
      icon.largest
    end

    # Reads ICO file and returns all icons with metadata
    #
    # Use this when you need access to all resolutions in the file.
    def self.read_all(path : String) : Icon
      File.open(path, "rb") do |file|
        read_all(file)
      end
    end

    # Reads all icons from IO
    def self.read_all(io : IO) : Icon
      read_all_internal(io)
    end

    # Reads configuration without decoding full image
    #
    # Returns metadata for the largest icon. Much faster than full read
    # when you only need to check dimensions or color model.
    def self.read_config(path : String) : CrImage::Config
      File.open(path, "rb") do |file|
        read_config(file)
      end
    end

    # Reads configuration from IO
    def self.read_config(io : IO) : CrImage::Config
      reader = new(io)
      reader.read_header

      # Find largest entry
      largest = reader.@entries.max_by(&.pixel_count)

      # Return config based on entry
      color_model = if largest.bit_count <= 8
                      Color::Palette.new([Color::BLACK.as(Color::Color)])
                    else
                      Color.rgba_model
                    end

      CrImage::Config.new(color_model, largest.actual_width, largest.actual_height)
    end

    # Internal method to read all icons
    private def self.read_all_internal(io : IO) : Icon
      reader = new(io)
      reader.read_header
      images = reader.read_images
      Icon.new(reader.@entries, images)
    end

    # Reads and validates ICO file header and directory entries
    protected def read_header
      # Read ICONDIR header (6 bytes)
      header = Bytes.new(6)
      @io.read_fully(header)

      # Check magic bytes (reserved=0, type=1 for ICO)
      reserved = IO::ByteFormat::LittleEndian.decode(UInt16, header[0, 2])
      type = IO::ByteFormat::LittleEndian.decode(UInt16, header[2, 2])
      count = IO::ByteFormat::LittleEndian.decode(UInt16, header[4, 2])

      raise FormatError.new("Invalid ICO file: bad magic bytes") unless reserved == 0
      raise FormatError.new("Not an ICO file (type=#{type})") unless type == 1
      raise FormatError.new("Invalid ICO file: no images") if count == 0

      # Read ICONDIRENTRY for each image (16 bytes each)
      count.times do
        entry_data = Bytes.new(16)
        @io.read_fully(entry_data)

        width = entry_data[0].to_i32
        height = entry_data[1].to_i32
        color_count = entry_data[2].to_i32
        reserved = entry_data[3]
        planes = IO::ByteFormat::LittleEndian.decode(UInt16, entry_data[4, 2]).to_i32
        bit_count = IO::ByteFormat::LittleEndian.decode(UInt16, entry_data[6, 2]).to_i32
        size = IO::ByteFormat::LittleEndian.decode(UInt32, entry_data[8, 4]).to_i32
        offset = IO::ByteFormat::LittleEndian.decode(UInt32, entry_data[12, 4]).to_i32

        @entries << IconEntry.new(width, height, color_count, planes, bit_count, size, offset)
      end
    end

    # Reads all image data from the ICO file
    #
    # Automatically detects whether each icon is PNG or BMP encoded
    # and decodes accordingly.
    protected def read_images : Array(CrImage::Image)
      images = [] of CrImage::Image

      @entries.each do |entry|
        # Seek to image data
        @io.seek(entry.offset)

        # Read first few bytes to detect format
        magic = Bytes.new(8)
        @io.read_fully(magic)
        @io.seek(entry.offset) # Reset

        # Check if it's PNG (modern ICO files can contain PNG)
        if magic[0, 4] == PNG_MAGIC
          # It's a PNG image
          limited_io = IO::Sized.new(@io, entry.size.to_i64)
          images << PNG.read(limited_io)
        else
          # It's a BMP image (without file header)
          images << read_bmp_data(entry)
        end
      end

      images
    end

    # Reads BMP-encoded icon data
    #
    # ICO files store BMP data without the 14-byte BITMAPFILEHEADER.
    # Supports 1, 4, 8, 24, and 32-bit color depths.
    private def read_bmp_data(entry : IconEntry) : CrImage::Image
      # ICO stores BMP data without the 14-byte BITMAPFILEHEADER
      # Read BITMAPINFOHEADER
      info_header_size = @io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)

      # Seek back to read full info header
      @io.seek(@io.pos - 4)

      info_header = Bytes.new(info_header_size)
      @io.read_fully(info_header)

      width = IO::ByteFormat::LittleEndian.decode(Int32, info_header[4, 4])
      # Height in ICO is doubled (includes AND mask)
      height = IO::ByteFormat::LittleEndian.decode(Int32, info_header[8, 4]) // 2
      planes = IO::ByteFormat::LittleEndian.decode(UInt16, info_header[12, 2])
      bit_count = IO::ByteFormat::LittleEndian.decode(UInt16, info_header[14, 2])
      compression = IO::ByteFormat::LittleEndian.decode(UInt32, info_header[16, 4])

      raise FormatError.new("Compressed BMP in ICO not supported") if compression != 0

      # Read color palette if present
      palette = nil
      if bit_count <= 8
        color_count = entry.color_count == 0 ? (1 << bit_count) : entry.color_count
        colors = [] of Color::Color
        color_count.times do
          b = @io.read_byte || 0_u8
          g = @io.read_byte || 0_u8
          r = @io.read_byte || 0_u8
          reserved = @io.read_byte || 0_u8
          colors << Color::RGBA.new(r, g, b, 255).as(Color::Color)
        end
        palette = Color::Palette.new(colors)
      end

      # Read XOR mask (actual image data)
      img = if bit_count == 32
              read_32bit_data(width, height)
            elsif bit_count == 24
              read_24bit_data(width, height)
            elsif bit_count <= 8 && palette
              read_paletted_data(width, height, bit_count.to_i, palette)
            else
              raise FormatError.new("Unsupported bit depth: #{bit_count}")
            end

      # Skip AND mask (we use alpha channel from XOR mask for 32-bit)
      # For other formats, we could read AND mask for transparency

      img
    end

    # Reads 32-bit BGRA image data with alpha channel
    private def read_32bit_data(width : Int32, height : Int32) : CrImage::Image
      img = NRGBA.new(CrImage.rect(0, 0, width, height))
      row_size = ((width * 32 + 31) // 32) * 4

      # BMP is stored bottom-up
      (height - 1).downto(0) do |y|
        width.times do |x|
          b = @io.read_byte || 0_u8
          g = @io.read_byte || 0_u8
          r = @io.read_byte || 0_u8
          a = @io.read_byte || 0_u8
          img.set(x, y, Color::NRGBA.new(r, g, b, a))
        end
        # Skip padding
        padding = row_size - width * 4
        @io.skip(padding) if padding > 0
      end

      img
    end

    # Reads 24-bit BGR image data (no alpha)
    private def read_24bit_data(width : Int32, height : Int32) : CrImage::Image
      img = RGBA.new(CrImage.rect(0, 0, width, height))
      row_size = ((width * 24 + 31) // 32) * 4

      # BMP is stored bottom-up
      (height - 1).downto(0) do |y|
        width.times do |x|
          b = @io.read_byte || 0_u8
          g = @io.read_byte || 0_u8
          r = @io.read_byte || 0_u8
          img.set(x, y, Color::RGBA.new(r, g, b, 255))
        end
        # Skip padding
        padding = row_size - width * 3
        @io.skip(padding) if padding > 0
      end

      img
    end

    # Reads paletted (indexed color) image data
    #
    # Supports 1, 4, and 8-bit color depths with custom palettes.
    private def read_paletted_data(width : Int32, height : Int32, bit_count : Int32, palette : Color::Palette) : CrImage::Image
      img = Paletted.new(CrImage.rect(0, 0, width, height), palette)
      pixels_per_byte = 8 // bit_count
      row_size = ((width * bit_count + 31) // 32) * 4

      # BMP is stored bottom-up
      (height - 1).downto(0) do |y|
        x = 0
        bytes_read = 0
        while x < width
          byte = @io.read_byte || 0_u8
          bytes_read += 1

          pixels_per_byte.times do |i|
            break if x >= width
            shift = 8 - bit_count - (i * bit_count)
            mask = (1 << bit_count) - 1
            index = (byte >> shift) & mask
            img.set_color_index(x, y, index.to_u8)
            x += 1
          end
        end
        # Skip padding
        padding = row_size - bytes_read
        @io.skip(padding) if padding > 0
      end

      img
    end
  end
end
