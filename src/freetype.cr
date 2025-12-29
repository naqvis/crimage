# FreeType module for TrueType font rendering
#
# This module provides TrueType font parsing and rendering capabilities
# for the CrImage library. It implements the CrImage::Font::Face interface
# to enable text drawing on images.
#
# ## Usage
#
# ```
# require "crimage"
# require "freetype"
#
# # Load a TrueType font
# font = FreeType::TrueType.load("path/to/font.ttf")
# face = FreeType::TrueType.new_face(font, 24.0) # 24pt font
#
# # Create an image
# image = CrImage::RGBA.new(CrImage.rect(0, 0, 400, 100))
#
# # Draw text
# text_color = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
# dot = CrImage::Math::Fixed::Point26_6.new(
#   CrImage::Math::Fixed::Int26_6[10 * 64],
#   CrImage::Math::Fixed::Int26_6[50 * 64]
# )
# drawer = CrImage::Font::Drawer.new(image, text_color, face, dot)
# drawer.draw("Hello, World!")
#
# # Save the image
# CrImage::PNG.write("output.png", image)
# ```
module FreeType
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
end

require "./freetype/**"
