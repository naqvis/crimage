require "../src/crimage"

# Image Identify Tool
# this tool analyzes image files and displays detailed information including format-specific details

class ImageIdentifier
  def self.identify(path : String)
    puts "Analyzing: #{path}"
    puts "-" * 60

    unless File.exists?(path)
      puts "Error: File not found"
      return
    end

    file_size = File.size(path)
    puts "File size: #{format_bytes(file_size)}"

    begin
      # Detect format
      format = detect_format(path)
      puts "Format: #{format}"

      # Get format-specific details
      format_details = get_format_details(path, format)
      puts "Details: #{format_details}" unless format_details.empty?

      # Read config to get dimensions
      config = CrImage.read_config(path)

      puts "Dimensions: #{config.width}x#{config.height}"
      puts "Color Model: #{color_model_name(config.color_model)}"

      # Read full image to get more details
      img = CrImage.read(path)

      case img
      when CrImage::Gray
        puts "Type: Grayscale"
        puts "Channels: 1"
        puts "Bit Depth: 8-bit"
      when CrImage::RGBA
        puts "Type: RGB with Alpha"
        puts "Channels: 4 (RGBA)"
        puts "Bit Depth: 8-bit per channel"
      when CrImage::NRGBA
        puts "Type: Non-premultiplied RGB with Alpha"
        puts "Channels: 4 (NRGBA)"
        puts "Bit Depth: 8-bit per channel"
      when CrImage::YCbCr
        puts "Type: YCbCr"
        puts "Channels: 3"
        puts "Bit Depth: 8-bit per channel"
      else
        puts "Type: #{img.class}"
      end

      puts "Pixels: #{format_number(config.width * config.height)}"

      # Calculate approximate memory usage
      memory = calculate_memory(img)
      puts "Memory: #{format_bytes(memory)}"
    rescue ex : CrImage::FormatError
      puts "Error: #{ex.message}"
    rescue ex
      puts "Error: #{ex.message}"
    end

    puts "-" * 60
  end

  # Detect image format by reading magic bytes
  private def self.detect_format(path : String) : String
    File.open(path, "r") do |file|
      # Read first few bytes to detect format
      magic = Bytes.new(16)
      bytes_read = file.read(magic)
      return "Unknown" if bytes_read == 0

      # JPEG
      if magic[0] == 0xFF && magic[1] == 0xD8
        return "JPEG"
      end

      # PNG
      if magic[0] == 0x89 && magic[1] == 0x50 && magic[2] == 0x4E && magic[3] == 0x47
        return "PNG"
      end

      # GIF
      if magic[0] == 0x47 && magic[1] == 0x49 && magic[2] == 0x46
        return "GIF"
      end

      # BMP
      if magic[0] == 0x42 && magic[1] == 0x4D
        return "BMP"
      end

      # WebP
      if magic[0] == 0x52 && magic[1] == 0x49 && magic[2] == 0x46 && magic[3] == 0x46 &&
         magic[8] == 0x57 && magic[9] == 0x45 && magic[10] == 0x42 && magic[11] == 0x50
        return "WebP"
      end

      # TIFF (little-endian)
      if magic[0] == 0x49 && magic[1] == 0x49 && magic[2] == 0x2A && magic[3] == 0x00
        return "TIFF"
      end

      # TIFF (big-endian)
      if magic[0] == 0x4D && magic[1] == 0x4D && magic[2] == 0x00 && magic[3] == 0x2A
        return "TIFF"
      end

      # ICO
      if magic[0] == 0x00 && magic[1] == 0x00 && magic[2] == 0x01 && magic[3] == 0x00
        return "ICO"
      end

      "Unknown"
    end
  rescue
    "Unknown"
  end

  # Get format-specific details
  private def self.get_format_details(path : String, format : String) : String
    case format
    when "JPEG"
      jpeg_type = detect_jpeg_type(path)
      jpeg_type
    when "GIF"
      gif_details = detect_gif_details(path)
      gif_details
    when "PNG"
      png_details = detect_png_details(path)
      png_details
    else
      ""
    end
  end

  # Detect JPEG type (baseline or progressive)
  private def self.detect_jpeg_type(path : String) : String
    File.open(path, "r") do |file|
      # Read SOI marker
      marker1 = file.read_byte
      marker2 = file.read_byte

      return "Invalid JPEG" if marker1.nil? || marker2.nil?
      return "Invalid JPEG" if marker1 != 0xFF || marker2 != 0xD8

      # Scan for SOF markers
      loop do
        # Find next marker
        loop do
          byte = file.read_byte
          return "Unknown JPEG type" if byte.nil?

          if byte == 0xFF
            marker = file.read_byte
            return "Unknown JPEG type" if marker.nil?

            # Skip padding 0xFF bytes
            next if marker == 0xFF

            # Check for SOF markers
            case marker
            when 0xC0
              return "Baseline DCT"
            when 0xC1
              return "Extended Sequential DCT"
            when 0xC2
              return "Progressive DCT"
            when 0xC3
              return "Lossless (Sequential)"
            when 0xD9 # EOI
              return "Unknown JPEG type"
            when 0x00 # Not a marker
              next
            else
              # Read and skip segment
              len_high = file.read_byte
              len_low = file.read_byte
              return "Unknown JPEG type" if len_high.nil? || len_low.nil?

              length = (len_high.to_u16 << 8) | len_low.to_u16
              return "Unknown JPEG type" if length < 2

              file.skip(length - 2) if length > 2
            end
          end
        end
      end
    end
  rescue
    "Unknown JPEG type"
  end

  # Detect GIF details (version and animation)
  private def self.detect_gif_details(path : String) : String
    File.open(path, "r") do |file|
      header = Bytes.new(13)
      bytes_read = file.read(header)
      return "" if bytes_read < 13

      # GIF version
      version = String.new(header[0, 6])

      # Check for animation (look for multiple image descriptors)
      # This is a simplified check - just look for Graphic Control Extension
      file.seek(13)
      has_animation = false
      image_count = 0

      loop do
        byte = file.read_byte
        break if byte.nil?

        if byte == 0x21 # Extension
          ext_type = file.read_byte
          break if ext_type.nil?

          # Skip extension data
          loop do
            block_size = file.read_byte
            break if block_size.nil? || block_size == 0
            file.skip(block_size)
          end
        elsif byte == 0x2C # Image descriptor
          image_count += 1
          has_animation = true if image_count > 1
          break if has_animation

          # Skip image descriptor and image data
          file.skip(9) # Image descriptor

          # Skip color table if present
          packed = file.read_byte
          break if packed.nil?

          if (packed & 0x80) != 0
            color_table_size = 2 ** ((packed & 0x07) + 1)
            file.skip(color_table_size * 3)
          end

          # Skip LZW data
          file.skip(1) # LZW minimum code size
          loop do
            block_size = file.read_byte
            break if block_size.nil? || block_size == 0
            file.skip(block_size)
          end
        elsif byte == 0x3B # Trailer
          break
        end
      end

      details = version
      details += ", Animated (#{image_count} frames)" if has_animation
      details
    end
  rescue
    ""
  end

  # Detect PNG details
  private def self.detect_png_details(path : String) : String
    File.open(path, "r") do |file|
      # Skip PNG signature
      file.skip(8)

      # Read IHDR chunk
      length_bytes = Bytes.new(4)
      file.read(length_bytes)

      chunk_type = Bytes.new(4)
      file.read(chunk_type)

      return "" unless String.new(chunk_type) == "IHDR"

      ihdr_data = Bytes.new(13)
      file.read(ihdr_data)

      bit_depth = ihdr_data[8]
      color_type = ihdr_data[9]
      interlace = ihdr_data[12]

      details = "#{bit_depth}-bit"

      case color_type
      when 0
        details += ", Grayscale"
      when 2
        details += ", RGB"
      when 3
        details += ", Indexed"
      when 4
        details += ", Grayscale with Alpha"
      when 6
        details += ", RGB with Alpha"
      end

      details += ", Interlaced" if interlace == 1

      details
    end
  rescue
    ""
  end

  private def self.color_model_name(model) : String
    case model.to_s
    when /rgba/i
      "RGBA"
    when /nrgba/i
      "NRGBA"
    when /gray/i
      "Grayscale"
    when /ycbcr/i
      "YCbCr"
    when /cmyk/i
      "CMYK"
    else
      model.to_s
    end
  end

  private def self.calculate_memory(img : CrImage::Image) : Int64
    case img
    when CrImage::Gray
      img.pix.size.to_i64
    when CrImage::RGBA, CrImage::NRGBA
      img.pix.size.to_i64
    when CrImage::YCbCr
      img.y.size.to_i64 + img.cb.size.to_i64 + img.cr.size.to_i64
    else
      0_i64
    end
  end

  private def self.format_bytes(bytes : Int64) : String
    return "#{bytes} bytes" if bytes < 1024

    kb = bytes / 1024.0
    return "#{kb.round(2)} KB" if kb < 1024

    mb = kb / 1024.0
    return "#{mb.round(2)} MB" if mb < 1024

    gb = mb / 1024.0
    "#{gb.round(2)} GB"
  end

  private def self.format_number(num : Int32) : String
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
  end
end

# Main program
if ARGV.empty?
  puts "Image Identify Tool"
  puts ""
  puts "Usage: crystal run examples/image_identify.cr <image_file> [<image_file2> ...]"
  puts ""
  puts "Supported formats: JPEG, PNG, GIF, BMP, WebP, TIFF, ICO"
  puts ""
  puts "Examples:"
  puts "  crystal run examples/image_identify.cr spec/testdata/test-gradient.jpeg"
  puts "  crystal run examples/image_identify.cr spec/testdata/*.jpeg"
  puts "  crystal run examples/image_identify.cr spec/testdata/*.png"
  exit 1
end

ARGV.each_with_index do |path, index|
  puts "" if index > 0
  ImageIdentifier.identify(path)
end
