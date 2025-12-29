# Charting Features Demo
#
# Demonstrates all the new charting-focused drawing features:
# 1. Path builder & bezier bands (Sankey diagrams)
# 2. Gradient fills for shapes
# 3. Blend modes
# 4. Pattern fills (hatching) - accessibility
# 5. Per-corner rounded rectangles (bar charts)
# 6. Arrow heads (flow diagrams)
# 7. Marker symbols (scatter plots)
# 8. Text along curves (pie chart labels)
# 9. Annotations (callouts, dimensions, brackets)
# 10. Gradient strokes (progress indicators)
#
# Run: crystal run examples/charting_features_demo.cr

require "../src/crimage"

puts "=== Charting Features Demo ==="

# Create large canvas
WIDTH  = 1200
HEIGHT =  900
img = CrImage.rgba(WIDTH, HEIGHT, CrImage::Color::WHITE)

# Load font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
font_bold_path = "fonts/Roboto/static/Roboto-Bold.ttf"

font = FreeType::TrueType.load(font_path)
font_bold = FreeType::TrueType.load(font_bold_path)
face_title = FreeType::TrueType.new_face(font_bold, 20.0)
face_label = FreeType::TrueType.new_face(font, 14.0)
face_small = FreeType::TrueType.new_face(font, 11.0)

text_black = CrImage::Uniform.new(CrImage::Color::BLACK)
drawer_title = CrImage::Font::Drawer.new(img, text_black, face_title)
drawer_label = CrImage::Font::Drawer.new(img, text_black, face_label)

# Helper to draw section title
def draw_title(img, text, x, y, face)
  drawer = CrImage::Font::Drawer.new(img, CrImage::Uniform.new(CrImage::Color.rgba(50_u8, 50_u8, 50_u8, 255_u8)), face)
  drawer.draw_text(text, x, y)
end

# ============================================================================
# ROW 1: Sankey/Bezier Bands, Path Builder, Gradient Fills
# ============================================================================
row_y = 30
puts "\n1. Drawing Sankey bands, paths, gradient fills..."

draw_title(img, "1. Bezier Bands (Sankey)", 20, row_y + 20, face_title)

# Sankey-style flow bands
top1 = {CrImage.point(30, row_y + 60), CrImage.point(100, row_y + 50),
        CrImage.point(170, row_y + 70), CrImage.point(230, row_y + 60)}
bottom1 = {CrImage.point(30, row_y + 90), CrImage.point(100, row_y + 100),
           CrImage.point(170, row_y + 110), CrImage.point(230, row_y + 100)}
CrImage::Draw.fill_bezier_band(img, top1, bottom1,
  CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 200_u8), anti_alias: true)

top2 = {CrImage.point(30, row_y + 100), CrImage.point(100, row_y + 110),
        CrImage.point(170, row_y + 130), CrImage.point(230, row_y + 120)}
bottom2 = {CrImage.point(30, row_y + 130), CrImage.point(100, row_y + 150),
           CrImage.point(170, row_y + 160), CrImage.point(230, row_y + 150)}
CrImage::Draw.fill_bezier_band(img, top2, bottom2,
  CrImage::Color.rgba(234_u8, 67_u8, 53_u8, 200_u8), anti_alias: true)

top3 = {CrImage.point(30, row_y + 140), CrImage.point(100, row_y + 160),
        CrImage.point(170, row_y + 170), CrImage.point(230, row_y + 160)}
bottom3 = {CrImage.point(30, row_y + 165), CrImage.point(100, row_y + 190),
           CrImage.point(170, row_y + 195), CrImage.point(230, row_y + 185)}
CrImage::Draw.fill_bezier_band(img, top3, bottom3,
  CrImage::Color.rgba(52_u8, 168_u8, 83_u8, 200_u8), anti_alias: true)

# Path builder demo
draw_title(img, "2. Path Builder", 270, row_y + 20, face_title)

path = CrImage::Draw::Path.new
  .move_to(280, row_y + 80)
  .bezier_to(330, row_y + 40, 430, row_y + 40, 480, row_y + 80)
  .line_to(480, row_y + 150)
  .bezier_to(430, row_y + 190, 330, row_y + 190, 280, row_y + 150)
  .close

