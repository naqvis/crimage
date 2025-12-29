require "../src/crimage"

puts "=== Image Stacking and Comparison Demo ===\n"

# Create sample images for demonstration
puts "Creating sample images..."

# Image 1: Red circle
img1 = CrImage.rgba(200, 150, CrImage::Color::WHITE)
img1.draw_circle(100, 75, 50, color: CrImage::Color.rgb(255, 100, 100), fill: true, anti_alias: false)
CrImage::PNG.write("stack_img1.png", img1)

# Image 2: Green square
img2 = CrImage.rgba(200, 150, CrImage::Color::WHITE)
img2.draw_rect(75, 50, 50, 50, fill: CrImage::Color.rgb(100, 255, 100))
CrImage::PNG.write("stack_img2.png", img2)

# Image 3: Blue triangle
img3 = CrImage.rgba(200, 150, CrImage::Color::WHITE)
points = [
  CrImage::Point.new(100, 25),
  CrImage::Point.new(150, 125),
  CrImage::Point.new(50, 125),
]
img3.draw_polygon(points, fill: CrImage::Color.rgb(100, 100, 255), anti_alias: false)
CrImage::PNG.write("stack_img3.png", img3)

puts "Sample images created\n"

# 1. Horizontal stacking
puts "1. Stacking images horizontally..."
horizontal = CrImage.stack_horizontal([img1, img2, img3])
CrImage::PNG.write("stack_horizontal.png", horizontal)
puts "Saved: stack_horizontal.png (#{horizontal.bounds.width}x#{horizontal.bounds.height})"

# 2. Horizontal with spacing
puts "\n2. Horizontal stacking with spacing..."
horizontal_spaced = CrImage.stack_horizontal([img1, img2, img3], spacing: 20)
CrImage::PNG.write("stack_horizontal_spaced.png", horizontal_spaced)
puts "Saved: stack_horizontal_spaced.png (#{horizontal_spaced.bounds.width}x#{horizontal_spaced.bounds.height})"

# 3. Vertical stacking
puts "\n3. Stacking images vertically..."
vertical = CrImage.stack_vertical([img1, img2, img3])
CrImage::PNG.write("stack_vertical.png", vertical)
puts "Saved: stack_vertical.png (#{vertical.bounds.width}x#{vertical.bounds.height})"

# 4. Vertical with spacing
puts "\n4. Vertical stacking with spacing..."
vertical_spaced = CrImage.stack_vertical([img1, img2, img3], spacing: 15)
CrImage::PNG.write("stack_vertical_spaced.png", vertical_spaced)
puts "Saved: stack_vertical_spaced.png (#{vertical_spaced.bounds.width}x#{vertical_spaced.bounds.height})"

# 5. Before/After comparison
puts "\n5. Creating before/after comparison..."
# Create "before" image (grayscale)
before = CrImage.rgba(300, 200, CrImage::Color.rgb(200, 200, 200))
before.draw_circle(150, 100, 60, color: CrImage::Color.rgb(150, 150, 150), fill: true, anti_alias: false)

# Create "after" image (colorful)
after = CrImage.rgba(300, 200, CrImage::Color.rgb(240, 240, 255))
after.draw_circle(150, 100, 60, color: CrImage::Color.rgb(255, 150, 100), fill: true, anti_alias: false)

comparison = CrImage.compare_images(before, after)
CrImage::PNG.write("stack_comparison.png", comparison)
puts "Saved: stack_comparison.png (#{comparison.bounds.width}x#{comparison.bounds.height})"

# 6. Before/After with divider
puts "\n6. Before/after with divider line..."
comparison_divider = CrImage.compare_images(before, after, divider: true, divider_width: 3)
CrImage::PNG.write("stack_comparison_divider.png", comparison_divider)
puts "Saved: stack_comparison_divider.png"

# 7. Grid layout
puts "\n7. Creating 2x2 grid..."
grid_images = [img1, img2, img3, before]
grid = CrImage.create_grid(grid_images, cols: 2, spacing: 15)
CrImage::PNG.write("stack_grid_2x2.png", grid)
puts "Saved: stack_grid_2x2.png (#{grid.bounds.width}x#{grid.bounds.height})"

