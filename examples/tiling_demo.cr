require "../src/crimage"

puts "=== Image Tiling and Pattern Generation Demo ===\n"

# Create a simple tile pattern
puts "1. Creating a simple tile pattern..."
tile = CrImage.rgba(80, 80, CrImage::Color::WHITE)

# Draw a colorful pattern on the tile
tile.draw_circle(40, 40, 30, color: CrImage::Color.rgb(100, 150, 255), fill: true, anti_alias: false)
tile.draw_circle(40, 40, 20, color: CrImage::Color.rgb(255, 200, 100), fill: true, anti_alias: false)
tile.draw_rect(10, 10, 20, 20, fill: CrImage::Color.rgb(255, 100, 150))
tile.draw_rect(50, 50, 20, 20, fill: CrImage::Color.rgb(150, 255, 100))

CrImage::PNG.write("tile_original.png", tile)
puts "Saved: tile_original.png (80x80)"

# 2. Simple tiling
puts "\n2. Tiling 4x3 grid..."
tiled = tile.tile(4, 3)
CrImage::PNG.write("tile_grid_4x3.png", tiled)
puts "Saved: tile_grid_4x3.png (#{tiled.bounds.width}x#{tiled.bounds.height})"

# 3. Large tiling for wallpaper
puts "\n3. Creating wallpaper pattern (8x6 grid)..."
wallpaper = tile.tile(8, 6)
CrImage::PNG.write("tile_wallpaper.png", wallpaper)
puts "Saved: tile_wallpaper.png (#{wallpaper.bounds.width}x#{wallpaper.bounds.height})"

# 4. Tile to specific size
puts "\n4. Tiling to fill 1000x800 pixels..."
sized = tile.tile_to_size(1000, 800)
CrImage::PNG.write("tile_sized.png", sized)
puts "Saved: tile_sized.png (#{sized.bounds.width}x#{sized.bounds.height})"

# 5. Create a gradient tile
puts "\n5. Creating gradient tile..."
gradient_tile = CrImage.rgba(100, 100)
100.times do |y|
  100.times do |x|
    intensity = ((x + y) * 255 // 200).clamp(0, 255)
    gradient_tile.set(x, y, CrImage::Color.rgb(intensity, 100, 255 - intensity))
  end
end
CrImage::PNG.write("tile_gradient_original.png", gradient_tile)

# Tile the gradient (will show seams)
gradient_tiled = gradient_tile.tile(4, 4)
CrImage::PNG.write("tile_gradient_with_seams.png", gradient_tiled)
puts "Saved: tile_gradient_with_seams.png (shows visible seams)"

# 6. Make seamless and tile
puts "\n6. Creating seamless pattern..."
seamless = gradient_tile.make_seamless(blend_width: 15)
CrImage::PNG.write("tile_seamless.png", seamless)
puts "Saved: tile_seamless.png (seamless version)"

seamless_tiled = seamless.tile(4, 4)
CrImage::PNG.write("tile_seamless_tiled.png", seamless_tiled)
puts "Saved: tile_seamless_tiled.png (no visible seams)"

# 7. Checkerboard pattern
puts "\n7. Creating checkerboard pattern..."
checker = CrImage.rgba(40, 40)
40.times do |y|
  40.times do |x|
    color = if (x // 20 + y // 20) % 2 == 0
              CrImage::Color.rgb(200, 200, 200)
            else
              CrImage::Color.rgb(100, 100, 100)
            end
    checker.set(x, y, color)
  end
end

checker_tiled = checker.tile(10, 10)
CrImage::PNG.write("tile_checkerboard.png", checker_tiled)
puts "Saved: tile_checkerboard.png (#{checker_tiled.bounds.width}x#{checker_tiled.bounds.height})"

# 8. Diagonal stripe pattern
puts "\n8. Creating diagonal stripe pattern..."
stripe = CrImage.rgba(60, 60)
60.times do |y|
  60.times do |x|
    color = if (x + y) % 20 < 10
              CrImage::Color.rgb(255, 150, 150)
            else
              CrImage::Color.rgb(150, 150, 255)
            end
    stripe.set(x, y, color)
  end
end

stripe_seamless = stripe.make_seamless(blend_width: 10)
stripe_tiled = stripe_seamless.tile(6, 6)
CrImage::PNG.write("tile_stripes.png", stripe_tiled)
puts "Saved: tile_stripes.png (#{stripe_tiled.bounds.width}x#{stripe_tiled.bounds.height})"

# 9. Dot pattern
puts "\n9. Creating dot pattern..."
dots = CrImage.rgba(50, 50, CrImage::Color.rgb(240, 240, 250))
dots.draw_circle(25, 25, 8, color: CrImage::Color.rgb(100, 100, 200), fill: true, anti_alias: false)

dots_tiled = dots.tile(12, 8)
CrImage::PNG.write("tile_dots.png", dots_tiled)
puts "Saved: tile_dots.png (#{dots_tiled.bounds.width}x#{dots_tiled.bounds.height})"

# 10. Complex pattern with seamless tiling
puts "\n10. Creating complex seamless pattern..."
complex = CrImage.rgba(120, 120)

# Draw multiple shapes
complex.draw_circle(30, 30, 20, color: CrImage::Color.rgb(255, 100, 100), fill: true, anti_alias: false)
complex.draw_circle(90, 30, 20, color: CrImage::Color.rgb(100, 255, 100), fill: true, anti_alias: false)
complex.draw_circle(30, 90, 20, color: CrImage::Color.rgb(100, 100, 255), fill: true, anti_alias: false)
complex.draw_circle(90, 90, 20, color: CrImage::Color.rgb(255, 255, 100), fill: true, anti_alias: false)
complex.draw_circle(60, 60, 25, color: CrImage::Color.rgb(255, 150, 200), fill: true, anti_alias: false)

# Add gradient background
120.times do |y|
  120.times do |x|
    existing = complex.at(x, y)
    _, _, _, a = existing.rgba
    if a == 0
      intensity = 200 + ((x + y) * 55 // 240)
      complex.set(x, y, CrImage::Color.rgb(intensity, intensity, 255))
    end
  end
end

complex_seamless = complex.make_seamless(blend_width: 20)
complex_tiled = complex_seamless.tile(4, 3)
CrImage::PNG.write("tile_complex.png", complex_tiled)
puts "Saved: tile_complex.png (#{complex_tiled.bounds.width}x#{complex_tiled.bounds.height})"

puts "\n✓ Tiling demo complete!"
puts "\nGenerated files:"
puts "  - tile_original.png - Original tile (80x80)"
puts "  - tile_grid_4x3.png - Simple 4x3 grid"
puts "  - tile_wallpaper.png - Large 8x6 wallpaper"
puts "  - tile_sized.png - Tiled to exact size (1000x800)"
puts "  - tile_gradient_with_seams.png - Gradient with visible seams"
puts "  - tile_seamless.png - Seamless gradient tile"
puts "  - tile_seamless_tiled.png - Seamless gradient tiled"
puts "  - tile_checkerboard.png - Checkerboard pattern"
puts "  - tile_stripes.png - Diagonal stripe pattern"
puts "  - tile_dots.png - Dot pattern"
puts "  - tile_complex.png - Complex seamless pattern"
