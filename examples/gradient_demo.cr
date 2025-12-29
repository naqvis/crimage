require "../src/crimage"

# Create an image
width = 400
height = 300
img = CrImage.rgba(width, height)

# Example 1: Linear gradient from red to blue
puts "Creating linear gradient..."
start_point = CrImage::Point.new(0, height // 2)
end_point = CrImage::Point.new(width - 1, height // 2)

# Using named colors - much cleaner!
stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
]

linear_gradient = CrImage::Draw::LinearGradient.new(start_point, end_point, stops)
rect = CrImage.rect(0, 0, width, height // 2)
CrImage::Draw.fill_linear_gradient(img, rect, linear_gradient)

# Example 2: Radial gradient from white to black
puts "Creating radial gradient..."
center = CrImage::Point.new(width // 2, 3 * height // 4)
radius = height // 4

radial_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::WHITE),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLACK),
]

radial_gradient = CrImage::Draw::RadialGradient.new(center, radius, radial_stops)
rect2 = CrImage.rect(0, height // 2, width, height)
CrImage::Draw.fill_radial_gradient(img, rect2, radial_gradient)

# Save the image
puts "Saving gradient_demo.png..."
CrImage::PNG.write("gradient_demo.png", img)
puts "Done!"