# 8. Grid layout 3 columns
puts "\n8. Creating 3-column grid..."
grid3 = CrImage.create_grid([img1, img2, img3], cols: 3, spacing: 10)
CrImage::PNG.write("stack_grid_3col.png", grid3)
puts "Saved: stack_grid_3col.png (#{grid3.bounds.width}x#{grid3.bounds.height})"

# 9. Photo gallery style
puts "\n9. Creating photo gallery..."
# Create multiple "photos"
photos = [] of CrImage::Image
6.times do |i|
  photo = CrImage.rgba(180, 180, CrImage::Color.rgb(220 + i * 5, 220 + i * 5, 240))

  # Add some content
  case i % 3
  when 0
    photo.draw_circle(90, 90, 50, color: CrImage::Color.rgb(255 - i * 20, 100 + i * 20, 150), fill: true, anti_alias: false)
  when 1
    photo.draw_rect(40, 40, 100, 100, fill: CrImage::Color.rgb(150, 255 - i * 20, 100 + i * 20))
  else
    points = [
      CrImage::Point.new(90, 30),
      CrImage::Point.new(150, 150),
      CrImage::Point.new(30, 150),
    ]
    photo.draw_polygon(points, fill: CrImage::Color.rgb(100 + i * 20, 150, 255 - i * 20), anti_alias: false)
  end

  photos << photo
end

gallery = CrImage.create_grid(photos, cols: 3, spacing: 12,
  background: CrImage::Color.rgb(240, 240, 240))
CrImage::PNG.write("stack_gallery.png", gallery)
puts "Saved: stack_gallery.png (#{gallery.bounds.width}x#{gallery.bounds.height})"

# 10. Different sized images with alignment
puts "\n10. Stacking different sized images..."
small = CrImage.rgba(100, 80, CrImage::Color.rgb(255, 200, 200))
medium = CrImage.rgba(150, 120, CrImage::Color.rgb(200, 255, 200))
large = CrImage.rgba(200, 150, CrImage::Color.rgb(200, 200, 255))

# Top alignment
aligned_top = CrImage.stack_horizontal([small, medium, large], spacing: 10,
  alignment: CrImage::Util::VerticalAlignment::Top)
CrImage::PNG.write("stack_aligned_top.png", aligned_top)
puts "Saved: stack_aligned_top.png (top-aligned)"

# Center alignment
aligned_center = CrImage.stack_horizontal([small, medium, large], spacing: 10,
  alignment: CrImage::Util::VerticalAlignment::Center)
CrImage::PNG.write("stack_aligned_center.png", aligned_center)
puts "Saved: stack_aligned_center.png (center-aligned)"

# Bottom alignment
aligned_bottom = CrImage.stack_horizontal([small, medium, large], spacing: 10,
  alignment: CrImage::Util::VerticalAlignment::Bottom)
CrImage::PNG.write("stack_aligned_bottom.png", aligned_bottom)
puts "Saved: stack_aligned_bottom.png (bottom-aligned)"

puts "\n✓ Stacking demo complete!"
puts "\nGenerated files:"
puts "  - stack_img1.png, stack_img2.png, stack_img3.png - Sample images"
puts "  - stack_horizontal.png - Horizontal stacking"
puts "  - stack_horizontal_spaced.png - With spacing"
puts "  - stack_vertical.png - Vertical stacking"
puts "  - stack_vertical_spaced.png - With spacing"
puts "  - stack_comparison.png - Before/after comparison"
puts "  - stack_comparison_divider.png - With divider line"
puts "  - stack_grid_2x2.png - 2x2 grid layout"
puts "  - stack_grid_3col.png - 3-column grid"
puts "  - stack_gallery.png - Photo gallery"
puts "  - stack_aligned_top.png - Top-aligned"
puts "  - stack_aligned_center.png - Center-aligned"
puts "  - stack_aligned_bottom.png - Bottom-aligned"
