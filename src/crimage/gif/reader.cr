require "./gif"
require "./lzw"
require "../decompression_guard"

module CrImage::GIF
  # GIF (Graphics Interchange Format) image decoder
  #
  # Implements GIF decoding according to GIF89a specification.
  # Supports both static images and animated GIFs with multiple frames.
  class Reader
    @io : IO
    @width : Int32
    @height : Int32
    @global_color_table : Color::Palette?
    @background_index : UInt8
    @loop_count : Int32
    @decompression_guard : DecompressionGuard::Guard

    private def initialize(@io, decompression_config : DecompressionGuard::Config? = nil)
      @width = 0
      @height = 0
      @global_color_table = nil
      @background_index = 0_u8
      @loop_count = 0
      @decompression_guard = DecompressionGuard.create("GIF", decompression_config)
    end

    def self.read(path : String) : CrImage::Image
      File.open(path, "rb") do |file|
        read(file)
      end
    end

    def self.read(io : IO) : CrImage::Image
      reader = new(io)
      reader.parse
    end

    def self.read_config(path : String) : CrImage::Config
      File.open(path, "rb") do |file|
        read_config(file)
      end
    end

    def self.read_config(io : IO) : CrImage::Config
      reader = new(io)
      reader.parse_config
    end

    def self.read_animation(path : String) : Animation
      File.open(path, "rb") do |file|
        read_animation(file)
      end
    end

    def self.read_animation(io : IO) : Animation
      reader = new(io)
      reader.parse_animation
    end

    protected def parse : CrImage::Image
      read_header
      read_logical_screen_descriptor

      # Read first image frame
      image : CrImage::Image? = nil

      loop do
        separator = @io.read_byte
        break if separator.nil?

        case separator
        when EXTENSION_INTRODUCER
          skip_extension
        when IMAGE_SEPARATOR
          image = read_image_data
          break # Return first frame
        when TRAILER
          break
        else
          raise FormatError.new("Unknown block type: 0x#{separator.to_s(16)}")
        end
      end

      image || raise FormatError.new("No image data found in GIF")
    end

    protected def parse_config : CrImage::Config
      read_header
      read_logical_screen_descriptor

      palette = @global_color_table || Color::Palette.new([Color::RGBA.new(0, 0, 0, 255).as(Color::Color)])
      CrImage::Config.new(palette, @width, @height)
    end

    private def read_header
      header = Bytes.new(6)
      @io.read_fully(header)

      unless header == GIF_HEADER_87A || header == GIF_HEADER_89A
        raise FormatError.new("Invalid GIF header")
      end
    end

    private def read_logical_screen_descriptor
      @width = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
      @height = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i

      packed = @io.read_byte || 0_u8
      @background_index = @io.read_byte || 0_u8
      aspect_ratio = @io.read_byte || 0_u8

      # Parse packed field
      has_global_color_table = (packed & 0x80) != 0
      color_resolution = ((packed & 0x70) >> 4) + 1
      global_color_table_size = 2 << (packed & 0x07)

      if has_global_color_table
        @global_color_table = read_color_table(global_color_table_size)
      end
    end

    private def read_color_table(size : Int32) : Color::Palette
      colors = [] of Color::Color

      size.times do
        r = @io.read_byte || 0_u8
        g = @io.read_byte || 0_u8
        b = @io.read_byte || 0_u8
        colors << Color::RGBA.new(r, g, b, 255_u8).as(Color::Color)
      end

      Color::Palette.new(colors)
    end

    protected def parse_animation : Animation
      read_header
      read_logical_screen_descriptor

      frames = [] of Frame
      current_gce : GraphicControlExtension? = nil

      loop do
        separator = @io.read_byte
        break if separator.nil?

        case separator
        when EXTENSION_INTRODUCER
          ext = read_extension
          if ext.is_a?(GraphicControlExtension)
            current_gce = ext
          elsif ext.is_a?(ApplicationExtension) && ext.identifier == "NETSCAPE2.0"
            @loop_count = ext.loop_count
          end
        when IMAGE_SEPARATOR
          image = read_image_data
          delay = current_gce.try(&.delay) || 0
          disposal = current_gce.try(&.disposal) || DisposalMethod::Unspecified
          transparent_index = current_gce.try(&.transparent_index)

          frames << Frame.new(image, delay, disposal, transparent_index)
          current_gce = nil
        when TRAILER
          break
        else
          raise FormatError.new("Unknown block type: 0x#{separator.to_s(16)}")
        end
      end

      Animation.new(frames, @width, @height, @loop_count)
    end

    private struct GraphicControlExtension
      property delay : Int32
      property disposal : DisposalMethod
      property transparent_index : Int32?

      def initialize(@delay, @disposal, @transparent_index)
      end
    end

    private struct ApplicationExtension
      property identifier : String
      property loop_count : Int32

      def initialize(@identifier, @loop_count = 0)
      end
    end

    private def skip_extension
      label = @io.read_byte || 0_u8

      # Skip extension data blocks
      loop do
        block_size = @io.read_byte || 0_u8
        break if block_size == 0

        @io.skip(block_size)
      end
    end

    private def read_extension : GraphicControlExtension | ApplicationExtension | Nil
      label = @io.read_byte || 0_u8

      case label
      when GRAPHIC_CONTROL_LABEL
        block_size = @io.read_byte || 0_u8
        return nil if block_size != 4

        packed = @io.read_byte || 0_u8
        delay = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
        transparent_index_byte = @io.read_byte || 0_u8
        @io.read_byte # Block terminator

        disposal = DisposalMethod.from_value((packed >> 2) & 0x07)
        has_transparent = (packed & 0x01) != 0
        transparent_index = has_transparent ? transparent_index_byte.to_i : nil

        GraphicControlExtension.new(delay, disposal, transparent_index)
      when APPLICATION_EXTENSION
        block_size = @io.read_byte || 0_u8
        return nil if block_size != 11

        identifier = Bytes.new(8)
        @io.read_fully(identifier)
        auth_code = Bytes.new(3)
        @io.read_fully(auth_code)

        identifier_str = String.new(identifier)

        # Read application data
        loop_count = 0
        loop do
          sub_block_size = @io.read_byte || 0_u8
          break if sub_block_size == 0

          if identifier_str == "NETSCAPE2.0" && sub_block_size >= 3
            @io.read_byte # Sub-block ID
            loop_count = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
          else
            @io.skip(sub_block_size)
          end
        end

        ApplicationExtension.new(identifier_str, loop_count)
      else
        # Skip unknown extension
        loop do
          block_size = @io.read_byte || 0_u8
          break if block_size == 0
          @io.skip(block_size)
        end
        nil
      end
    end

    private def read_image_data : CrImage::Image
      # Read image descriptor
      left = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
      top = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
      width = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i
      height = @io.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_i

      packed = @io.read_byte || 0_u8

      # Parse packed field
      has_local_color_table = (packed & 0x80) != 0
      interlaced = (packed & 0x40) != 0
      local_color_table_size = 2 << (packed & 0x07)

      # Read local color table if present
      palette = if has_local_color_table
                  read_color_table(local_color_table_size)
                else
                  @global_color_table || Color::Palette.new([Color::RGBA.new(0, 0, 0, 255).as(Color::Color)])
                end

      # Read LZW minimum code size
      min_code_size = (@io.read_byte || 8_u8).to_i

      # Validate expected decompressed size
      @decompression_guard.validate_expected_size(width, height, 1) # 1 byte per pixel for paletted

      # Read compressed image data blocks
      compressed_data = IO::Memory.new
      loop do
        block_size = @io.read_byte || 0_u8
        break if block_size == 0

        block = Bytes.new(block_size)
        @io.read_fully(block)
        compressed_data.write(block)

        # Track compressed bytes
        @decompression_guard.add_compressed(block_size)
      end

      # Decompress using LZW
      pixel_data = LZW.decompress(compressed_data.to_slice, min_code_size)

      # Track decompressed bytes
      @decompression_guard.add_decompressed(pixel_data.size)

      # Create paletted image
      image = CrImage::Paletted.new(CrImage.rect(0, 0, width, height), palette)
      if interlaced
        fill_interlaced(image, pixel_data, width, height)
      else
        fill_sequential(image, pixel_data, width, height)
      end

      image
    end

    private def fill_sequential(image : CrImage::Paletted, data : Bytes, width : Int32, height : Int32)
      idx = 0
      height.times do |y|
        width.times do |x|
          break if idx >= data.size
          image.set_color_index(x, y, data[idx])
          idx += 1
        end
      end
    end

    private def fill_interlaced(image : CrImage::Paletted, data : Bytes, width : Int32, height : Int32)
      # GIF interlacing uses 4 passes
      passes = [
        {start: 0, step: 8}, # Pass 1: every 8th row, starting at 0
        {start: 4, step: 8}, # Pass 2: every 8th row, starting at 4
        {start: 2, step: 4}, # Pass 3: every 4th row, starting at 2
        {start: 1, step: 2}, # Pass 4: every 2nd row, starting at 1
      ]

      idx = 0
      passes.each do |pass|
        y = pass[:start]
        while y < height
          width.times do |x|
            break if idx >= data.size
            image.set_color_index(x, y, data[idx])
            idx += 1
          end
          y += pass[:step]
        end
      end
    end
  end
end
