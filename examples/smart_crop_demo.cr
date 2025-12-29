require "../src/crimage"

# Smart Crop Demo
# Demonstrates intelligent cropping that preserves important content

puts "=== Smart Crop Demo ===\n"

# Create a test image with interesting content
puts "1. Creating test image with content..."
img = CrImage.rgba(800, 600, CrImage::Color::WHITE)

# Draw some "interesting" content (circles and text-like shapes)
# Top-left: red circle
img.draw_circle(150, 100, 50, color: CrImage::Color::RED, fill: true)

# Center: blue square with details
200.upto(400) do |x|
  200.upto(400) do |y|
    # Create a pattern
    if (x + y) % 20 < 10
      img.set(x, y, CrImage::Color::BLUE)
    end
  end
end

# Bottom-right: green circle
img.draw_circle(650, 500, 60, color: CrImage::Color::GREEN, fill: true)

CrImage::PNG.write("smart_crop_original.png", img)
puts "  Saved smart_crop_original.png (800x600)"

# Test different cropping strategies
target_width = 400
target_height = 400

puts "\n2. Comparing crop strategies (#{target_width}x#{target_height}):"

# Entropy-based (default)
entropy_crop = img.smart_crop(target_width, target_height, CrImage::Util::CropStrategy::Entropy)
CrImage::PNG.write("smart_crop_entropy.png", entropy_crop)
puts "  ✓ Entropy-based: smart_crop_entropy.png"

# Edge-based
edge_crop = img.smart_crop(target_width, target_height, CrImage::Util::CropStrategy::Edge)
CrImage::PNG.write("smart_crop_edge.png", edge_crop)
puts "  ✓ Edge-based: smart_crop_edge.png"

# Center-weighted
center_crop = img.smart_crop(target_width, target_height, CrImage::Util::CropStrategy::CenterWeighted)
CrImage::PNG.write("smart_crop_center.png", center_crop)
puts "  ✓ Center-weighted: smart_crop_center.png"

# Attention-based
attention_crop = img.smart_crop(target_width, target_height, CrImage::Util::CropStrategy::Attention)
CrImage::PNG.write("smart_crop_attention.png", attention_crop)
puts "  ✓ Attention-based: smart_crop_attention.png"

# Compare with simple center crop
simple_center_x = (800 - target_width) // 2
simple_center_y = (600 - target_height) // 2
simple_crop = img.crop(CrImage.rect(simple_center_x, simple_center_y,
  simple_center_x + target_width,
  simple_center_y + target_height))
CrImage::PNG.write("smart_crop_simple_center.png", simple_crop)
puts "  ✓ Simple center: smart_crop_simple_center.png"

puts "\n3. Thumbnail generation example:"
# Create thumbnails at different sizes
[{300, 200}, {200, 200}, {150, 150}].each do |(w, h)|
  thumb = img.smart_crop(w, h)
  CrImage::PNG.write("smart_crop_thumb_#{w}x#{h}.png", thumb)
  puts "  ✓ Created #{w}x#{h} thumbnail"
end

puts "\n✓ Demo complete!"
puts "\nCompare the outputs to see how smart crop preserves interesting content"
puts "vs simple center cropping."
