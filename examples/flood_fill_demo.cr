require "../src/crimage"

# Example: Flood Fill and Color Selection
#
# Demonstrates flood fill, color-based selection,
# and color replacement operations.
#
# Usage:
#   crystal run examples/flood_fill_demo.cr

puts "Flood Fill and Color Selection Demo"
puts "=" * 50

# Create an image with distinct colored regions
puts "Creating image with colored regions..."
img = CrImage.rgba(250, 200, CrImage::Color::WHITE)

# Draw colored shapes
(30...90).each do |y|
  (30...90).each do |x|
    img.set(x, y, CrImage::Color::RED)
  end
end

(50...150).each do |y|
  (100...180).each do |x|
    img.set(x, y, CrImage::Color::GREEN)
  end
end

img.draw_circle(200, 50, 35, color: CrImage::Color::BLUE, fill: true)
img.draw_circle(200, 150, 30, color: CrImage::Color::PURPLE, fill: true)

CrImage::PNG.write("flood_original.png", img)
puts "  Saved: flood_original.png"

# Flood fill the red region with yellow
puts "\nFlood filling red region with yellow..."
fill_img = CrImage.rgba(250, 200)
200.times do |y|
  250.times do |x|
    fill_img.set(x, y, img.at(x, y))
  end
end
filled = fill_img.flood_fill(60, 60, CrImage::Color::YELLOW, tolerance: 10)
CrImage::PNG.write("flood_yellow.png", fill_img)
puts "  Filled #{filled} pixels"
puts "  Saved: flood_yellow.png"

# Flood fill with different tolerance
puts "\nFlood filling with high tolerance (catches similar colors)..."
fill_img2 = CrImage.rgba(250, 200)
200.times do |y|
  250.times do |x|
    fill_img2.set(x, y, img.at(x, y))
  end
end
filled2 = fill_img2.flood_fill(60, 60, CrImage::Color::CYAN, tolerance: 50)
CrImage::PNG.write("flood_high_tolerance.png", fill_img2)
puts "  Filled #{filled2} pixels"
puts "  Saved: flood_high_tolerance.png"

# Create selection mask (contiguous)
puts "\nCreating contiguous selection mask for green region..."
mask = img.select_by_color(140, 100, tolerance: 10, contiguous: true)
CrImage::PNG.write("flood_mask_contiguous.png", mask)
puts "  Saved: flood_mask_contiguous.png"

# Create selection mask (non-contiguous / global)
puts "\nCreating global selection mask for white background..."
global_mask = img.select_by_color(10, 10, tolerance: 10, contiguous: false)
CrImage::PNG.write("flood_mask_global.png", global_mask)
puts "  Saved: flood_mask_global.png"

# Replace color globally
puts "\nReplacing all blue with orange..."
replaced = img.replace_color(CrImage::Color::BLUE, CrImage::Color::ORANGE, tolerance: 10)
CrImage::PNG.write("flood_replaced_blue.png", replaced)
puts "  Saved: flood_replaced_blue.png"

# Replace multiple colors
puts "\nReplacing multiple colors..."
multi_replaced = img
  .replace_color(CrImage::Color::RED, CrImage::Color::CYAN, tolerance: 10)
  .replace_color(CrImage::Color::GREEN, CrImage::Color::MAGENTA, tolerance: 10)
CrImage::PNG.write("flood_multi_replaced.png", multi_replaced)
puts "  Saved: flood_multi_replaced.png"

# Paint bucket effect - fill white background
puts "\nPaint bucket: filling white background with light blue..."
bucket_img = CrImage.rgba(250, 200)
200.times do |y|
  250.times do |x|
    bucket_img.set(x, y, img.at(x, y))
  end
end
bucket_img.flood_fill(5, 5, CrImage::Color::RGBA.new(200_u8, 220_u8, 255_u8, 255_u8), tolerance: 10)
CrImage::PNG.write("flood_paint_bucket.png", bucket_img)
puts "  Saved: flood_paint_bucket.png"

puts "\nOutput files:"
puts "  - flood_original.png"
puts "  - flood_yellow.png (red filled with yellow)"
puts "  - flood_high_tolerance.png"
puts "  - flood_mask_contiguous.png (selection mask)"
puts "  - flood_mask_global.png (global selection)"
puts "  - flood_replaced_blue.png"
puts "  - flood_multi_replaced.png"
puts "  - flood_paint_bucket.png"
