require "../src/crimage"

# Example: Convenience Factory Methods
#
# Demonstrates quick image creation with checkerboard patterns,
# gradients, and auto-format detection.
#
# Usage:
#   crystal run examples/factory_methods_demo.cr

puts "Convenience Factory Methods Demo"
puts "=" * 50

# =============================================================================
# Checkerboard Patterns
# =============================================================================
puts "\nCreating checkerboard patterns..."

# Default checkerboard (transparency background style)
checker = CrImage.checkerboard(200, 200, cell_size: 16)
CrImage::PNG.write("factory_checkerboard.png", checker)
puts "  Saved: factory_checkerboard.png (16px cells)"

# Small cells
checker_small = CrImage.checkerboard(200, 200, cell_size: 8)
CrImage::PNG.write("factory_checkerboard_small.png", checker_small)
puts "  Saved: factory_checkerboard_small.png (8px cells)"

# Large cells
checker_large = CrImage.checkerboard(200, 200, cell_size: 32)
CrImage::PNG.write("factory_checkerboard_large.png", checker_large)
puts "  Saved: factory_checkerboard_large.png (32px cells)"

# Custom colors (pink and light blue)
checker_custom = CrImage.checkerboard(200, 200,
  cell_size: 20,
  color1: CrImage::Color::RGBA.new(255_u8, 200_u8, 200_u8, 255_u8),
  color2: CrImage::Color::RGBA.new(200_u8, 200_u8, 255_u8, 255_u8))
CrImage::PNG.write("factory_checkerboard_custom.png", checker_custom)
puts "  Saved: factory_checkerboard_custom.png (custom colors)"

# Chess board style
chess = CrImage.checkerboard(400, 400,
  cell_size: 50,
  color1: CrImage::Color::RGBA.new(139_u8, 90_u8, 43_u8, 255_u8),
  color2: CrImage::Color::RGBA.new(222_u8, 184_u8, 135_u8, 255_u8))
CrImage::PNG.write("factory_chessboard.png", chess)
puts "  Saved: factory_chessboard.png (chess board)"

# =============================================================================
# Gradient Images
# =============================================================================
puts "\nCreating gradient images..."

# Horizontal gradient (red to blue)
h_gradient = CrImage.gradient(300, 100, CrImage::Color::RED, CrImage::Color::BLUE, :horizontal)
CrImage::PNG.write("factory_gradient_horizontal.png", h_gradient)
puts "  Saved: factory_gradient_horizontal.png"

# Vertical gradient (green to yellow)
v_gradient = CrImage.gradient(100, 300, CrImage::Color::GREEN, CrImage::Color::YELLOW, :vertical)
CrImage::PNG.write("factory_gradient_vertical.png", v_gradient)
puts "  Saved: factory_gradient_vertical.png"

# Diagonal gradient (black to white)
d_gradient = CrImage.gradient(200, 200, CrImage::Color::BLACK, CrImage::Color::WHITE, :diagonal)
CrImage::PNG.write("factory_gradient_diagonal.png", d_gradient)
puts "  Saved: factory_gradient_diagonal.png"

# Sunset gradient
sunset = CrImage.gradient(400, 200,
  CrImage::Color::RGBA.new(255_u8, 94_u8, 77_u8, 255_u8),
  CrImage::Color::RGBA.new(255_u8, 195_u8, 113_u8, 255_u8),
  :horizontal)
CrImage::PNG.write("factory_gradient_sunset.png", sunset)
puts "  Saved: factory_gradient_sunset.png"

# Ocean gradient
ocean = CrImage.gradient(400, 200,
  CrImage::Color::RGBA.new(0_u8, 50_u8, 100_u8, 255_u8),
  CrImage::Color::RGBA.new(0_u8, 150_u8, 200_u8, 255_u8),
  :vertical)
CrImage::PNG.write("factory_gradient_ocean.png", ocean)
puts "  Saved: factory_gradient_ocean.png"

# =============================================================================
# Point and Rectangle Helpers
# =============================================================================
puts "\nUsing point and rectangle helpers..."

# Create points
p1 = CrImage.point(10, 20)
p2 = CrImage.point({100, 200}) # From tuple
puts "  Point from coords: (#{p1.x}, #{p1.y})"
puts "  Point from tuple: (#{p2.x}, #{p2.y})"

# Create rectangles
r1 = CrImage.rect(0, 0, 100, 100)
puts "  Rectangle: #{r1.width}x#{r1.height}"

# =============================================================================
# Combining Factory Methods
# =============================================================================
puts "\nCombining factory methods..."

# Create gradient background with shapes
bg = CrImage.gradient(300, 200,
  CrImage::Color::RGBA.new(30_u8, 30_u8, 60_u8, 255_u8),
  CrImage::Color::RGBA.new(60_u8, 60_u8, 120_u8, 255_u8),
  :diagonal)
bg.draw_circle(150, 100, 50, color: CrImage::Color::WHITE, fill: true)
bg.draw_circle(80, 60, 20, color: CrImage::Color::YELLOW, fill: true)
CrImage::PNG.write("factory_combined.png", bg)
puts "  Saved: factory_combined.png"

# Checkerboard with overlay
overlay_bg = CrImage.checkerboard(300, 200, cell_size: 10)
overlay_bg.draw_rect(50, 50, 200, 100, fill: CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 180_u8))
CrImage::PNG.write("factory_checker_overlay.png", overlay_bg)
puts "  Saved: factory_checker_overlay.png"

puts "\nOutput files:"
puts "  Checkerboards:"
puts "    - factory_checkerboard.png"
puts "    - factory_checkerboard_small.png"
puts "    - factory_checkerboard_large.png"
puts "    - factory_checkerboard_custom.png"
puts "    - factory_chessboard.png"
puts "  Gradients:"
puts "    - factory_gradient_horizontal.png"
puts "    - factory_gradient_vertical.png"
puts "    - factory_gradient_diagonal.png"
puts "    - factory_gradient_sunset.png"
puts "    - factory_gradient_ocean.png"
puts "  Combined:"
puts "    - factory_combined.png"
puts "    - factory_checker_overlay.png"
