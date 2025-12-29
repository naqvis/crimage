require "../src/crimage"
require "../src/freetype"

# Create a sample base image (blue gradient)
width, height = 400, 300
img = CrImage.rgba(width, height)

# Fill with blue gradient
height.times do |y|
  width.times do |x|
    intensity = (255 * y / height).to_u8
    img.set(x, y, CrImage::Color.rgb(0, 100, intensity))
  end
end

# Create a simple watermark logo (circle with "©" symbol pattern)
wm_size = 60
watermark = CrImage.rgba(wm_size, wm_size)

# Fill with transparent background
watermark.clear # Simplified!

# Draw a white circle with semi-transparent fill
center = wm_size // 2
radius = wm_size // 2 - 2

wm_size.times do |y|
  wm_size.times do |x|
    dx = x - center
    dy = y - center
    distance = ::Math.sqrt(dx * dx + dy * dy)

    if distance <= radius
      # White semi-transparent circle
      watermark.set(x, y, CrImage::Color.rgba(255, 255, 255, 200))
    elsif distance <= radius + 2
      # White border
      watermark.set(x, y, CrImage::Color::WHITE)
    end
  end
end

# Add a simple "C" pattern in the center (copyright symbol approximation)
c_radius = radius // 2
wm_size.times do |y|
  wm_size.times do |x|
    dx = x - center
    dy = y - center
    distance = ::Math.sqrt(dx * dx + dy * dy)
    angle = ::Math.atan2(dy, dx)

    # Draw "C" shape (circle with gap on right side)
    if distance >= c_radius - 3 && distance <= c_radius + 3
      # Skip right side to create "C" shape
      unless angle > -0.5 && angle < 0.5
        watermark.set(x, y, CrImage::Color.rgb(100, 100, 100))
      end
    end
  end
end

puts "Watermarking Demo"
puts "=" * 50

# Save original image
CrImage::PNG.write("watermark_original.png", img)
puts "\nSaved original image: watermark_original.png"

# Demo 1: Bottom-right watermark (default)
puts "\n1. Bottom-right watermark with 50% opacity"
options1 = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::BottomRight,
  opacity: 0.5
)
result1 = CrImage::Util.watermark_image(img, watermark, options1)
CrImage::PNG.write("watermark_bottom_right.png", result1)
puts "   Saved: watermark_bottom_right.png"

# Demo 2: Top-left watermark
puts "\n2. Top-left watermark with 70% opacity"
options2 = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::TopLeft,
  opacity: 0.7
)
result2 = CrImage::Util.watermark_image(img, watermark, options2)
CrImage::PNG.write("watermark_top_left.png", result2)
puts "   Saved: watermark_top_left.png"

# Demo 3: Center watermark
puts "\n3. Center watermark with 80% opacity"
options3 = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::Center,
  opacity: 0.8
)
result3 = CrImage::Util.watermark_image(img, watermark, options3)
CrImage::PNG.write("watermark_center.png", result3)
puts "   Saved: watermark_center.png"

# Demo 4: Custom position watermark
puts "\n4. Custom position watermark at (100, 50)"
options4 = CrImage::Util::WatermarkOptions.new(
  position: CrImage::Util::WatermarkPosition::Custom,
  custom_point: CrImage::Point.new(100, 50),
  opacity: 0.6
)
result4 = CrImage::Util.watermark_image(img, watermark, options4)
CrImage::PNG.write("watermark_custom.png", result4)
puts "   Saved: watermark_custom.png"

# Demo 5: Tiled watermark
puts "\n5. Tiled watermark with 30% opacity"
options5 = CrImage::Util::WatermarkOptions.new(
  opacity: 0.3,
  tiled: true
)
result5 = CrImage::Util.watermark_image(img, watermark, options5)
CrImage::PNG.write("watermark_tiled.png", result5)
puts "   Saved: watermark_tiled.png"

# Demo 6: Text watermark (if font is available)
font_path = "fonts/Roboto/static/Roboto-Bold.ttf"
if File.exists?(font_path)
  puts "\n6. Text watermark '© 2024 Copyright' at bottom-right"
  font = FreeType::TrueType.load(font_path)
  face = FreeType::TrueType.new_face(font, 24.0)

  options6 = CrImage::Util::WatermarkOptions.new(
    position: CrImage::Util::WatermarkPosition::BottomRight,
    opacity: 0.8
  )
  result6 = CrImage::Util.watermark_text(img, "© 2024 Copyright", face, options6)
  CrImage::PNG.write("watermark_text.png", result6)
  puts "   Saved: watermark_text.png"

  # Demo 7: Tiled text watermark
  puts "\n7. Tiled text watermark 'CONFIDENTIAL'"
  options7 = CrImage::Util::WatermarkOptions.new(
    opacity: 0.3,
    tiled: true
  )
  result7 = CrImage::Util.watermark_text(img, "CONFIDENTIAL", face, options7)
  CrImage::PNG.write("watermark_text_tiled.png", result7)
  puts "   Saved: watermark_text_tiled.png"

  puts "\n" + "=" * 50
  puts "Watermarking demo completed successfully!"
  puts "Generated 8 PNG files demonstrating different watermark options."
else
  puts "\n" + "=" * 50
  puts "Watermarking demo completed successfully!"
  puts "Generated 6 PNG files demonstrating image watermark options."
  puts "\nNote: Text watermark examples skipped (font not found at #{font_path})"
  puts "To see text watermarks, ensure fonts are available in fonts/ directory."
end
