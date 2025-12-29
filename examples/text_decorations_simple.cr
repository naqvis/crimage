require "../src/crimage"
require "../src/freetype"

# Simple Text Decorations Demo
puts "Simple Text Decorations Demo"
puts "=" * 60

# Check for font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"

unless File.exists?(font_path)
  puts "Font not found at #{font_path}"
  puts "Please install fonts. See fonts/README.md"
  exit 1
end

# Load font
ttf = FreeType::TrueType.load(font_path)
face = FreeType::TrueType::Face.new(ttf, 48.0)

# Create image with white background
img = CrImage.rgba(800, 400, CrImage::Color::WHITE)

# Create drawer with black text
black = CrImage::Uniform.new(CrImage::Color::BLACK)
drawer = CrImage::Font::Drawer.new(img, black, face)

# Simple API - one method, named parameters!
drawer.draw_text("Normal Text", 50, 100)
drawer.draw_text("Underlined Text", 50, 180, underline: true)
drawer.draw_text("Strikethrough Text", 50, 260, strikethrough: true)

# With custom color
red = CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
drawer.draw_text("Red Underline", 50, 340, underline: true, decoration_color: red)

# Save output
CrImage::PNG.write("text_decorations_simple.png", img)

puts "Saved: text_decorations_simple.png"