CrImage::Draw.fill_path_aa(img, path, CrImage::Color.rgba(156_u8, 39_u8, 176_u8, 220_u8))
stroke_style = CrImage::Draw::PathStyle.new(CrImage::Color.rgba(100_u8, 20_u8, 120_u8, 255_u8), thickness: 2)
CrImage::Draw.stroke_path(img, path, stroke_style)

# Gradient fill for polygon
draw_title(img, "3. Gradient Polygon Fill", 520, row_y + 20, face_title)

triangle = [
  CrImage.point(600, row_y + 50),
  CrImage.point(720, row_y + 180),
  CrImage.point(530, row_y + 180),
]
gradient = CrImage::Draw::LinearGradient.new(
  CrImage.point(530, row_y + 50),
  CrImage.point(720, row_y + 180),
  [
    CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(255, 87, 34)),
    CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(255, 193, 7)),
    CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(76, 175, 80)),
  ]
)
CrImage::Draw.fill_polygon_gradient(img, triangle, gradient)

# Blend modes
draw_title(img, "4. Blend Modes", 770, row_y + 20, face_title)

# Base rectangle
base_rect = [CrImage.point(780, row_y + 60), CrImage.point(880, row_y + 60),
             CrImage.point(880, row_y + 140), CrImage.point(780, row_y + 140)]
CrImage::Draw.polygon(img, base_rect, CrImage::Draw::PolygonStyle.new(fill_color: CrImage::Color.rgb(100, 150, 200)))

# Overlapping with multiply
overlay_rect = [CrImage.point(830, row_y + 100), CrImage.point(930, row_y + 100),
                CrImage.point(930, row_y + 180), CrImage.point(830, row_y + 180)]
CrImage::Draw.fill_polygon_blended(img, overlay_rect,
  CrImage::Color.rgba(255_u8, 100_u8, 100_u8, 200_u8), CrImage::Draw::BlendMode::Multiply)

drawer_small = CrImage::Font::Drawer.new(img, text_black, face_small)
drawer_small.draw_text("Multiply", 850, row_y + 195)

# Screen blend
overlay2 = [CrImage.point(950, row_y + 60), CrImage.point(1050, row_y + 60),
            CrImage.point(1050, row_y + 140), CrImage.point(950, row_y + 140)]
CrImage::Draw.polygon(img, overlay2, CrImage::Draw::PolygonStyle.new(fill_color: CrImage::Color.rgb(80, 80, 80)))

overlay3 = [CrImage.point(1000, row_y + 100), CrImage.point(1100, row_y + 100),
            CrImage.point(1100, row_y + 180), CrImage.point(1000, row_y + 180)]
CrImage::Draw.fill_polygon_blended(img, overlay3,
  CrImage::Color.rgba(100_u8, 200_u8, 255_u8, 200_u8), CrImage::Draw::BlendMode::Screen)
drawer_small.draw_text("Screen", 1030, row_y + 195)

# ============================================================================
# ROW 2: Pattern Fills, Rounded Rectangles, Arrows
# ============================================================================
row_y = 230
puts "2. Drawing patterns, rounded rects, arrows..."

draw_title(img, "5. Pattern Fills (Accessibility)", 20, row_y + 20, face_title)

# Different patterns
patterns = [
  {CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6, thickness: 2), "Diagonal"},
  {CrImage::Draw::Pattern.crosshatch(CrImage::Color.rgb(0, 128, 0), spacing: 8), "Crosshatch"},
  {CrImage::Draw::Pattern.dots(CrImage::Color.rgb(200, 0, 0), spacing: 8, size: 2), "Dots"},
  {CrImage::Draw::Pattern.horizontal(CrImage::Color.rgb(128, 0, 128), spacing: 5, thickness: 2), "Horizontal"},
]

x_offset = 30
patterns.each_with_index do |(pattern, name), i|
  rect = CrImage.rect(x_offset, row_y + 50, x_offset + 70, row_y + 120)
  CrImage::Draw.fill_rect_pattern(img, rect, pattern)
  # Border
  CrImage::Draw.rectangle(img, rect, CrImage::Draw::RectStyle.new(outline_color: CrImage::Color::BLACK))
  drawer_small.draw_text(name, x_offset + 10, row_y + 140)
  x_offset += 85
end

# Per-corner rounded rectangles
draw_title(img, "6. Per-Corner Rounded Rects", 380, row_y + 20, face_title)

# Bar chart style (top rounded)
bar_colors = [CrImage::Color.rgb(66, 133, 244), CrImage::Color.rgb(234, 67, 53),
              CrImage::Color.rgb(251, 188, 5), CrImage::Color.rgb(52, 168, 83)]
