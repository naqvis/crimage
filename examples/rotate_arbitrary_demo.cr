require "../src/crimage"

# This example demonstrates arbitrary angle rotation
#
# Run with: crystal run examples/rotate_arbitrary_demo.cr

puts "=== Arbitrary Angle Rotation Demo ===\n"

# Create a test image with a pattern
puts "1. Creating test image with pattern..."
img = CrImage.rgba(200, 200, CrImage::Color::WHITE)

# Draw a red cross pattern using high-level API
img.draw_line(100, 0, 100, 99, color: CrImage::Color::RED)
img.draw_line(0, 100, 99, 100, color: CrImage::Color::RED)

# Draw blue corners using high-level API
img.draw_rect(0, 0, 20, 20, fill: CrImage::Color::BLUE)
img.draw_rect(180, 0, 20, 20, fill: CrImage::Color::BLUE)
img.draw_rect(0, 180, 20, 20, fill: CrImage::Color::BLUE)
img.draw_rect(180, 180, 20, 20, fill: CrImage::Color::BLUE)

puts " Created 200x200 test image\n"

# Rotate by various angles
angles = [15.0, 30.0, 45.0, 60.0, 90.0]

angles.each do |angle|
  puts "2. Rotating by #{angle}°..."

  # Bilinear interpolation (higher quality)
  rotated_bilinear = CrImage::Transform.rotate(img, angle)
  puts "   Bilinear: #{rotated_bilinear.bounds.width}x#{rotated_bilinear.bounds.height}"

  # Nearest neighbor (faster)
  rotated_nearest = CrImage::Transform.rotate(img, angle,
    interpolation: CrImage::Transform::RotationInterpolation::Nearest)
  puts "   Nearest:  #{rotated_nearest.bounds.width}x#{rotated_nearest.bounds.height}"

  # Save examples
  CrImage::PNG.write("rotated_#{angle.to_i}_bilinear.png", rotated_bilinear)
  CrImage::PNG.write("rotated_#{angle.to_i}_nearest.png", rotated_nearest)
  puts " Saved rotated_#{angle.to_i}_*.png\n"
end

# Demonstrate custom background
puts "3. Rotating with custom background color..."
rotated_bg = CrImage::Transform.rotate(img, 45.0,
  background: CrImage::Color.rgb(255, 255, 0)) # Yellow background
CrImage::PNG.write("rotated_45_yellow_bg.png", rotated_bg)
puts " Saved rotated_45_yellow_bg.png\n"

# Demonstrate negative angles
puts "4. Rotating counter-clockwise (negative angle)..."
rotated_ccw = CrImage::Transform.rotate(img, -30.0)
CrImage::PNG.write("rotated_minus30.png", rotated_ccw)
puts " Saved rotated_minus30.png\n"

# Performance comparison
puts "5. Performance comparison..."
start = Time.monotonic

10.times do
  CrImage::Transform.rotate(img, 37.0,
    interpolation: CrImage::Transform::RotationInterpolation::Nearest)
end
nearest_time = Time.monotonic - start

start = Time.monotonic
10.times do
  CrImage::Transform.rotate(img, 37.0,
    interpolation: CrImage::Transform::RotationInterpolation::Bilinear)
end
bilinear_time = Time.monotonic - start

puts "   Nearest neighbor: #{(nearest_time.total_milliseconds / 10).round(2)}ms per rotation"
puts "   Bilinear:         #{(bilinear_time.total_milliseconds / 10).round(2)}ms per rotation"
puts "   Speedup:          #{(bilinear_time / nearest_time).round(2)}x\n"

puts "=== Demo Complete ===\n"
puts "Features demonstrated:"
puts "  • Rotation by arbitrary angles (not just 90° increments)"
puts "  • Bilinear interpolation for smooth results"
puts "  • Nearest neighbor for fast rotation"
puts "  • Custom background colors"
puts "  • Negative angles (counter-clockwise rotation)"
puts "  • Automatic bounding box calculation"
puts "\nGenerated files:"
puts "  • rotated_*_bilinear.png - High quality rotations"
puts "  • rotated_*_nearest.png - Fast rotations"
puts "  • rotated_45_yellow_bg.png - Custom background"
puts "  • rotated_minus30.png - Counter-clockwise rotation"
