require "../src/crimage"

# Create sample sprite images with different sizes and colors
puts "Creating sample sprites..."

sprites = [] of CrImage::Image

# Sprite 1: Red circle
sprite1 = CrImage.rgba(64, 64, CrImage::Color::TRANSPARENT)
sprite1.draw_circle(32, 32, 28, color: CrImage::Color::RED, fill: true, anti_alias: false)
sprites << sprite1

# Sprite 2: Green square
sprite2 = CrImage.rgba(48, 48, CrImage::Color::TRANSPARENT)
sprite2.draw_rect(8, 8, 32, 32, fill: CrImage::Color::GREEN)
sprites << sprite2

# Sprite 3: Blue triangle (polygon)
sprite3 = CrImage.rgba(56, 56, CrImage::Color::TRANSPARENT)
points = [
  CrImage::Point.new(28, 8),
  CrImage::Point.new(48, 48),
  CrImage::Point.new(8, 48),
]
sprite3.draw_polygon(points, fill: CrImage::Color::BLUE, anti_alias: false)
sprites << sprite3

# Sprite 4: Yellow star (simplified as diamond)
sprite4 = CrImage.rgba(40, 40, CrImage::Color::TRANSPARENT)
star_points = [
  CrImage::Point.new(20, 4),
  CrImage::Point.new(36, 20),
  CrImage::Point.new(20, 36),
  CrImage::Point.new(4, 20),
]
sprite4.draw_polygon(star_points, fill: CrImage::Color::YELLOW, anti_alias: false)
sprites << sprite4

# Sprite 5: Cyan ellipse
sprite5 = CrImage.rgba(72, 48, CrImage::Color::TRANSPARENT)
sprite5.draw_ellipse(36, 24, 32, 20, color: CrImage::Color::CYAN, fill: true, anti_alias: false)
sprites << sprite5

# Sprite 6: Magenta hexagon (approximated)
sprite6 = CrImage.rgba(52, 52, CrImage::Color::TRANSPARENT)
hex_points = [
  CrImage::Point.new(26, 4),
  CrImage::Point.new(44, 16),
  CrImage::Point.new(44, 36),
  CrImage::Point.new(26, 48),
  CrImage::Point.new(8, 36),
  CrImage::Point.new(8, 16),
]
sprite6.draw_polygon(hex_points, fill: CrImage::Color.rgb(255, 0, 255), anti_alias: false)
sprites << sprite6

puts "Generated #{sprites.size} sprites"

# Generate horizontal sprite sheet
puts "\nGenerating horizontal sprite sheet..."
horizontal = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Horizontal,
  spacing: 8,
  background: CrImage::Color::BLACK
)
CrImage::PNG.write("sprite_horizontal.png", horizontal.image)
puts "Saved: sprite_horizontal.png (#{horizontal.image.bounds.width}x#{horizontal.image.bounds.height})"
horizontal.sprites.each_with_index do |sprite, i|
  puts "  Sprite #{i}: pos=(#{sprite.x}, #{sprite.y}) size=(#{sprite.width}x#{sprite.height})"
end

# Generate vertical sprite sheet
puts "\nGenerating vertical sprite sheet..."
vertical = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Vertical,
  spacing: 8,
  background: CrImage::Color::BLACK
)
CrImage::PNG.write("sprite_vertical.png", vertical.image)
puts "Saved: sprite_vertical.png (#{vertical.image.bounds.width}x#{vertical.image.bounds.height})"

# Generate grid sprite sheet
puts "\nGenerating grid sprite sheet..."
grid = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Grid,
  spacing: 10,
  background: CrImage::Color::BLACK
)
CrImage::PNG.write("sprite_grid.png", grid.image)
puts "Saved: sprite_grid.png (#{grid.image.bounds.width}x#{grid.image.bounds.height})"

# Generate packed sprite sheet
puts "\nGenerating packed sprite sheet..."
packed = CrImage.generate_sprite_sheet(
  sprites,
  CrImage::Util::SpriteLayout::Packed,
  spacing: 5,
  background: CrImage::Color::BLACK
)
CrImage::PNG.write("sprite_packed.png", packed.image)
puts "Saved: sprite_packed.png (#{packed.image.bounds.width}x#{packed.image.bounds.height})"

# Demonstrate sprite extraction
puts "\nExtracting individual sprites from sheet..."
sprite_info = horizontal[2] # Get third sprite
extracted = horizontal.image.crop(sprite_info.bounds)
CrImage::PNG.write("sprite_extracted.png", extracted)
puts "Extracted sprite #{sprite_info.index} from position (#{sprite_info.x}, #{sprite_info.y})"

# Create a game-style sprite sheet with animation frames
puts "\nCreating animation sprite sheet..."
frames = [] of CrImage::Image

8.times do |i|
  frame = CrImage.rgba(48, 48, CrImage::Color::TRANSPARENT)
  # Animate a bouncing ball
  y_pos = 24 + (::Math.sin(i * ::Math::PI / 4) * 12).to_i32
  frame.draw_circle(24, y_pos, 10, color: CrImage::Color.rgb(255, 128, 0), fill: true, anti_alias: false)
  frames << frame
end

animation_sheet = CrImage.generate_sprite_sheet(
  frames,
  CrImage::Util::SpriteLayout::Horizontal,
  spacing: 2
)
CrImage::PNG.write("sprite_animation.png", animation_sheet.image)
puts "Saved: sprite_animation.png (#{frames.size} frames)"

# Create icon sprite sheet
puts "\nCreating icon sprite sheet..."
icons = [] of CrImage::Image

# Icon 1: Plus
icon1 = CrImage.rgba(32, 32, CrImage::Color::TRANSPARENT)
icon1.draw_rect(14, 8, 4, 16, fill: CrImage::Color::BLACK)
icon1.draw_rect(8, 14, 16, 4, fill: CrImage::Color::BLACK)
icons << icon1

# Icon 2: Minus
icon2 = CrImage.rgba(32, 32, CrImage::Color::TRANSPARENT)
icon2.draw_rect(8, 14, 16, 4, fill: CrImage::Color::BLACK)
icons << icon2

# Icon 3: X
icon3 = CrImage.rgba(32, 32, CrImage::Color::TRANSPARENT)
icon3.draw_line(8, 8, 24, 24, color: CrImage::Color::BLACK, thickness: 3, anti_alias: false)
icon3.draw_line(24, 8, 8, 24, color: CrImage::Color::BLACK, thickness: 3, anti_alias: false)
icons << icon3

# Icon 4: Check
icon4 = CrImage.rgba(32, 32, CrImage::Color::TRANSPARENT)
icon4.draw_line(8, 16, 14, 22, color: CrImage::Color::BLACK, thickness: 3, anti_alias: false)
icon4.draw_line(14, 22, 24, 10, color: CrImage::Color::BLACK, thickness: 3, anti_alias: false)
icons << icon4

icon_sheet = CrImage.generate_sprite_sheet(
  icons,
  CrImage::Util::SpriteLayout::Grid,
  spacing: 4,
  background: CrImage::Color::WHITE
)
CrImage::PNG.write("sprite_icons.png", icon_sheet.image)
puts "Saved: sprite_icons.png (#{icons.size} icons)"

puts "\n✓ Sprite generation demo complete!"
puts "Generated files:"
puts "  - sprite_horizontal.png"
puts "  - sprite_vertical.png"
puts "  - sprite_grid.png"
puts "  - sprite_packed.png"
puts "  - sprite_extracted.png"
puts "  - sprite_animation.png"
puts "  - sprite_icons.png"
