require "../src/crimage"

# WebP Comprehensive Demo
# Demonstrates various WebP encoding features and capabilities

puts "=== WebP Comprehensive Demo ===\n"

# 1. Create a simple gradient image
puts "1. Creating gradient image..."
width = 256
height = 256
gradient = CrImage.nrgba(width, height)

height.times do |y|
  width.times do |x|
    r = x.to_u8
    g = y.to_u8
    b = ((x + y) // 2).to_u8
    gradient.set_nrgba(x, y, CrImage::Color::NRGBA.new(r, g, b, 255))
  end
end

CrImage::WEBP.write("demo_gradient.webp", gradient)
puts " Saved: demo_gradient.webp (#{File.size("demo_gradient.webp")} bytes)"

# 2. Create image with transparency
puts "\n2. Creating image with alpha channel..."
alpha_img = CrImage.nrgba(100, 100)

100.times do |y|
  100.times do |x|
    # Create a pattern with varying transparency
    alpha = ((x + y) * 255 // 200).clamp(0, 255).to_u8
    alpha_img.set_nrgba(x, y, CrImage::Color::NRGBA.new(255, 100, 50, alpha))
  end
end

CrImage::WEBP.write("demo_alpha.webp", alpha_img)
puts " Saved: demo_alpha.webp (#{File.size("demo_alpha.webp")} bytes)"
puts "   Opaque: #{alpha_img.opaque?}"

# 3. Test extended format
puts "\n3. Creating with extended format (VP8X)..."
options = CrImage::WEBP::Options.new(use_extended_format: true)
CrImage::WEBP.write("demo_extended.webp", gradient, options)
puts " Saved: demo_extended.webp (#{File.size("demo_extended.webp")} bytes)"

# 4. Create a pattern image (good for compression)
puts "\n4. Creating pattern image (tests compression)..."
pattern = CrImage.nrgba(128, 128)

128.times do |y|
  128.times do |x|
    # Checkerboard pattern
    if (x // 16 + y // 16) % 2 == 0
      pattern.set_nrgba(x, y, CrImage::Color::NRGBA.new(255, 0, 0, 255))
    else
      pattern.set_nrgba(x, y, CrImage::Color::NRGBA.new(0, 0, 255, 255))
    end
  end
end

CrImage::WEBP.write("demo_pattern.webp", pattern)
puts " Saved: demo_pattern.webp (#{File.size("demo_pattern.webp")} bytes)"

# 5. Round-trip test
puts "\n5. Testing round-trip encoding/decoding..."
decoded = CrImage::WEBP.read("demo_gradient.webp")
puts "   Original: #{gradient.bounds.width}x#{gradient.bounds.height}"
puts "   Decoded:  #{decoded.bounds.width}x#{decoded.bounds.height}"

# Verify a few pixels
matches = 0
mismatches = 0
10.times do |i|
  x = (i * 25) % width
  y = (i * 25) % height

  orig = gradient.nrgba_at(x, y)
  dec_color = decoded.at(x, y)
  r, g, b, a = dec_color.rgba

  if orig.r == (r >> 8) && orig.g == (g >> 8) && orig.b == (b >> 8) && orig.a == (a >> 8)
    matches += 1
  else
    mismatches += 1
  end
end

puts "   Pixel verification: #{matches}/10 exact matches"
if mismatches == 0
  puts " Perfect round-trip!"
end

# 6. Compare with PNG
puts "\n6. Comparing WebP vs PNG compression..."
CrImage::PNG.write("demo_gradient.png", gradient)
webp_size = File.size("demo_gradient.webp")
png_size = File.size("demo_gradient.png")
ratio = (webp_size.to_f / png_size * 100).round(2)

puts "   WebP: #{webp_size} bytes"
puts "   PNG:  #{png_size} bytes"
puts "   WebP is #{ratio}% the size of PNG"

if webp_size < png_size
  saved = png_size - webp_size
  puts "   Saved: #{saved} bytes (#{(100 - ratio).round(2)}% reduction)"
end

# 7. Test with different image types
puts "\n7. Testing with different source image types..."

# RGBA image
rgba = CrImage::RGBA.new(CrImage::Rectangle.new(CrImage::Point.new(0, 0), CrImage::Point.new(50, 50)))
50.times do |y|
  50.times do |x|
    rgba.set_rgba(x, y, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
  end
end
CrImage::WEBP.write("demo_rgba.webp", rgba)
puts " RGBA source: demo_rgba.webp (#{File.size("demo_rgba.webp")} bytes)"

# Gray image
gray = CrImage::Gray.new(CrImage::Rectangle.new(CrImage::Point.new(0, 0), CrImage::Point.new(50, 50)))
50.times do |y|
  50.times do |x|
    gray.set_gray(x, y, CrImage::Color::Gray.new(((x + y) * 255 // 100).to_u8))
  end
end
CrImage::WEBP.write("demo_gray.webp", gray)
puts " Gray source: demo_gray.webp (#{File.size("demo_gray.webp")} bytes)"

# Summary
puts "\n=== Summary ==="
puts "Created 7 WebP demo files:"
puts "  • demo_gradient.webp - Color gradient"
puts "  • demo_alpha.webp - Transparency example"
puts "  • demo_extended.webp - VP8X extended format"
puts "  • demo_pattern.webp - Checkerboard pattern"
puts "  • demo_gradient.png - PNG comparison"
puts "  • demo_rgba.webp - From RGBA source"
puts "  • demo_gray.webp - From grayscale source"

total_size = ["demo_gradient.webp", "demo_alpha.webp", "demo_extended.webp",
              "demo_pattern.webp", "demo_rgba.webp", "demo_gray.webp"].sum do |f|
  File.size(f)
end

puts "\nTotal WebP files size: #{total_size} bytes"
puts "\nDemo complete! All files created successfully."
