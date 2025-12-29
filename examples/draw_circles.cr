require "../src/crimage"

# Create a canvas with white background - simplified!
img = CrImage.rgba(400, 400, CrImage::Color::WHITE)

# Draw circles using the new simplified API
# Red circle outline
img.draw_circle(100, 100, 50,
  color: CrImage::Color::RED,
  fill: false,
  anti_alias: false)

# Blue filled circle
img.draw_circle(300, 100, 50,
  color: CrImage::Color::BLUE,
  fill: true,
  anti_alias: false)

# Green anti-aliased circle
img.draw_circle(100, 300, 50,
  color: CrImage::Color::GREEN,
  fill: false,
  anti_alias: true)

# Purple filled anti-aliased circle
img.draw_circle(300, 300, 50,
  color: CrImage::Color::PURPLE,
  fill: true,
  anti_alias: true)

# Draw ellipses
# Orange ellipse outline
img.draw_ellipse(200, 200, 80, 40,
  color: CrImage::Color::ORANGE,
  fill: false,
  anti_alias: false)

# Cyan filled ellipse
img.draw_ellipse(200, 200, 40, 80,
  color: CrImage::Color::CYAN,
  fill: true,
  anti_alias: false)

# Save the image
CrImage::PNG.write("circles_demo.png", img)
puts "Created circles_demo.png with various circles and ellipses"
