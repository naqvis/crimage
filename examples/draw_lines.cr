require "../src/crimage"

# Create a blank white image - simplified!
img = CrImage.rgba(400, 400, CrImage::Color::WHITE)

# Draw lines with the new simplified API

# 1. Simple red line
img.draw_line(50, 50, 350, 50,
  color: CrImage::Color::RED,
  thickness: 1,
  anti_alias: false)

# 2. Green thick line
img.draw_line(50, 100, 350, 100,
  color: CrImage::Color::GREEN,
  thickness: 5,
  anti_alias: false)

# 3. Blue anti-aliased line
img.draw_line(50, 150, 350, 200,
  color: CrImage::Color::BLUE,
  thickness: 1,
  anti_alias: true)

# 4. Diagonal lines forming an X
img.draw_line(50, 250, 350, 350,
  color: CrImage::Color::PURPLE,
  thickness: 2)
img.draw_line(350, 250, 50, 350,
  color: CrImage::Color::PURPLE,
  thickness: 2)

# 5. Vertical and horizontal lines
img.draw_line(200, 50, 200, 200,
  color: CrImage::Color::ORANGE,
  thickness: 3)
img.draw_line(100, 125, 300, 125,
  color: CrImage::Color::ORANGE,
  thickness: 3)

# Save the image
CrImage::PNG.write("examples/output_lines.png", img)
puts "Line drawing example saved to examples/output_lines.png"
