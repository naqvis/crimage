require "../src/crimage"
require "../src/freetype"

# This example demonstrates multi-line text rendering with word wrapping
#
# Usage:
#   crystal run examples/multiline_text_demo.cr

# Configuration
output_file = "multiline_text_demo.png"
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
font_size = 24.0
width = 600
height = 400

unless File.exists?(font_path)
  puts "Error: Font file not found: #{font_path}"
  puts ""
  puts "Please download a font. Quick options:"
  puts "  1. Download Roboto from https://fonts.google.com/specimen/Roboto"
  puts "  2. Extract Roboto-Regular.ttf to fonts/Roboto/static/"
  puts "  3. Or use a system font by modifying font_path in this file"
  exit 1
end

# Load TrueType font
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, font_size)

# Create image with white background
image = CrImage.rgba(width, height, CrImage::Color::WHITE)

# Text color (black)
txt_color = CrImage::Uniform.new(CrImage::Color::BLACK)

# Example 1: Multi-line text with explicit newlines
puts "Example 1: Multi-line text with explicit newlines"
dot1 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[20 * 64],
  CrImage::Math::Fixed::Int26_6[50 * 64]
)
drawer1 = CrImage::Font::Drawer.new(image, txt_color, face, dot1)
text1 = "Multi-line Text Demo\nLine 2\nLine 3"
drawer1.draw_multiline(text1)

# Example 2: Word wrapping
puts "Example 2: Word wrapping with max width"
dot2 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[20 * 64],
  CrImage::Math::Fixed::Int26_6[150 * 64]
)
drawer2 = CrImage::Font::Drawer.new(image, txt_color, face, dot2)
text2 = "This is a longer text that will be wrapped at word boundaries when it exceeds the maximum width specified."
max_width = 400
drawer2.draw_multiline(text2, max_width)

# Example 3: Custom line spacing
puts "Example 3: Custom line spacing"
dot3 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[20 * 64],
  CrImage::Math::Fixed::Int26_6[280 * 64]
)
drawer3 = CrImage::Font::Drawer.new(image, txt_color, face, dot3)
text3 = "Line spacing 1.5\nSecond line\nThird line"
drawer3.draw_multiline(text3, nil, 1.5)

# Save image
CrImage::PNG.write(output_file, image)

puts ""
puts "Created #{output_file}"
puts "  Size: #{width}x#{height}"
puts "  Font: #{File.basename(font_path)} @ #{font_size}pt"
