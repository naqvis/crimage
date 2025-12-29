require "../src/crimage"

# WebP Transparency Example
# Demonstrates creating WebP images with alpha channel (transparency)

puts "Creating image with transparency..."

# Create a 200x200 image
width = 200
height = 200
img = CrImage.nrgba(width, height)

# Fill with transparent background
img.clear # Much simpler!

# Draw a red circle with varying transparency
center_x = width // 2
center_y = height // 2
radius = 80

height.times do |y|
  width.times do |x|
    dx = x - center_x
    dy = y - center_y
    distance = Math.sqrt(dx * dx + dy * dy)

    if distance <= radius
      # Alpha decreases from center to edge
      alpha = (255 * (1.0 - distance / radius)).to_u8
      img.set_nrgba(x, y, CrImage::Color::NRGBA.new(255, 0, 0, alpha))
    end
  end
end

# Draw a blue square with semi-transparency
square_size = 60
square_x = 30
square_y = 30

square_size.times do |dy|
  square_size.times do |dx|
    x = square_x + dx
    y = square_y + dy
    if x < width && y < height
      img.set_nrgba(x, y, CrImage::Color::NRGBA.new(0, 0, 255, 180))
    end
  end
end

# Draw a green square with semi-transparency (overlapping)
square_x2 = 110
square_y2 = 110

square_size.times do |dy|
  square_size.times do |dx|
    x = square_x2 + dx
    y = square_y2 + dy
    if x < width && y < height
      img.set_nrgba(x, y, CrImage::Color::NRGBA.new(0, 255, 0, 180))
    end
  end
end

puts "Image created: #{width}x#{height} with alpha channel"
puts "  Opaque: #{img.opaque?}"

# Save as WebP with standard format
puts "\nSaving as WebP (standard format)..."
CrImage::WEBP.write("transparency_standard.webp", img)
standard_size = File.size("transparency_standard.webp")
puts "  File: transparency_standard.webp (#{standard_size} bytes)"

# Save as WebP with extended format
puts "\nSaving as WebP (extended format)..."
options = CrImage::WEBP::Options.new(use_extended_format: true)
CrImage::WEBP.write("transparency_extended.webp", img, options)
extended_size = File.size("transparency_extended.webp")
puts "  File: transparency_extended.webp (#{extended_size} bytes)"

# Also save as PNG for comparison
puts "\nSaving as PNG for comparison..."
CrImage::PNG.write("transparency.png", img)
png_size = File.size("transparency.png")
puts "  File: transparency.png (#{png_size} bytes)"

# Show size comparison
puts "\nSize comparison:"
puts "  WebP (standard): #{standard_size} bytes (#{(standard_size.to_f / png_size * 100).round(2)}% of PNG)"
puts "  WebP (extended): #{extended_size} bytes (#{(extended_size.to_f / png_size * 100).round(2)}% of PNG)"
puts "  PNG: #{png_size} bytes (100%)"

# Verify round-trip
puts "\nVerifying round-trip encoding/decoding..."
decoded = CrImage::WEBP.read("transparency_standard.webp")
puts "  Decoded: #{decoded.bounds.width}x#{decoded.bounds.height}"
puts "  Opaque: #{decoded.opaque?}"

# Check a few pixels
test_pixels = [
  {x: center_x, y: center_y, desc: "center (red, full alpha)"},
  {x: 10, y: 10, desc: "corner (transparent)"},
  {x: square_x + 10, y: square_y + 10, desc: "blue square"},
]

puts "\nSample pixels:"
test_pixels.each do |test|
  original = img.nrgba_at(test[:x], test[:y])
  decoded_color = decoded.at(test[:x], test[:y])
  r, g, b, a = decoded_color.rgba

  puts "  #{test[:desc]}:"
  puts "    Original: R=#{original.r} G=#{original.g} B=#{original.b} A=#{original.a}"
  puts "    Decoded:  R=#{r >> 8} G=#{g >> 8} B=#{b >> 8} A=#{a >> 8}"
end

puts "\nWebP transparency example complete!"
puts "  Created: transparency_standard.webp, transparency_extended.webp, transparency.png"
