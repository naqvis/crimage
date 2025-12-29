require "../src/crimage"
require "../src/freetype"

# QR Code Generation Demo
# Demonstrates generating QR codes with various options

puts "=== QR Code Demo ==="

# 1. Simple QR code
puts "\n1. Simple QR code..."
qr = CrImage.qr_code("https://github.com/naqvis/crimage")
CrImage::PNG.write("qrcode_simple.png", qr)
puts "   Saved: qrcode_simple.png"

# 2. QR code with custom size
puts "\n2. Custom size QR code..."
qr = CrImage.qr_code("Hello World", size: 400)
CrImage::PNG.write("qrcode_large.png", qr)
puts "   Saved: qrcode_large.png (400px)"

# 3. Different error correction levels
puts "\n3. Error correction levels..."
data = "Test Data"
[:low, :medium, :quartile, :high].each do |ec|
  qr = CrImage.qr_code(data, size: 200, error_correction: ec)
  CrImage::PNG.write("qrcode_ec_#{ec}.png", qr)
  puts "   Saved: qrcode_ec_#{ec}.png"
end

# 4. Low-level API with custom colors
puts "\n4. Custom colors..."
code = CrImage::Util::QRCode.encode("Custom Colors!")
img = code.to_image(
  module_size: 8,
  margin: 3,
  foreground: CrImage::Color::RGBA.new(0_u8, 100_u8, 150_u8, 255_u8),
  background: CrImage::Color::RGBA.new(255_u8, 250_u8, 240_u8, 255_u8)
)
CrImage::PNG.write("qrcode_custom_colors.png", img)
puts "   Saved: qrcode_custom_colors.png"

# 5. QR code info
puts "\n5. QR code information..."
code = CrImage::Util::QRCode.encode("https://example.com/very/long/url/path")
puts "   Data: https://example.com/very/long/url/path"
puts "   Version: #{code.version}"
puts "   Size: #{code.size}x#{code.size} modules"
puts "   Error Correction: #{code.error_correction}"

# 6. Numeric data (efficient encoding)
puts "\n6. Numeric data (efficient)..."
code = CrImage::Util::QRCode.encode("1234567890123456789012345678901234567890")
puts "   40 digits encoded in version #{code.version}"
img = code.to_image(module_size: 5)
CrImage::PNG.write("qrcode_numeric.png", img)
puts "   Saved: qrcode_numeric.png"

# 7. Alphanumeric data
puts "\n7. Alphanumeric data..."
code = CrImage::Util::QRCode.encode("HELLO WORLD 123")
puts "   'HELLO WORLD 123' encoded in version #{code.version}"
img = code.to_image(module_size: 8)
CrImage::PNG.write("qrcode_alphanumeric.png", img)
puts "   Saved: qrcode_alphanumeric.png"

# 8. WiFi QR code
puts "\n8. WiFi QR code..."
wifi = "WIFI:T:WPA;S:MyNetwork;P:MyPassword;;"
qr = CrImage.qr_code(wifi, size: 300, error_correction: :medium)
CrImage::PNG.write("qrcode_wifi.png", qr)
puts "   Saved: qrcode_wifi.png"

# 9. vCard QR code
puts "\n9. vCard QR code..."
vcard = <<-VCARD
BEGIN:VCARD
VERSION:3.0
N:Doe;John
FN:John Doe
TEL:+1234567890
EMAIL:john@example.com
END:VCARD
VCARD
qr = CrImage.qr_code(vcard, size: 350, error_correction: :medium)
CrImage::PNG.write("qrcode_vcard.png", qr)
puts "   Saved: qrcode_vcard.png"

# 10. QR code with logo overlay
puts "\n10. QR code with logo..."
font_path = "fonts/Roboto/static/Roboto-Bold.ttf"
if File.exists?(font_path)
  # Create logo with "CR" text (for CRimage)
  logo = CrImage.rgba(50, 50, CrImage::Color::WHITE)
  font = FreeType::TrueType.load(font_path)
  face = FreeType::TrueType.new_face(font, 28.0)
  blue = CrImage::Uniform.new(CrImage::Color::BLUE)
  drawer = CrImage::Font::Drawer.new(logo, blue, face)
  drawer.draw_text("CR", 5, 38)
  qr = CrImage.qr_code("https://github.com/naqvis/crimage", size: 300, logo: logo)
  CrImage::PNG.write("qrcode_with_logo.png", qr)
  puts "   Saved: qrcode_with_logo.png"
else
  # Fallback: simple colored square
  logo = CrImage.rgba(40, 40, CrImage::Color::WHITE)
  32.times do |y|
    32.times do |x|
      logo.set(x + 4, y + 4, CrImage::Color::BLUE)
    end
  end
  qr = CrImage.qr_code("https://github.com/naqvis/crimage", size: 300, logo: logo)
  CrImage::PNG.write("qrcode_with_logo.png", qr)
  puts "   Saved: qrcode_with_logo.png (no font - using colored square)"
end

# 11. QR code with larger logo
puts "\n11. QR code with larger logo (25%)..."
if File.exists?(font_path)
  logo_large = CrImage.rgba(60, 60, CrImage::Color::WHITE)
  font = FreeType::TrueType.load(font_path)
  face = FreeType::TrueType.new_face(font, 36.0)
  blue = CrImage::Uniform.new(CrImage::Color::BLUE)
  drawer = CrImage::Font::Drawer.new(logo_large, blue, face)
  drawer.draw_text("CR", 5, 46)
  qr = CrImage.qr_code("https://github.com/naqvis/crimage",
    size: 400,
    logo: logo_large,
    logo_scale: 0.25,
    logo_border: 6)
  CrImage::PNG.write("qrcode_logo_large.png", qr)
  puts "   Saved: qrcode_logo_large.png"
else
  puts "   Skipped (font not available)"
end

puts "\n=== Demo Complete ==="
