require "../src/crimage"

# Create a canvas with white background
img = CrImage.rgba(400, 400, CrImage::Color::WHITE)

# Draw a filled triangle using simplified API
triangle_points = [
  CrImage::Point.new(50, 50),
  CrImage::Point.new(150, 50),
  CrImage::Point.new(100, 150),
]
img.draw_polygon(triangle_points,
  fill: CrImage::Color::RED,
  outline: CrImage::Color::BLACK)

# Draw a filled square
square_points = [
  CrImage::Point.new(200, 50),
  CrImage::Point.new(350, 50),
  CrImage::Point.new(350, 200),
  CrImage::Point.new(200, 200),
]
img.draw_polygon(square_points,
  fill: CrImage::Color::GREEN,
  outline: CrImage::Color::BLACK)

# Draw a pentagon outline only
pentagon_points = [
  CrImage::Point.new(100, 250),
  CrImage::Point.new(150, 220),
  CrImage::Point.new(140, 280),
  CrImage::Point.new(60, 280),
  CrImage::Point.new(50, 220),
]
img.draw_polygon(pentagon_points,
  outline: CrImage::Color::BLUE)

# Draw a hexagon with anti-aliasing
hexagon_points = [
  CrImage::Point.new(275, 250),
  CrImage::Point.new(325, 270),
  CrImage::Point.new(325, 310),
  CrImage::Point.new(275, 330),
  CrImage::Point.new(225, 310),
  CrImage::Point.new(225, 270),
]
img.draw_polygon(hexagon_points,
  fill: CrImage::Color::YELLOW,
  outline: CrImage::Color::PURPLE,
  anti_alias: true)

# Save the image
File.open("polygon_demo.png", "wb") do |file|
  CrImage::PNG.write(file, img)
end

puts "Polygon demo saved to polygon_demo.png"
