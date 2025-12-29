require "../src/crimage"

puts "=== Border and Frame Demo ===\n"

# Create a sample image
puts "Creating sample image..."
img = CrImage.rgba(300, 200, CrImage::Color::WHITE)

# Draw some content
img.draw_circle(150, 100, 60, color: CrImage::Color.rgb(255, 100, 100), fill: true, anti_alias: false)
img.draw_circle(120, 80, 20, color: CrImage::Color.rgb(255, 200, 100), fill: true, anti_alias: false)
img.draw_circle(180, 80, 20, color: CrImage::Color.rgb(255, 200, 100), fill: true, anti_alias: false)
img.draw_line(130, 120, 170, 120, color: CrImage::Color.rgb(100, 50, 50), thickness: 3, anti_alias: false)

puts "Sample image created (300x200)\n"

# 1. Simple solid border
puts "\n1. Adding simple solid border..."
bordered = img.add_border(20, CrImage::Color::WHITE)
CrImage::PNG.write("border_simple.png", bordered)
puts "Saved: border_simple.png (#{bordered.bounds.width}x#{bordered.bounds.height})"

# 2. Colored border
puts "\n2. Adding colored border..."
colored_border = img.add_border(30, CrImage::Color.rgb(100, 150, 200))
CrImage::PNG.write("border_colored.png", colored_border)
puts "Saved: border_colored.png"

# 3. Rounded corners
puts "\n3. Adding rounded corners..."
rounded = img.round_corners(30)
CrImage::PNG.write("border_rounded.png", rounded)
puts "Saved: border_rounded.png"

# 4. Border with shadow (on colored background to see shadow)
puts "\n4. Adding border with drop shadow..."
shadowed = img.add_border_with_shadow(
  border_width: 20,
  border_color: CrImage::Color::WHITE,
  shadow_offset: 10,
  shadow_blur: 15
)
# Add background so shadow is visible
bg = CrImage.rgba(shadowed.bounds.width, shadowed.bounds.height, CrImage::Color.rgb(220, 220, 230))
shadowed.bounds.height.times do |y|
  shadowed.bounds.width.times do |x|
    pixel = shadowed.at(x, y)
    _, _, _, a = pixel.rgba
    if a > 0
      bg.set(x, y, pixel)
    end
  end
end
CrImage::PNG.write("border_shadow.png", bg)
puts "Saved: border_shadow.png (#{bg.bounds.width}x#{bg.bounds.height})"
puts "  Note: Shadow extends beyond border - transparent areas show viewer background"

# 5. Rounded border
puts "\n5. Adding rounded border..."
rounded_border = img.add_rounded_border(
  border_width: 25,
  corner_radius: 40,
  border_color: CrImage::Color::WHITE
)
CrImage::PNG.write("border_rounded_frame.png", rounded_border)
puts "Saved: border_rounded_frame.png"

# 6. Rounded border with shadow (on colored background)
puts "\n6. Adding rounded border with shadow..."
rounded_shadow = img.add_rounded_border(
  border_width: 25,
  corner_radius: 40,
  border_color: CrImage::Color::WHITE,
  shadow: true,
  shadow_offset: 12,
  shadow_blur: 18
)
# Add background so shadow is visible
bg2 = CrImage.rgba(rounded_shadow.bounds.width, rounded_shadow.bounds.height, CrImage::Color.rgb(220, 220, 230))
rounded_shadow.bounds.height.times do |y|
  rounded_shadow.bounds.width.times do |x|
    pixel = rounded_shadow.at(x, y)
    _, _, _, a = pixel.rgba
    if a > 0
      bg2.set(x, y, pixel)
    end
  end
end
CrImage::PNG.write("border_rounded_shadow.png", bg2)
puts "Saved: border_rounded_shadow.png (#{bg2.bounds.width}x#{bg2.bounds.height})"

# 7. Multiple borders (nested)
puts "\n7. Creating nested borders..."
nested = img.add_border(10, CrImage::Color.rgb(200, 100, 100))
nested = nested.add_border(5, CrImage::Color::WHITE)
nested = nested.add_border(15, CrImage::Color.rgb(100, 100, 200))
CrImage::PNG.write("border_nested.png", nested)
puts "Saved: border_nested.png"

# 8. Photo frame effect
puts "\n8. Creating photo frame effect..."
# Load or create a photo-like image
photo = CrImage.rgba(400, 300)
# Create gradient background
300.times do |y|
  400.times do |x|
    intensity = ((x + y) // 7) % 256
    photo.set(x, y, CrImage::Color.rgb(intensity, intensity // 2, 200))
  end
end

framed_photo = photo.add_rounded_border(
  border_width: 40,
  corner_radius: 20,
  border_color: CrImage::Color.rgb(240, 240, 240),
  shadow: true,
  shadow_offset: 15,
  shadow_blur: 20
)
# Add background for shadow visibility
bg3 = CrImage.rgba(framed_photo.bounds.width, framed_photo.bounds.height, CrImage::Color.rgb(200, 210, 220))
framed_photo.bounds.height.times do |y|
  framed_photo.bounds.width.times do |x|
    pixel = framed_photo.at(x, y)
    _, _, _, a = pixel.rgba
    if a > 0
      bg3.set(x, y, pixel)
    end
  end
end
CrImage::PNG.write("border_photo_frame.png", bg3)
puts "Saved: border_photo_frame.png"

# 9. Profile picture style (circular-ish with rounded corners)
puts "\n9. Creating profile picture style..."
profile = CrImage.rgba(200, 200, CrImage::Color.rgb(100, 150, 255))
profile.draw_circle(100, 100, 80, color: CrImage::Color.rgb(255, 200, 150), fill: true, anti_alias: false)
profile_rounded = profile.round_corners(100) # Large radius for circular effect
CrImage::PNG.write("border_profile.png", profile_rounded)
puts "Saved: border_profile.png"

# 10. Instagram-style border
puts "\n10. Creating Instagram-style border..."
insta = img.add_border(40, CrImage::Color::WHITE)
insta = insta.add_border(2, CrImage::Color.rgb(200, 200, 200))
CrImage::PNG.write("border_instagram.png", insta)
puts "Saved: border_instagram.png"

puts "\n✓ Border demo complete!"
puts "\nGenerated files:"
puts "  - border_simple.png - Simple white border"
puts "  - border_colored.png - Colored border"
puts "  - border_rounded.png - Rounded corners only"
puts "  - border_shadow.png - Border with drop shadow"
puts "  - border_rounded_frame.png - Rounded border"
puts "  - border_rounded_shadow.png - Rounded border with shadow"
puts "  - border_nested.png - Multiple nested borders"
puts "  - border_photo_frame.png - Photo frame effect"
puts "  - border_profile.png - Profile picture style"
puts "  - border_instagram.png - Instagram-style border"
