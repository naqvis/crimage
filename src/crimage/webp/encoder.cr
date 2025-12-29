require "./writer"
require "./riff"
require "../image"
require "../image/nrgba"

module CrImage::WEBP
  # Encoding options for WebP encoder.
  #
  # Configures WebP encoding behavior and output format.
  #
  # Properties:
  # - `use_extended_format` : Whether to use VP8X extended format (default: false)
  #
  # The extended format (VP8X) provides additional metadata and features like
  # alpha channel flags, but adds overhead. Simple VP8L format is sufficient
  # for most lossless images.
  struct Options
    property use_extended_format : Bool

    def initialize(@use_extended_format = false)
    end
  end

  # Encoder handles WebP image encoding.
  #
  # Provides methods for encoding images to WebP lossless format (VP8L).
  # Handles image conversion, bitstream generation, and RIFF container creation.
  module Encoder
    # Encodes image to file path.
    #
    # Writes the image to a WebP file using lossless VP8L compression.
    #
    # Parameters:
    # - `path` : Output file path
    # - `img` : Image to encode (must not be nil)
    # - `options` : Optional encoding options
    #
    # Raises:
    # - `ArgumentError` if image is nil or dimensions are invalid
    # - `IO::Error` if file write fails
    #
    # Example:
    # ```
    # img = CrImage.read("photo.png")
    # CrImage::WEBP::Encoder.write("output.webp", img)
    # ```
    def self.write(path : String, img : CrImage::Image?, options : Options? = nil) : Nil
      raise ArgumentError.new("Image cannot be nil") if img.nil?

      File.open(path, "wb") do |file|
        write(file, img, options)
      end
    rescue ex : IO::Error
      raise IO::Error.new("Failed to write WebP data to file: #{ex.message}")
    end

    # Encodes image to IO stream.
    #
    # Writes the image to an IO stream in WebP lossless format.
    # Performs validation, format conversion, and bitstream generation.
    #
    # Parameters:
    # - `io` : Output IO stream
    # - `img` : Image to encode (must not be nil)
    # - `options` : Optional encoding options
    #
    # Raises:
    # - `ArgumentError` if image is nil or dimensions invalid (1-16384 pixels)
    # - `IO::Error` if stream write fails
    # - `OverflowError` if arithmetic overflow occurs during encoding
    #
    # Example:
    # ```
    # File.open("output.webp", "wb") do |file|
    #   CrImage::WEBP::Encoder.write(file, img)
    # end
    # ```
    def self.write(io : IO, img : CrImage::Image?, options : Options? = nil) : Nil
      raise ArgumentError.new("Image cannot be nil") if img.nil?

      # Validate image dimensions
      validate_dimensions(img)

      # Convert image to NRGBA format
      nrgba_img = convert_to_nrgba(img)

      # Generate VP8L bitstream
      bitstream_data, has_alpha = Writer.write_bitstream(nrgba_img)

      # Get options or use defaults
      opts = options || Options.new

      # Build and write RIFF container
      write_riff_container(io, bitstream_data, nrgba_img, has_alpha, opts)
    rescue ex : ArgumentError
      raise ex
    rescue ex : IO::Error
      raise IO::Error.new("Failed to write WebP data to stream: #{ex.message}")
    rescue ex : OverflowError
      raise IO::Error.new("Arithmetic overflow during WebP encoding: #{ex.message}\n#{ex.backtrace.join("\n")}")
    rescue ex
      raise IO::Error.new("Failed to encode WebP: #{ex.class}: #{ex.message}\n#{ex.backtrace.join("\n")}")
    end

    # Validates image dimensions are within WebP limits.
    #
    # WebP supports images from 1x1 to 16384x16384 pixels.
    private def self.validate_dimensions(img : CrImage::Image) : Nil
      width = img.bounds.width
      height = img.bounds.height

      if width < 1 || height < 1
        raise ArgumentError.new("Image must have at least 1 pixel")
      end

      if width > 16384 || height > 16384
        raise ArgumentError.new("Image dimensions must be between 1 and 16384 pixels, got #{width}x#{height}")
      end
    end

    # Converts image to NRGBA format for encoding.
    #
    # VP8L encoder requires NRGBA format. If image is already NRGBA,
    # returns it directly. Otherwise, creates a new NRGBA image and
    # copies pixels with color model conversion.
    private def self.convert_to_nrgba(img : CrImage::Image) : CrImage::NRGBA
      # If already NRGBA, return as-is
      return img if img.is_a?(CrImage::NRGBA)

      # Create new NRGBA image
      bounds = img.bounds
      nrgba = CrImage::NRGBA.new(bounds)

      # Copy pixels
      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          color = img.at(x, y)
          nrgba_color = CrImage::Color.nrgba_model.convert(color).as(CrImage::Color::NRGBA)
          nrgba.set_nrgba(x, y, nrgba_color)
        end
      end

      nrgba
    end

    # Writes RIFF container with WebP data.
    #
    # Constructs the RIFF/WEBP container structure with optional VP8X
    # extended format chunk and VP8L lossless data chunk.
    private def self.write_riff_container(io : IO, bitstream_data : Bytes, img : CrImage::NRGBA, has_alpha : Bool, options : Options) : Nil
      # Calculate sizes
      # VP8L chunk: 4 (fourcc) + 4 (size) + data
      vp8l_data_size = bitstream_data.size
      vp8l_chunk_size = 8 + vp8l_data_size

      # VP8X chunk: 4 (fourcc) + 4 (size) + 10 (data)
      vp8x_chunk_size = options.use_extended_format ? 18 : 0

      # Total RIFF size: 4 (WEBP) + chunks
      riff_size = 4 + vp8x_chunk_size + vp8l_chunk_size

      # Write RIFF header
      io.write("RIFF".to_slice)
      write_u32_le(io, riff_size.to_u32)
      io.write("WEBP".to_slice)

      # Write VP8X chunk if extended format is enabled
      if options.use_extended_format
        write_vp8x_chunk(io, img, has_alpha)
      end

      # Write VP8L chunk
      write_vp8l_chunk(io, bitstream_data)
    end

    # Writes VP8X extended format chunk.
    #
    # The VP8X chunk provides metadata including alpha channel flag
    # and canvas dimensions. Required for extended WebP features.
    private def self.write_vp8x_chunk(io : IO, img : CrImage::NRGBA, has_alpha : Bool) : Nil
      io.write("VP8X".to_slice)
      write_u32_le(io, 10_u32) # Chunk data size

      # Flags byte
      flags = 0_u8
      flags |= 0x10 if has_alpha # Alpha flag

      io.write_byte(flags)

      # Reserved bytes (3 bytes)
      io.write_byte(0_u8)
      io.write_byte(0_u8)
      io.write_byte(0_u8)

      # Canvas width minus one (24 bits, little-endian)
      width = img.bounds.width - 1
      io.write_byte((width & 0xFF).to_u8)
      io.write_byte(((width >> 8) & 0xFF).to_u8)
      io.write_byte(((width >> 16) & 0xFF).to_u8)

      # Canvas height minus one (24 bits, little-endian)
      height = img.bounds.height - 1
      io.write_byte((height & 0xFF).to_u8)
      io.write_byte(((height >> 8) & 0xFF).to_u8)
      io.write_byte(((height >> 16) & 0xFF).to_u8)
    end

    # Writes VP8L lossless chunk.
    #
    # Contains the compressed VP8L bitstream data.
    private def self.write_vp8l_chunk(io : IO, bitstream_data : Bytes) : Nil
      io.write("VP8L".to_slice)
      write_u32_le(io, bitstream_data.size.to_u32)
      io.write(bitstream_data)
    end

    # Writes 32-bit unsigned integer in little-endian format.
    #
    # WebP uses little-endian byte order for all multi-byte values.
    private def self.write_u32_le(io : IO, value : UInt32) : Nil
      io.write_byte((value & 0xFF).to_u8)
      io.write_byte(((value >> 8) & 0xFF).to_u8)
      io.write_byte(((value >> 16) & 0xFF).to_u8)
      io.write_byte(((value >> 24) & 0xFF).to_u8)
    end
  end
end
