require "../src/crimage"
require "../src/freetype"

# Demonstrate font features including kerning and glyph handling

puts "Font Features Demo"
puts "=" * 50

# Check if font exists
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
unless File.exists?(font_path)
  puts "Error: Font not found at #{font_path}"
  puts "Please download Roboto font from Google Fonts"
  puts "See fonts/README.md for instructions"
  exit 1
end

# Load font
font = FreeType::TrueType.load(font_path)

# 1. Font metrics
puts "\n1. Font Metrics"
puts "-" * 40

face = FreeType::TrueType.new_face(font, 48.0)
metrics = face.metrics

puts "Font size: 48pt"
puts "Ascent:  #{metrics.ascent.floor}px (above baseline)"
puts "Descent: #{metrics.descent.floor}px (below baseline)"
puts "Height:  #{metrics.height.floor}px (line height)"

# 2. Glyph metrics
puts "\n2. Glyph Metrics"
puts "-" * 40

test_chars = ['A', 'W', 'i', 'l']
test_chars.each do |char|
  advance, ok = face.glyph_advance(char)
  if ok
    puts "Char '#{char}': advance = #{advance.floor}px"
  end
end

# 3. Kerning - adjusts spacing between specific character pairs
puts "\n3. Kerning"
puts "-" * 40

kerning_pairs = [
  {'A', 'V'},
  {'T', 'o'},
  {'W', 'A'},
  {'V', 'A'},
  {'f', 'i'},
  {'Y', 'o'},
]

puts "Kerning adjustments (horizontal spacing between character pairs):"
kerning_pairs.each do |pair|
  kern = face.kern(pair[0], pair[1])
  kern_px = (kern.to_i / 64.0).round(2)
  if kern.to_i != 0
    direction = kern.to_i < 0 ? "closer" : "farther"
    puts "  '#{pair[0]}#{pair[1]}': #{kern_px}px (#{direction})"
  else
    puts "  '#{pair[0]}#{pair[1]}': #{kern_px}px (no adjustment)"
  end
end
puts "Note: Kerning values depend on the font's kern table"
puts "      Negative values bring characters closer together"

# 4. Render text showing character spacing
puts "\n4. Text Rendering"
puts "-" * 40

width, height = 600, 300
img = CrImage.rgba(width, height, CrImage::Color::WHITE)

# Render text
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[100 * 64]
)

drawer = CrImage::Font::Drawer.new(img, text_color, face, dot)
drawer.draw("WAVE Type")

# Render same text at different size
small_face = FreeType::TrueType.new_face(font, 24.0)
dot2 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[180 * 64]
)
drawer2 = CrImage::Font::Drawer.new(img, text_color, small_face, dot2)
drawer2.draw("The quick brown fox jumps over the lazy dog")

# Demonstrate composite glyphs (accented characters)
composite_face = FreeType::TrueType.new_face(font, 32.0)
dot_composite = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[230 * 64]
)
drawer_composite = CrImage::Font::Drawer.new(img, text_color, composite_face, dot_composite)
drawer_composite.draw("Café Niño Ñoño")

# Add info text
tiny_face = FreeType::TrueType.new_face(font, 14.0)
dot3 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[270 * 64]
)
drawer3 = CrImage::Font::Drawer.new(img, text_color, tiny_face, dot3)
drawer3.draw("Composite glyphs (é, ñ) are built from base + accent components")

CrImage::PNG.write("output/font_features.png", img)
puts "Saved: output/font_features.png"
