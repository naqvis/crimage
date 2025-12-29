require "../src/crimage"

# Example: Edge Detection
#
# Demonstrates various edge detection algorithms for finding boundaries
# and features in images.
#
# Edge detection highlights areas where pixel intensity changes rapidly,
# revealing object boundaries and features. White pixels = edges detected.
#
# Usage:
#   crystal run examples/edge_detection_demo.cr

puts "Edge Detection Demo"
puts "=" * 50

# Create a more interesting test image with gradients and shapes
img = CrImage.rgba(400, 400)

# Create a gradient background
400.times do |y|
  400.times do |x|
    gray = (100 + (x + y) * 155 // 800).to_u8
    img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
  end
end

# Draw various shapes with different intensities
img.draw_circle(100, 100, 60, color: CrImage::Color::BLACK, fill: true)
img.draw_circle(100, 100, 40, color: CrImage::Color::WHITE, fill: true)

img.draw_rect(200, 50, 150, 100, fill: CrImage::Color.rgba(200, 200, 200, 255))
img.draw_rect(220, 70, 110, 60, fill: CrImage::Color.rgba(50, 50, 50, 255))

# Triangle-ish polygon
points = [
  CrImage::Point.new(100, 250),
  CrImage::Point.new(200, 250),
  CrImage::Point.new(150, 350),
]
img.draw_polygon(points, fill: CrImage::Color.rgba(150, 150, 150, 255))

# Some lines
img.draw_line(250, 250, 380, 380, color: CrImage::Color::WHITE, thickness: 5)
img.draw_line(380, 250, 250, 380, color: CrImage::Color::BLACK, thickness: 5)

CrImage::PNG.write("edge_original.png", img)
puts "Created original image with shapes and gradients"

# Apply different edge detection operators
puts "\nApplying edge detection algorithms..."

sobel = img.sobel
# Invert so edges show as black on white (easier to see)
sobel_inverted = sobel.invert
CrImage::PNG.write("edge_sobel.png", sobel_inverted)
puts "Sobel operator - general purpose, good balance"

prewitt = img.prewitt
prewitt_inverted = prewitt.invert
CrImage::PNG.write("edge_prewitt.png", prewitt_inverted)
puts "Prewitt operator - similar to Sobel, equal weighting"

roberts = img.roberts
roberts_inverted = roberts.invert
CrImage::PNG.write("edge_roberts.png", roberts_inverted)
puts "Roberts cross - fast 2x2 operator, more noise"

scharr = img.detect_edges(CrImage::Transform::EdgeOperator::Scharr)
scharr_inverted = scharr.invert
CrImage::PNG.write("edge_scharr.png", scharr_inverted)
puts "Scharr operator - improved Sobel, better rotation invariance"

# Binary edge map with threshold
binary_edges = img.sobel(threshold: 30)
binary_inverted = binary_edges.invert
CrImage::PNG.write("edge_binary.png", binary_inverted)
puts "Binary edge map (threshold=30) - clean edges only"

# Show gradient magnitude (not inverted) for comparison
CrImage::PNG.write("edge_sobel_gradient.png", sobel)
puts "Gradient magnitude (white=strong edges)"

puts "\n" + "=" * 50
puts "Understanding the Output"
puts "=" * 50
puts "Edge detection finds areas of rapid intensity change."
puts "In the inverted images (most outputs):"
puts "  • Black lines = detected edges"
puts "  • White areas = no edges (uniform regions)"
puts ""
puts "In edge_sobel_gradient.png (not inverted):"
puts "  • White/bright = strong edges"
puts "  • Black/dark = weak or no edges"
puts "  • Gray = medium edge strength"

puts "\n" + "=" * 50
puts "Output Files"
puts "=" * 50
puts "  edge_original.png       - Original image"
puts "  edge_sobel.png          - Sobel (inverted, black edges)"
puts "  edge_prewitt.png        - Prewitt (inverted, black edges)"
puts "  edge_roberts.png        - Roberts (inverted, black edges)"
puts "  edge_scharr.png         - Scharr (inverted, black edges)"
puts "  edge_binary.png         - Binary threshold (inverted)"
puts "  edge_sobel_gradient.png - Gradient magnitude (white edges)"

puts "\nCompare the different operators to see their characteristics!"
