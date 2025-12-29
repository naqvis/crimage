require "../src/crimage"
require "../src/freetype"

# Kerning Demo
# Demonstrates proper kerning (spacing adjustment between character pairs)

puts "Kerning Demo"
puts "=" * 50

# Check for font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"

unless File.exists?(font_path)
  puts "Font not found at #{font_path}"
  puts "Please install fonts. See fonts/README.md"
  exit 1
end

# Load font
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 72.0)

puts "Font loaded: #{font_path}"
puts ""

# Test common kerning pairs
test_pairs = [
  {'A', 'V'}, # Classic kerning pair
  {'T', 'o'}, # Another common pair
  {'W', 'A'}, # Wide letter + narrow letter
  {'V', 'A'}, # Similar to AV
  {'f', 'i'}, # Often becomes ligature
  {'A', 'B'}, # Usually no kerning
]

puts "Kerning Values (in font units):"
puts "-" * 50

has_any_kerning = false
test_pairs.each do |(char1, char2)|
  glyph1 = font.glyph_index(char1)
  glyph2 = font.glyph_index(char2)

  if glyph1 > 0 && glyph2 > 0
    kern_value = font.lookup_kern(glyph1, glyph2)

    if kern_value != 0
      puts "  #{char1}#{char2}: #{kern_value} (tighter spacing)"
      has_any_kerning = true
    else
      puts "  #{char1}#{char2}: #{kern_value} (no kerning)"
    end
  end
end

unless has_any_kerning
  puts ""
  puts "⚠ This font has no kern table data."
  puts "Modern fonts like Roboto use GPOS (OpenType) for kerning."
  puts ""
  puts "To see kerning in action, try fonts with legacy kern tables:"
  puts "  - Times New Roman"
  puts "  - Arial"
  puts "  - Georgia"
  puts "  - Liberation fonts (free)"
  puts "  - DejaVu fonts (free)"
end

puts ""
puts "Creating visual comparison..."
puts ""

# Create image with white background
width, height = 800, 400
img = CrImage.rgba(width, height, CrImage::Color::WHITE)

# Black text
text_color = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))

# Text to demonstrate kerning
demo_text = "WAVE Type AV To"

# Draw text WITH kerning (top)
puts "Drawing with kerning (top)..."
dot_with_kern = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[120 * 64]
)
drawer_with = CrImage::Font::Drawer.new(img, text_color, face, dot_with_kern)
drawer_with.draw(demo_text)

# Draw text WITHOUT kerning (bottom) - manually position each character
puts "Drawing without kerning (bottom)..."
dot_without_kern = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[280 * 64]
)

# Manually draw each character without kerning
current_x = dot_without_kern.x
demo_text.each_char do |char|
  glyph_index = font.glyph_index(char)
  next if glyph_index == 0

  # Get advance width (no kerning)
  advance_width, _ = font.h_metrics(glyph_index)

  # Draw character
  char_dot = CrImage::Math::Fixed::Point26_6.new(current_x, dot_without_kern.y)
  char_drawer = CrImage::Font::Drawer.new(img, text_color, face, char_dot)
  char_drawer.draw(char.to_s)

  # Advance by full width (no kerning adjustment)
  scale = face.scale
  current_x += (scale * advance_width) // 64
end

# Add labels
label_face = FreeType::TrueType.new_face(font, 24.0)

label1_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[70 * 64]
)
label1_drawer = CrImage::Font::Drawer.new(img, text_color, label_face, label1_dot)
label1_drawer.draw("With Kerning (proper spacing):")

label2_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[230 * 64]
)
label2_drawer = CrImage::Font::Drawer.new(img, text_color, label_face, label2_dot)
label2_drawer.draw("Without Kerning (uniform spacing):")

# Save output
output_path = "kerning_demo.png"
CrImage::PNG.write(output_path, img)

puts "✓ Saved to #{output_path}"
puts ""
puts "Notice the difference:"
puts "  - 'AV' and 'WA' are tighter with kerning"
puts "  - 'To' has better spacing with kerning"
puts "  - Overall text looks more professional with kerning"
