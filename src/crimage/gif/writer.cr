require "./gif"
require "./lzw"

module CrImage::GIF
  # GIF writer implementation
  class Writer
    @io : IO
    @image : CrImage::Image
    @transparent_index : Int32?

    private def initialize(@io, @image, @transparent_index = nil)
    end

    def self.write(path : String, image : CrImage::Image, transparent_index : Int32? = nil) : Nil
      File.open(path, "wb") do |file|
        write(file, image, transparent_index)
      end
    end

    def self.write(io : IO, image : CrImage::Image, transparent_index : Int32? = nil) : Nil
      writer = new(io, image, transparent_index)
      writer.encode
    end

    protected def encode
      bounds = @image.bounds
      width = bounds.width
      height = bounds.height

      # Convert image to paletted if needed
      paletted_image, palette = convert_to_paletted

      # Write header
      write_header

      # Write logical screen descriptor
      write_logical_screen_descriptor(width, height, palette.size)

      # Write global color table
      write_color_table(palette)

      # Write graphic control extension if transparency is used
      if @transparent_index
        write_graphic_control_extension(@transparent_index.not_nil!)
      end

      # Write image descriptor
      write_image_descriptor(width, height)

      # Write image data
      write_image_data(paletted_image, palette)

      # Write trailer
      @io.write_byte(TRAILER)
    end

    private def convert_to_paletted : {CrImage::Paletted, Color::Palette}
      if paletted = @image.as?(CrImage::Paletted)
        return {paletted, paletted.palette}
      end

      # Build palette from image colors
      bounds = @image.bounds
      color_map = Hash(UInt32, Color::Color).new

      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          color = @image.at(x, y)
          r, g, b, a = color.rgba
          # Create a hash key from RGBA values
          key = (r.to_u32 << 24) | (g.to_u32 << 16) | (b.to_u32 << 8) | a.to_u32
          color_map[key] = color unless color_map.has_key?(key)

          # GIF supports max 256 colors
          if color_map.size >= 256
            break
          end
        end
        break if color_map.size >= 256
      end

      # Create palette
      colors = color_map.values.map do |c|
        r, g, b, a = c.rgba
        Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8).as(Color::Color)
      end
      palette = Color::Palette.new(colors)

      # Create paletted image
      paletted = CrImage::Paletted.new(CrImage.rect(0, 0, bounds.width, bounds.height), palette)

      # Fill paletted image
      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          color = @image.at(x, y)
          r, g, b, a = color.rgba
          key = (r.to_u32 << 24) | (g.to_u32 << 16) | (b.to_u32 << 8) | a.to_u32

          # Find closest color in palette
          index = find_color_index(palette, color)
          paletted.set_color_index(x - bounds.min.x, y - bounds.min.y, index.to_u8)
        end
      end

      {paletted, palette}
    end

    private def find_color_index(palette : Color::Palette, color : Color::Color) : Int32
      r1, g1, b1, _ = color.rgba

      best_index = 0
      best_distance = UInt64::MAX

      palette.size.times do |i|
        r2, g2, b2, _ = palette[i].rgba

        # Calculate squared Euclidean distance
        dr = r1.to_i64 - r2.to_i64
        dg = g1.to_i64 - g2.to_i64
        db = b1.to_i64 - b2.to_i64
        distance = (dr * dr + dg * dg + db * db).to_u64

        if distance < best_distance
          best_distance = distance
          best_index = i
        end
      end

      best_index
    end

    private def write_header
      @io.write(GIF_HEADER_89A)
    end

    private def write_logical_screen_descriptor(width : Int32, height : Int32, palette_size : Int32)
      @io.write_bytes(width.to_u16, IO::ByteFormat::LittleEndian)
      @io.write_bytes(height.to_u16, IO::ByteFormat::LittleEndian)

      # Calculate color table size bits
      color_table_size_bits = 0
      size = palette_size
      while size > 2
        color_table_size_bits += 1
        size >>= 1
      end

      # Packed field: global color table flag, color resolution, sort flag, size
      packed = 0x80_u8 | (7_u8 << 4) | color_table_size_bits.to_u8
      @io.write_byte(packed)

      @io.write_byte(0_u8) # Background color index
      @io.write_byte(0_u8) # Pixel aspect ratio
    end

    private def write_color_table(palette : Color::Palette)
      # Calculate actual table size (must be power of 2)
      table_size = 2
      while table_size < palette.size
        table_size <<= 1
      end

      # Write palette colors
      palette.size.times do |i|
        r, g, b, _ = palette[i].rgba
        @io.write_byte((r >> 8).to_u8)
        @io.write_byte((g >> 8).to_u8)
        @io.write_byte((b >> 8).to_u8)
      end

      # Pad with black if needed
      (table_size - palette.size).times do
        @io.write_byte(0_u8)
        @io.write_byte(0_u8)
        @io.write_byte(0_u8)
      end
    end

    private def write_graphic_control_extension(transparent_index : Int32)
      @io.write_byte(EXTENSION_INTRODUCER)
      @io.write_byte(GRAPHIC_CONTROL_LABEL)
      @io.write_byte(4_u8) # Block size

      # Packed field: disposal method, user input flag, transparency flag
      packed = 0x01_u8 # Transparency flag set
      @io.write_byte(packed)

      @io.write_bytes(0_u16, IO::ByteFormat::LittleEndian) # Delay time
      @io.write_byte(transparent_index.to_u8)              # Transparent color index
      @io.write_byte(BLOCK_TERMINATOR)
    end

    private def write_image_descriptor(width : Int32, height : Int32)
      @io.write_byte(IMAGE_SEPARATOR)
      @io.write_bytes(0_u16, IO::ByteFormat::LittleEndian) # Left position
      @io.write_bytes(0_u16, IO::ByteFormat::LittleEndian) # Top position
      @io.write_bytes(width.to_u16, IO::ByteFormat::LittleEndian)
      @io.write_bytes(height.to_u16, IO::ByteFormat::LittleEndian)

      # Packed field: no local color table, no interlace
      @io.write_byte(0_u8)
    end

    private def write_image_data(image : CrImage::Paletted, palette : Color::Palette)
      # Determine minimum code size based on palette size
      min_code_size = 2
      size = palette.size
      while size > (1 << min_code_size)
        min_code_size += 1
      end
      min_code_size = [min_code_size, 8].min

      @io.write_byte(min_code_size.to_u8)

      # Collect pixel indices
      bounds = image.bounds
      pixel_data = IO::Memory.new

      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          pixel_data.write_byte(image.color_index_at(x, y))
        end
      end

      # Compress using LZW
      compressed_bytes = LZW.compress(pixel_data.to_slice, min_code_size)

      # Write compressed data in blocks
      offset = 0
      while offset < compressed_bytes.size
        block_size = [compressed_bytes.size - offset, 255].min
        @io.write_byte(block_size.to_u8)
        @io.write(compressed_bytes[offset, block_size])
        offset += block_size
      end

      # Write block terminator
      @io.write_byte(BLOCK_TERMINATOR)
    end

    # Write animated GIF
    def self.write_animation(path : String, animation : Animation) : Nil
      File.open(path, "wb") do |file|
        write_animation(file, animation)
      end
    end

    def self.write_animation(io : IO, animation : Animation) : Nil
      return if animation.frames.empty?

      # Build global palette from all frames
      global_palette = build_global_palette(animation.frames)

      # Write header
      io.write(GIF_HEADER_89A)

      # Write logical screen descriptor
      write_logical_screen_descriptor_static(io, animation.width, animation.height, global_palette.size)

      # Write global color table
      write_color_table_static(io, global_palette)

      # Write NETSCAPE2.0 application extension for looping
      write_netscape_extension(io, animation.loop_count)

      # Write each frame
      animation.frames.each do |frame|
        write_frame(io, frame, global_palette)
      end

      # Write trailer
      io.write_byte(TRAILER)
    end

    private def self.build_global_palette(frames : Array(Frame)) : Color::Palette
      color_map = Hash(UInt32, Color::Color).new

      frames.each do |frame|
        bounds = frame.image.bounds
        bounds.min.y.upto(bounds.max.y - 1) do |y|
          bounds.min.x.upto(bounds.max.x - 1) do |x|
            color = frame.image.at(x, y)
            r, g, b, a = color.rgba
            key = (r.to_u32 << 24) | (g.to_u32 << 16) | (b.to_u32 << 8) | a.to_u32
            color_map[key] = color unless color_map.has_key?(key)
            break if color_map.size >= 256
          end
          break if color_map.size >= 256
        end
        break if color_map.size >= 256
      end

      colors = color_map.values.map do |c|
        r, g, b, a = c.rgba
        Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8).as(Color::Color)
      end
      Color::Palette.new(colors)
    end

    private def self.write_netscape_extension(io : IO, loop_count : Int32)
      io.write_byte(EXTENSION_INTRODUCER)
      io.write_byte(APPLICATION_EXTENSION)
      io.write_byte(11_u8) # Block size

      # Write "NETSCAPE2.0"
      io.write("NETSCAPE".to_slice)
      io.write("2.0".to_slice)

      # Write loop count sub-block
      io.write_byte(3_u8) # Sub-block size
      io.write_byte(1_u8) # Sub-block ID
      io.write_bytes(loop_count.to_u16, IO::ByteFormat::LittleEndian)

      io.write_byte(BLOCK_TERMINATOR)
    end

    private def self.write_frame(io : IO, frame : Frame, palette : Color::Palette)
      # Write graphic control extension
      io.write_byte(EXTENSION_INTRODUCER)
      io.write_byte(GRAPHIC_CONTROL_LABEL)
      io.write_byte(4_u8)

      # Packed field: disposal method, transparency flag
      disposal_bits = frame.disposal.value << 2
      transparent_flag = frame.transparent_index ? 0x01_u8 : 0x00_u8
      packed = disposal_bits.to_u8 | transparent_flag
      io.write_byte(packed)

      io.write_bytes(frame.delay.to_u16, IO::ByteFormat::LittleEndian)
      io.write_byte((frame.transparent_index || 0).to_u8)
      io.write_byte(BLOCK_TERMINATOR)

      # Convert frame image to paletted
      bounds = frame.image.bounds
      paletted = convert_to_paletted_with_palette(frame.image, palette)

      # Write image descriptor
      io.write_byte(IMAGE_SEPARATOR)
      io.write_bytes(0_u16, IO::ByteFormat::LittleEndian) # Left
      io.write_bytes(0_u16, IO::ByteFormat::LittleEndian) # Top
      io.write_bytes(bounds.width.to_u16, IO::ByteFormat::LittleEndian)
      io.write_bytes(bounds.height.to_u16, IO::ByteFormat::LittleEndian)
      io.write_byte(0_u8) # No local color table

      # Write image data
      write_image_data_static(io, paletted, palette)
    end

    private def self.convert_to_paletted_with_palette(image : CrImage::Image, palette : Color::Palette) : CrImage::Paletted
      bounds = image.bounds
      paletted = CrImage::Paletted.new(CrImage.rect(0, 0, bounds.width, bounds.height), palette)

      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          color = image.at(x, y)
          index = find_color_index_static(palette, color)
          paletted.set_color_index(x - bounds.min.x, y - bounds.min.y, index.to_u8)
        end
      end

      paletted
    end

    private def self.find_color_index_static(palette : Color::Palette, color : Color::Color) : Int32
      r1, g1, b1, _ = color.rgba
      best_index = 0
      best_distance = UInt64::MAX

      palette.size.times do |i|
        r2, g2, b2, _ = palette[i].rgba
        dr = r1.to_i64 - r2.to_i64
        dg = g1.to_i64 - g2.to_i64
        db = b1.to_i64 - b2.to_i64
        distance = (dr * dr + dg * dg + db * db).to_u64

        if distance < best_distance
          best_distance = distance
          best_index = i
        end
      end

      best_index
    end

    private def self.write_logical_screen_descriptor_static(io : IO, width : Int32, height : Int32, palette_size : Int32)
      io.write_bytes(width.to_u16, IO::ByteFormat::LittleEndian)
      io.write_bytes(height.to_u16, IO::ByteFormat::LittleEndian)

      color_table_size_bits = 0
      size = palette_size
      while size > 2
        color_table_size_bits += 1
        size >>= 1
      end

      packed = 0x80_u8 | (7_u8 << 4) | color_table_size_bits.to_u8
      io.write_byte(packed)
      io.write_byte(0_u8)
      io.write_byte(0_u8)
    end

    private def self.write_color_table_static(io : IO, palette : Color::Palette)
      table_size = 2
      while table_size < palette.size
        table_size <<= 1
      end

      palette.size.times do |i|
        r, g, b, _ = palette[i].rgba
        io.write_byte((r >> 8).to_u8)
        io.write_byte((g >> 8).to_u8)
        io.write_byte((b >> 8).to_u8)
      end

      (table_size - palette.size).times do
        io.write_byte(0_u8)
        io.write_byte(0_u8)
        io.write_byte(0_u8)
      end
    end

    private def self.write_image_data_static(io : IO, image : CrImage::Paletted, palette : Color::Palette)
      min_code_size = 2
      size = palette.size
      while size > (1 << min_code_size)
        min_code_size += 1
      end
      min_code_size = [min_code_size, 8].min

      io.write_byte(min_code_size.to_u8)

      bounds = image.bounds
      pixel_data = IO::Memory.new

      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          pixel_data.write_byte(image.color_index_at(x, y))
        end
      end

      compressed_bytes = LZW.compress(pixel_data.to_slice, min_code_size)

      offset = 0
      while offset < compressed_bytes.size
        block_size = [compressed_bytes.size - offset, 255].min
        io.write_byte(block_size.to_u8)
        io.write(compressed_bytes[offset, block_size])
        offset += block_size
      end

      io.write_byte(BLOCK_TERMINATOR)
    end
  end
end
