require "io"

# WEBP module implements a decoder and encoder for WEBP images.
# The WEBP specification is at:
# https://developers.google.com/speed/webp/docs/riff_container
#
# ## Reading WebP Images
#
# ```
# # Read from file
# image = CrImage::WEBP.read("image.webp")
#
# # Read from IO
# File.open("image.webp", "rb") do |file|
#   image = CrImage::WEBP.read(file)
# end
#
# # Read configuration only (dimensions, color model)
# config = CrImage::WEBP.read_config("image.webp")
# ```
#
# ## Writing WebP Images
#
# ```
# # Write to file (lossless VP8L format)
# CrImage::WEBP.write("output.webp", image)
#
# # Write to IO
# File.open("output.webp", "wb") do |file|
#   CrImage::WEBP.write(file, image)
# end
#
# # Write with extended format (VP8X container)
# options = CrImage::WEBP::Options.new(use_extended_format: true)
# CrImage::WEBP.write("output.webp", image, options)
# ```
module CrImage::WEBP
  extend CrImage::ImageReader

  WEBP_HEADER = "RIFF".to_slice

  class FormatError < CrImage::FormatError
  end

  # read and decode the entire image
  def self.read(path : String) : CrImage::Image
    File.open(path, "rb") do |file|
      read(file)
    end
  end

  def self.read(io : IO) : CrImage::Image
    Decoder.decode(io)
  end

  # read and decode the configurations like color model, dimensions
  def self.read_config(path : String) : CrImage::Config
    File.open(path, "rb") do |file|
      read_config(file)
    end
  end

  def self.read_config(io : IO) : CrImage::Config
    Decoder.decode_config(io)
  end

  # write the Image to file in WebP lossless format
  def self.write(path : String, image : CrImage::Image, options : Options? = nil) : Nil
    Encoder.write(path, image, options)
  end

  # write the Image to IO in WebP lossless format
  def self.write(io : IO, image : CrImage::Image, options : Options? = nil) : Nil
    Encoder.write(io, image, options)
  end
end

CrImage.register_format("webp", "RIFF????WEBPVP8".to_slice, CrImage::WEBP)

require "./*"