bar_heights = [100, 70, 120, 85]

(0...4).each do |i|
  rect = CrImage.rect(400 + i * 50, row_y + 150 - bar_heights[i], 440 + i * 50, row_y + 150)
  radii = CrImage::Draw::CornerRadii.top(8)
  CrImage::Draw.rounded_rect(img, rect, radii, fill: bar_colors[i])
end
drawer_small.draw_text("Bar Chart (top rounded)", 400, row_y + 170)

# Custom corners
rect = CrImage.rect(620, row_y + 60, 720, row_y + 140)
radii = CrImage::Draw::CornerRadii.new(top_left: 20, top_right: 5, bottom_right: 20, bottom_left: 5)
CrImage::Draw.rounded_rect(img, rect, radii,
  fill: CrImage::Color.rgb(255, 152, 0),
  stroke: CrImage::Color.rgb(230, 81, 0), stroke_thickness: 2)
drawer_small.draw_text("Custom corners", 630, row_y + 160)

# Arrows
draw_title(img, "7. Arrow Heads", 770, row_y + 20, face_title)

arrow_types = [
  {CrImage::Draw::ArrowHeadType::Triangle, "Triangle"},
  {CrImage::Draw::ArrowHeadType::Open, "Open"},
  {CrImage::Draw::ArrowHeadType::Stealth, "Stealth"},
  {CrImage::Draw::ArrowHeadType::Circle, "Circle"},
  {CrImage::Draw::ArrowHeadType::Diamond, "Diamond"},
]

y_off = row_y + 55
arrow_types.each_with_index do |(head_type, name), i|
  style = CrImage::Draw::ArrowStyle.new(CrImage::Color::BLACK, thickness: 2,
    head_type: head_type, head_size: 12)
  CrImage::Draw.arrow(img, CrImage.point(780, y_off), CrImage.point(900, y_off), style)
  drawer_small.draw_text(name, 910, y_off + 4)
  y_off += 25
end

# Double arrow
style = CrImage::Draw::ArrowStyle.double(CrImage::Color.rgb(0, 100, 200), thickness: 2, head_size: 10)
CrImage::Draw.arrow(img, CrImage.point(1000, row_y + 80), CrImage.point(1150, row_y + 80), style)
drawer_small.draw_text("Double", 1050, row_y + 100)

# ============================================================================
# ROW 3: Markers, Text on Curves, Annotations
# ============================================================================
row_y = 430
puts "3. Drawing markers, curved text, annotations..."

draw_title(img, "8. Scatter Plot Markers", 20, row_y + 20, face_title)

marker_types = [
  CrImage::Draw::MarkerType::Circle,
  CrImage::Draw::MarkerType::Square,
  CrImage::Draw::MarkerType::Diamond,
  CrImage::Draw::MarkerType::Triangle,
  CrImage::Draw::MarkerType::TriangleDown,
  CrImage::Draw::MarkerType::Cross,
  CrImage::Draw::MarkerType::Plus,
  CrImage::Draw::MarkerType::Star,
]

colors = [CrImage::Color::RED, CrImage::Color::BLUE, CrImage::Color::GREEN,
          CrImage::Color.rgb(255, 152, 0), CrImage::Color.rgb(156, 39, 176),
          CrImage::Color::BLACK, CrImage::Color.rgb(0, 150, 136), CrImage::Color.rgb(255, 193, 7)]

x_off = 40
marker_types.each_with_index do |mtype, i|
  style = CrImage::Draw::MarkerStyle.filled(mtype, colors[i], size: 14)
  CrImage::Draw.marker(img, CrImage.point(x_off, row_y + 70), style)

  # Outlined version below
  style2 = CrImage::Draw::MarkerStyle.outlined(mtype, colors[i], size: 14, thickness: 2)
  CrImage::Draw.marker(img, CrImage.point(x_off, row_y + 100), style2)

  x_off += 35
end
drawer_small.draw_text("Filled", 20, row_y + 75)
drawer_small.draw_text("Outlined", 20, row_y + 105)

