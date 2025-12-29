require "../src/crimage"
require "../src/freetype"

# WOFF (Web Open Font Format) Demo
# This demonstrates loading and using WOFF fonts

puts "WOFF Font Support Demo"
puts "=" * 50

# Check if we have a WOFF font file
woff_path = "fonts/OpenSans-Regular-webfont.woff"

unless File.exists?(woff_path)
  puts "Note: WOFF font not found at #{woff_path}"
  puts "WOFF fonts are compressed TrueType/OpenType fonts commonly used on the web."
  puts ""
  puts "To test this demo:"
  puts "1. Download a WOFF font (e.g., from Google Fonts)"
  puts "2. Place it at #{woff_path}"
  puts ""
  puts "For now, demonstrating WOFF detection with sample data..."
  puts ""

  # Create sample WOFF header for detection test
  sample_woff = Bytes.new(44)
  sample_woff[0] = 0x77_u8 # 'w'
  sample_woff[1] = 0x4F_u8 # 'O'
  sample_woff[2] = 0x46_u8 # 'F'
  sample_woff[3] = 0x46_u8 # 'F'

  puts "✓ WOFF signature detection: #{FreeType::WOFF::Font.is_woff?(sample_woff)}"

  # Test with TrueType signature
  sample_ttf = Bytes.new(44)
  sample_ttf[0] = 0x00_u8
  sample_ttf[1] = 0x01_u8
  sample_ttf[2] = 0x00_u8
  sample_ttf[3] = 0x00_u8

  puts "✓ TrueType is not WOFF: #{!FreeType::WOFF::Font.is_woff?(sample_ttf)}"
  puts ""
  puts "WOFF Features:"
  puts "- Compressed TrueType/OpenType wrapper"
  puts "- Reduces font file size by ~40%"
  puts "- Widely used for web fonts"
  puts "- Transparent decompression to TrueType"
  exit
end

# Load WOFF font
puts "Loading WOFF font: #{woff_path}"
woff_font = FreeType::WOFF.load(woff_path)
puts "✓ WOFF font loaded successfully"

# Convert to TrueType
ttf_font = woff_font.to_truetype
puts "✓ Decompressed to TrueType format"
puts ""

# Create font face and render text
face = FreeType::TrueType.new_face(ttf_font, 48.0)
puts "Font metrics:"
metrics = face.metrics
puts "  Height: #{metrics.height}"
puts "  Ascent: #{metrics.ascent}"
puts "  Descent: #{metrics.descent}"
puts ""

# Render sample text
text = "WOFF Font"
puts "Rendering: '#{text}'"

# Create image with white background
img = CrImage.rgba(400, 100, CrImage::Color::WHITE)

# Black text
text_color = CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))

# Draw text
dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[20 * 64],
  CrImage::Math::Fixed::Int26_6[70 * 64]
)
drawer = CrImage::Font::Drawer.new(img, text_color, face, dot)
drawer.draw(text)

# Save output
output_path = "woff_demo.png"
CrImage::PNG.write(output_path, img)
puts "✓ Saved to #{output_path}"
puts ""

# Show file size comparison
woff_size = File.size(woff_path)
ttf_data_size = woff_font.truetype_data.size
compression_ratio = (1.0 - woff_size.to_f / ttf_data_size) * 100

puts "Compression Statistics:"
puts "  WOFF file size: #{woff_size} bytes"
puts "  Decompressed size: #{ttf_data_size} bytes"
puts "  Compression ratio: #{compression_ratio.round(1)}%"
