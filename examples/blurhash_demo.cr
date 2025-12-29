require "../src/crimage"

# Blurhash Demo - Compact image placeholders
# Blurhash encodes images into short strings for lazy-loading previews

puts "=== Blurhash Demo ==="

# Create a sample gradient image
puts "\n1. Creating sample image..."
img = CrImage.gradient(200, 150, CrImage::Color::RED, CrImage::Color::BLUE, direction: :diagonal)
CrImage::PNG.write("blurhash_original.png", img)
puts "   Saved: blurhash_original.png (200x150)"

# Encode to blurhash
puts "\n2. Encoding to blurhash..."
hash = img.to_blurhash(x_components: 4, y_components: 3)
puts "   Hash: #{hash}"
puts "   Length: #{hash.size} characters"

# Get component info
x, y = CrImage::Util::Blurhash.components(hash)
puts "   Components: #{x}x#{y}"

# Extract average color (fast, no full decode)
puts "\n3. Extracting average color..."
avg = CrImage::Util::Blurhash.average_color(hash)
puts "   Average: RGB(#{avg.r}, #{avg.g}, #{avg.b})"

# Decode to different sizes
puts "\n4. Decoding to placeholder images..."

# Tiny placeholder (for inline base64)
tiny = CrImage::Util::Blurhash.decode(hash, 4, 3)
CrImage::PNG.write("blurhash_tiny.png", tiny)
puts "   Saved: blurhash_tiny.png (4x3)"

# Small placeholder
small = CrImage::Util::Blurhash.decode(hash, 32, 24)
CrImage::PNG.write("blurhash_small.png", small)
puts "   Saved: blurhash_small.png (32x24)"

# Medium placeholder with punch (contrast boost)
medium = CrImage::Util::Blurhash.decode(hash, 100, 75, punch: 1.5)
CrImage::PNG.write("blurhash_medium.png", medium)
puts "   Saved: blurhash_medium.png (100x75, punch=1.5)"

# Validate hash
puts "\n5. Validation..."
puts "   Valid hash: #{CrImage::Util::Blurhash.valid?(hash)}"
puts "   Invalid 'abc': #{CrImage::Util::Blurhash.valid?("abc")}"

# Different component counts
puts "\n6. Component comparison..."
[{1, 1}, {4, 3}, {9, 9}].each do |xc, yc|
  h = img.to_blurhash(x_components: xc, y_components: yc)
  puts "   #{xc}x#{yc} components: #{h.size} chars"
end

# Use with real image if available
if File.exists?("spec/testdata/exif/Canon_40D.jpg")
  puts "\n7. Real image example..."
  photo = CrImage::JPEG.read("spec/testdata/exif/Canon_40D.jpg")
  photo_hash = photo.to_blurhash
  puts "   Photo hash: #{photo_hash}"

  placeholder = CrImage::Util::Blurhash.decode(photo_hash, 64, 48)
  CrImage::PNG.write("blurhash_photo_placeholder.png", placeholder)
  puts "   Saved: blurhash_photo_placeholder.png"
end

puts "\n=== Demo Complete ==="