# Scatter plot simulation
draw_title(img, "Scatter Plot", 20, row_y + 130, face_small)
scatter_points = [
  CrImage.point(50, row_y + 180), CrImage.point(80, row_y + 160),
  CrImage.point(120, row_y + 175), CrImage.point(160, row_y + 150),
  CrImage.point(200, row_y + 165), CrImage.point(240, row_y + 145),
]
style = CrImage::Draw::MarkerStyle.filled_outlined(
  CrImage::Draw::MarkerType::Circle,
  fill: CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 200_u8),
  stroke: CrImage::Color.rgb(25, 118, 210), size: 10, thickness: 2)
CrImage::Draw.markers(img, scatter_points, style)

# Text on curves
draw_title(img, "9. Text Along Curves", 320, row_y + 20, face_title)

# Arc text (pie chart label style) - offset outward from arc
center = CrImage.point(420, row_y + 130)
CrImage::Draw.text_on_arc(img, "CURVED LABEL", center, 70,
  -::Math::PI * 0.8, -::Math::PI * 0.2, face_label, CrImage::Color.rgb(0, 100, 180),
  text_offset: -15) # Negative = toward center (above the arc for top arcs)

# Draw arc for reference
arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color.rgba(180_u8, 180_u8, 180_u8, 255_u8), thickness: 2)
CrImage::Draw.arc(img, center, 70, -::Math::PI * 0.8, -::Math::PI * 0.2, arc_style)

# Bezier curve text - offset above the curve
curve = CrImage::Draw::CubicBezier.new(
  {530.0, (row_y + 100).to_f64}, {600.0, (row_y + 50).to_f64},
  {680.0, (row_y + 150).to_f64}, {750.0, (row_y + 100).to_f64}
)
# Draw curve for reference
bezier_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(180_u8, 180_u8, 180_u8, 255_u8), thickness: 2)
CrImage::Draw.cubic_bezier(img,
  CrImage.point(530, row_y + 100), CrImage.point(600, row_y + 50),
  CrImage.point(680, row_y + 150), CrImage.point(750, row_y + 100), bezier_style)

CrImage::Draw.text_on_curve(img, "Bezier Text", curve, face_label, CrImage::Color.rgb(180, 0, 100),
  text_offset: -18) # Negative = above the curve

# Annotations
draw_title(img, "10. Annotations", 800, row_y + 20, face_title)

# Callout
callout_style = CrImage::Draw::CalloutStyle.new(
  background: CrImage::Color.rgb(255, 255, 200),
  border: CrImage::Color.rgb(200, 150, 0),
  corner_radius: 5, padding: 8)
CrImage::Draw.callout(img, "Important!", CrImage.point(900, row_y + 70),
  CrImage.point(1050, row_y + 130), callout_style, face_small, CrImage::Color::BLACK)

# Target point marker
CrImage::Draw.marker(img, CrImage.point(1050, row_y + 130),
  CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED, size: 8))

# Dimension line
dim_style = CrImage::Draw::DimensionStyle.new(color: CrImage::Color::BLACK, arrow_size: 6)
CrImage::Draw.dimension_line(img, CrImage.point(820, row_y + 170), CrImage.point(980, row_y + 170),
  "160 px", dim_style, face_small, offset: 20)

# Bracket
bracket_style = CrImage::Draw::BracketStyle.new(color: CrImage::Color.rgb(100, 100, 100), thickness: 2)
CrImage::Draw.square_bracket(img, CrImage.point(1020, row_y + 60), CrImage.point(1020, row_y + 160),
  bracket_style, side: :right)
drawer_small.draw_text("Range", 1035, row_y + 115)

# ============================================================================
# ROW 4: Gradient Strokes
# ============================================================================
row_y = 640
puts "4. Drawing gradient strokes..."

draw_title(img, "11. Gradient Strokes", 20, row_y + 20, face_title)

# Gradient line
stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(76, 175, 80)),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(255, 235, 59)),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(244, 67, 54)),
]
CrImage::Draw.stroke_line_gradient(img, CrImage.point(30, row_y + 60), CrImage.point(250, row_y + 60),
  stops, thickness: 6)
drawer_small.draw_text("Gradient Line", 100, row_y + 80)

# Gradient bezier
curve = CrImage::Draw::CubicBezier.new(
  {30.0, (row_y + 130).to_f64}, {100.0, (row_y + 90).to_f64},
  {180.0, (row_y + 170).to_f64}, {250.0, (row_y + 130).to_f64}
)
CrImage::Draw.stroke_bezier_gradient(img, curve, stops, thickness: 5)
drawer_small.draw_text("Gradient Bezier", 100, row_y + 180)

