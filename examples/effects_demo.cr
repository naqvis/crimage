require "../src/crimage"

# Example: Visual Effects
#
# Demonstrates artistic effects like sepia, emboss, vignette, and
# color temperature adjustment.
#
# Usage:
#   crystal run examples/effects_demo.cr

puts "Visual Effects Demo"
puts "=" * 50

# Create a colorful test image
img = CrImage.rgba(300, 300)

# Create a gradient background
300.times do |y|
  300.times do |x|
    r = (x * 255 // 300).to_u8
    g = (y * 255 // 300).to_u8
    b = ((x + y) * 255 // 600).to_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

# Add some shapes
img.draw_circle(150, 150, 80, color: CrImage::Color::WHITE, fill: true)
img.draw_circle(150, 150, 60, color: CrImage::Color::BLACK, fill: true)

CrImage::PNG.write("effects_original.png", img)
puts "Created original image"

# Apply sepia tone
sepia = img.sepia
CrImage::PNG.write("effects_sepia.png", sepia)
puts "Applied sepia tone effect"

# Apply emboss effect
embossed = img.emboss
CrImage::PNG.write("effects_emboss.png", embossed)
puts "Applied emboss effect"

# Apply emboss with different angle
embossed_angle = img.emboss(angle: 135.0, depth: 1.5)
CrImage::PNG.write("effects_emboss_angle.png", embossed_angle)
puts "Applied emboss with custom angle"

# Apply vignette
vignetted = img.vignette
CrImage::PNG.write("effects_vignette.png", vignetted)
puts "Applied vignette effect"

# Apply strong vignette
strong_vignette = img.vignette(strength: 0.8, radius: 0.5)
CrImage::PNG.write("effects_vignette_strong.png", strong_vignette)
puts "Applied strong vignette"

# Adjust color temperature - warmer
warmer = img.temperature(40)
CrImage::PNG.write("effects_warm.png", warmer)
puts "Applied warm color temperature"

# Adjust color temperature - cooler
cooler = img.temperature(-40)
CrImage::PNG.write("effects_cool.png", cooler)
puts "Applied cool color temperature"

puts "\nOutput files:"
puts "  - effects_original.png"
puts "  - effects_sepia.png (vintage look)"
puts "  - effects_emboss.png (3D raised effect)"
puts "  - effects_emboss_angle.png (custom angle)"
puts "  - effects_vignette.png (darkened edges)"
puts "  - effects_vignette_strong.png (stronger effect)"
puts "  - effects_warm.png (orange/red tint)"
puts "  - effects_cool.png (blue tint)"
