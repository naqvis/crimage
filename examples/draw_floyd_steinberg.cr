require "math"
require "../src/crimage"

# Example: Floyd-Steinberg Dithering
#
# Demonstrates error diffusion dithering to convert a grayscale gradient
# into a limited palette (5 shades) while preserving visual quality.
#
# Floyd-Steinberg dithering distributes quantization error to neighboring
# pixels, creating the illusion of more colors than actually present.
#
# Usage:
#   crystal run examples/draw_floyd_steinberg.cr
#
# Output: ASCII art representation of dithered gradient

width = 130
height = 50

# Create a grayscale image with radial gradient
im = CrImage::Gray.new(CrImage::Rectangle.new(max: CrImage::Point.new(width, height),
  min: CrImage::Point.zero))

# Fill with radial gradient (ellipse from center)
0.upto(width - 1) do |x|
  0.upto(height - 1) do |y|
    # Calculate distance from center (elliptical)
    dist = Math.sqrt(((x - width/2) ** 2) / 3 + (y - height/2) ** 2) / (height / 1.5) * 255
    gray = dist > 255 ? 255_u8 : dist.to_u8!
    im.set_gray(x, y, CrImage::Color::Gray.new(255 - gray))
  end
end

# Create paletted image with only 5 gray levels
pi = CrImage::Paletted.new(im.bounds, CrImage::Color::Palette.new([
  CrImage::Color::Gray.new(255).as(CrImage::Color::Color), # White
  CrImage::Color::Gray.new(160).as(CrImage::Color::Color), # Light gray
  CrImage::Color::Gray.new(70).as(CrImage::Color::Color),  # Medium gray
  CrImage::Color::Gray.new(35).as(CrImage::Color::Color),  # Dark gray
  CrImage::Color::Gray.new(0).as(CrImage::Color::Color),   # Black
]))

# Apply Floyd-Steinberg dithering
# This converts the smooth gradient to 5 colors while maintaining visual quality
CrImage::Draw::FloydSteinberg.draw(pi, im.bounds, im, CrImage::Point.zero)

# Render as ASCII art using Unicode block characters
shade = [" ", "░", "▒", "▓", "█"]
output = String.build do |sb|
  pi.pix.each_with_index do |p, i|
    sb << shade[p]
    sb << "\n" if (i + 1) % width == 0
  end
end

puts "\nFloyd-Steinberg Dithering Demo"
puts "=" * 50
puts "Original: Smooth gradient (256 gray levels)"
puts "Dithered: 5 gray levels with error diffusion"
puts "=" * 50
puts output
puts "\nNotice how dithering creates the illusion of smooth gradients"
puts "using only 5 distinct shades!"