# Gradient arc (progress indicator)
draw_title(img, "Progress Indicators", 300, row_y + 20, face_title)

arc_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(33, 150, 243)),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(156, 39, 176)),
]
CrImage::Draw.stroke_arc_gradient(img, CrImage.point(400, row_y + 120), 50,
  -::Math::PI * 0.75, ::Math::PI * 0.5, arc_stops, thickness: 8)

# Background arc
bg_arc = CrImage::Draw::ArcStyle.new(CrImage::Color.rgb(230, 230, 230), thickness: 8)
CrImage::Draw.arc(img, CrImage.point(400, row_y + 120), 50,
  ::Math::PI * 0.5, ::Math::PI * 1.25, bg_arc)

drawer_small.draw_text("75%", 385, row_y + 125)

# Gradient path
draw_title(img, "Gradient Path Stroke", 500, row_y + 20, face_title)

path = CrImage::Draw::Path.new
  .move_to(520, row_y + 140)
  .bezier_to(570, row_y + 60, 670, row_y + 60, 720, row_y + 100)
  .bezier_to(770, row_y + 140, 820, row_y + 80, 870, row_y + 120)

intensity_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(0, 200, 83)),
  CrImage::Draw::ColorStop.new(0.3, CrImage::Color.rgb(100, 221, 23)),
  CrImage::Draw::ColorStop.new(0.6, CrImage::Color.rgb(255, 214, 0)),
  CrImage::Draw::ColorStop.new(0.8, CrImage::Color.rgb(255, 109, 0)),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(213, 0, 0)),
]
CrImage::Draw.stroke_path_gradient(img, path, intensity_stops, thickness: 4)
drawer_small.draw_text("Value intensity line chart", 620, row_y + 170)

# Gauge chart with gradient ring
draw_title(img, "Gauge Chart", 920, row_y + 20, face_title)

gauge_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(76, 175, 80)),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(255, 235, 59)),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(244, 67, 54)),
]
gauge_gradient = CrImage::Draw::ConicGradient.new(
  CrImage.point(1020, row_y + 120), gauge_stops,
  start_angle: -::Math::PI * 0.75)
CrImage::Draw.fill_conic_ring(img, CrImage.point(1020, row_y + 120), 35, 55, gauge_gradient,
  start_angle: -::Math::PI * 0.75, end_angle: ::Math::PI * 0.75)

# Gauge needle
needle_angle = -::Math::PI * 0.75 + ::Math::PI * 1.5 * 0.65 # 65%
needle_x = (1020 + 45 * ::Math.cos(needle_angle)).round.to_i
needle_y = (row_y + 120 + 45 * ::Math.sin(needle_angle)).round.to_i
CrImage::Draw.line(img, CrImage.point(1020, row_y + 120), CrImage.point(needle_x, needle_y),
  CrImage::Draw::LineStyle.new(CrImage::Color::BLACK, thickness: 3))
CrImage::Draw.circle(img, CrImage.point(1020, row_y + 120), 8,
  CrImage::Draw::CircleStyle.new(CrImage::Color::BLACK, fill: true))

drawer_small.draw_text("65%", 1005, row_y + 180)

# ============================================================================
# Footer
# ============================================================================
footer_y = HEIGHT - 40
CrImage::Draw.line(img, CrImage.point(20, footer_y - 10), CrImage.point(WIDTH - 20, footer_y - 10),
  CrImage::Draw::LineStyle.new(CrImage::Color.rgb(200, 200, 200)))

drawer_label.draw_text("CrImage Charting Features Demo - All features for building charts without external dependencies",
  20, footer_y + 5)

# Save output
output_path = "output/charting_features_demo.png"
Dir.mkdir_p("output")
CrImage::PNG.write(output_path, img)

puts "\n✓ Saved to #{output_path}"
puts "\nFeatures demonstrated:"
puts "  1. Bezier bands (Sankey diagrams)"
puts "  2. Path builder with fill/stroke"
puts "  3. Gradient fills for polygons"
puts "  4. Blend modes (multiply, screen)"
puts "  5. Pattern fills (accessibility)"
puts "  6. Per-corner rounded rectangles"
puts "  7. Arrow heads (6 types)"
puts "  8. Scatter plot markers (8 types)"
puts "  9. Text along curves/arcs"
puts "  10. Annotations (callouts, dimensions, brackets)"
puts "  11. Gradient strokes (lines, arcs, paths)"
