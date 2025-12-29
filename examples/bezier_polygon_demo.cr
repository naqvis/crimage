# Bezier Curves and Regular Polygons Demo
#
# Demonstrates:
# - Regular polygons (triangle, square, pentagon, hexagon, octagon)
# - Thick circle outlines
# - Quadratic bezier curves (one control point)
# - Cubic bezier curves (two control points)
# - Smooth splines through multiple points
#
# Run: crystal run examples/bezier_polygon_demo.cr

require "../src/crimage"

puts "=== Bezier Curves and Regular Polygons Demo ==="

# Create canvas
img = CrImage.rgba(600, 500, CrImage::Color::WHITE)

# --- Regular Polygons ---
puts "\n1. Drawing regular polygons..."

fill_style = CrImage::Draw::PolygonStyle.new(
  fill_color: CrImage::Color.rgba(100, 150, 255, 255),
  outline_color: CrImage::Color::BLACK
)

outline_style = CrImage::Draw::PolygonStyle.new(
  outline_color: CrImage::Color.rgba(255, 100, 100, 255)
)

# Row 1: Filled polygons
CrImage::Draw.triangle(img, CrImage::Point.new(60, 60), 40, fill_style)
CrImage::Draw.square(img, CrImage::Point.new(160, 60), 35, fill_style)
CrImage::Draw.pentagon(img, CrImage::Point.new(260, 60), 40, fill_style)
CrImage::Draw.hexagon(img, CrImage::Point.new(360, 60), 40, fill_style)
CrImage::Draw.regular_polygon(img, CrImage::Point.new(460, 60), 40, 8, fill_style)  # Octagon
CrImage::Draw.regular_polygon(img, CrImage::Point.new(540, 60), 35, 12, fill_style) # Dodecagon

# Labels
puts "   Triangle, Square, Pentagon, Hexagon, Octagon, Dodecagon"

# --- Thick Circle Outlines ---
puts "\n2. Drawing thick circle outlines..."

# Different thicknesses
[2, 4, 6, 8].each_with_index do |thickness, i|
  style = CrImage::Draw::CircleStyle.new(
    CrImage::Color.rgba((50 + i * 50).to_u8, 100_u8, 200_u8, 255_u8)
  ).with_thickness(thickness)
  CrImage::Draw.circle(img, CrImage::Point.new(80 + i * 120, 160), 40, style)
end

puts "   Thickness: 2, 4, 6, 8 pixels"

# --- Quadratic Bezier Curves ---
puts "\n3. Drawing quadratic bezier curves..."

bezier_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(0, 150, 0, 255), thickness: 2)

# Draw control point visualization
def draw_control_point(img, p, color)
  style = CrImage::Draw::CircleStyle.new(color, fill: true)
  CrImage::Draw.circle(img, p, 4, style)
end

# Quadratic bezier 1
p0 = CrImage::Point.new(50, 280)
p1 = CrImage::Point.new(150, 220) # Control point
p2 = CrImage::Point.new(250, 280)
CrImage::Draw.quadratic_bezier(img, p0, p1, p2, bezier_style)

# Draw control points
draw_control_point(img, p0, CrImage::Color::BLUE)
draw_control_point(img, p1, CrImage::Color::RED)
draw_control_point(img, p2, CrImage::Color::BLUE)

# Quadratic bezier 2 (inverted)
p0 = CrImage::Point.new(280, 280)
p1 = CrImage::Point.new(380, 340) # Control point below
p2 = CrImage::Point.new(480, 280)
CrImage::Draw.quadratic_bezier(img, p0, p1, p2, bezier_style)

draw_control_point(img, p0, CrImage::Color::BLUE)
draw_control_point(img, p1, CrImage::Color::RED)
draw_control_point(img, p2, CrImage::Color::BLUE)

# --- Cubic Bezier Curves ---
puts "\n4. Drawing cubic bezier curves..."

cubic_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(200, 50, 150, 255), thickness: 2)

# Cubic bezier (S-curve)
p0 = CrImage::Point.new(50, 380)
p1 = CrImage::Point.new(100, 320) # Control 1
p2 = CrImage::Point.new(200, 440) # Control 2
p3 = CrImage::Point.new(250, 380)
CrImage::Draw.cubic_bezier(img, p0, p1, p2, p3, cubic_style)

draw_control_point(img, p0, CrImage::Color::BLUE)
draw_control_point(img, p1, CrImage::Color::RED)
draw_control_point(img, p2, CrImage::Color::RED)
draw_control_point(img, p3, CrImage::Color::BLUE)

# Draw control lines (dashed)
dash_style = CrImage::Draw::DashedLineStyle.dotted(CrImage::Color.rgba(150, 150, 150, 255))
CrImage::Draw.dashed_line(img, p0, p1, dash_style)
CrImage::Draw.dashed_line(img, p2, p3, dash_style)

# Another cubic bezier
p0 = CrImage::Point.new(300, 380)
p1 = CrImage::Point.new(350, 300)
p2 = CrImage::Point.new(450, 300)
p3 = CrImage::Point.new(500, 380)
CrImage::Draw.cubic_bezier(img, p0, p1, p2, p3, cubic_style)

draw_control_point(img, p0, CrImage::Color::BLUE)
draw_control_point(img, p1, CrImage::Color::RED)
draw_control_point(img, p2, CrImage::Color::RED)
draw_control_point(img, p3, CrImage::Color::BLUE)

CrImage::Draw.dashed_line(img, p0, p1, dash_style)
CrImage::Draw.dashed_line(img, p2, p3, dash_style)

# --- Smooth Spline ---
puts "\n5. Drawing smooth spline..."

spline_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(255, 100, 0, 255), thickness: 3)

points = [
  CrImage::Point.new(50, 470),
  CrImage::Point.new(150, 430),
  CrImage::Point.new(250, 480),
  CrImage::Point.new(350, 420),
  CrImage::Point.new(450, 470),
  CrImage::Point.new(550, 440),
]

CrImage::Draw.spline(img, points, spline_style, tension: 0.5)

# Draw the points
points.each do |p|
  draw_control_point(img, p, CrImage::Color::BLACK)
end

# Save output
output_path = "output/bezier_polygon_demo.png"
Dir.mkdir_p("output")
CrImage::PNG.write(output_path, img)

puts "\n✓ Saved to #{output_path}"
puts "\nLegend:"
puts "  Blue dots  = Start/end points"
puts "  Red dots   = Control points"
puts "  Black dots = Spline pass-through points"
