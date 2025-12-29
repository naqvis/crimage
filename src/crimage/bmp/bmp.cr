require "../image"

# BMP module implements a BMP (Windows Bitmap) image decoder and encoder.
#
# Supports:
# - 8-bit paletted images (256 colors)
# - 24-bit RGB images (true color)
# - 32-bit RGBA images (true color with alpha)
# - Top-down and bottom-up orientation
# - Uncompressed images only
#
# Specification: http://www.digicamsoft.com/bmp/bmp.html
#
# Example:
# ```
# # Read BMP image
# img = CrImage::BMP.read("photo.bmp")
#
# # Write BMP image
# CrImage::BMP.write("output.bmp", img)
#
# # Read only metadata (fast)
# config = CrImage::BMP.read_config("photo.bmp")
# puts "#{config.width}x#{config.height}"
# ```
module CrImage::BMP
  extend CrImage::ImageReader

  # Raised when BMP format is invalid or unsupported.
  class FormatError < CrImage::FormatError
    def initialize
      super("Unsupported BMP image")
    end

    def initialize(message)
      super(message)
    end
  end

  # Reads and decodes a BMP image from a file.
  #
  # Parameters:
  # - `path` : Path to the BMP file
  #
  # Returns: Decoded image (RGBA, NRGBA, or Paletted depending on bit depth)
  #
  # Raises: `FormatError` if the file is not a valid BMP or uses unsupported features
  #
  # Example:
  # ```
  # img = CrImage::BMP.read("photo.bmp")
  # ```
  def self.read(path : String) : CrImage::Image
    Reader.read(path)
  end

  # Reads and decodes a BMP image from an IO stream.
  #
  # Parameters:
  # - `io` : IO stream containing BMP data
  #
  # Returns: Decoded image
  #
  # Example:
  # ```
  # File.open("photo.bmp") do |file|
  #   img = CrImage::BMP.read(file)
  # end
  # ```
  def self.read(io : IO) : CrImage::Image
    Reader.read(io)
  end

  # Reads BMP image metadata without decoding pixel data.
  #
  # This is much faster than `read` when you only need dimensions and color model.
  #
  # Parameters:
  # - `path` : Path to the BMP file
  #
  # Returns: Config with width, height, and color model
  #
  # Example:
  # ```
  # config = CrImage::BMP.read_config("photo.bmp")
  # puts "Size: #{config.width}x#{config.height}"
  # puts "Bit depth: #{config.color_model.name}"
  # ```
  def self.read_config(path : String) : CrImage::Config
    Reader.read_config(path)
  end

  # Reads BMP image metadata from an IO stream without decoding pixel data.
  #
  # Parameters:
  # - `io` : IO stream containing BMP data
  #
  # Returns: Config with width, height, and color model
  def self.read_config(io : IO) : CrImage::Config
    Reader.read_config(io)
  end

  # Writes an image to a file in BMP format.
  #
  # Automatically selects the optimal bit depth:
  # - 8-bit for Gray and Paletted images
  # - 24-bit for opaque RGB images
  # - 32-bit for images with transparency
  #
  # Parameters:
  # - `path` : Output file path
  # - `image` : Image to encode
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # CrImage::BMP.write("output.bmp", img)
  # ```
  def self.write(path : String, image : CrImage::Image) : Nil
    Writer.write(path, image)
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
  #   CrImage::BMP.write(file, img)
  # end
  # ```
  def self.write(io : IO, image : CrImage::Image) : Nil
    Writer.write(io, image)
  end
end

CrImage.register_format("bmp", "BM????\x00\x00\x00\x00".to_slice, CrImage::BMP)
