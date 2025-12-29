# Chart Helpers Demo
# Demonstrates charting-related features in CrImage
#
# Features shown:
# 1. Pattern fills for pie/ring (accessibility)
# 2. Color utilities
# 3. Chart legend and color scale
# 4. Thick curves (KDE lines)
# 5. Axes with ticks

require "../src/crimage"

# Load font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 14.0)
face_small = FreeType::TrueType.new_face(font, 10.0)
face_title = FreeType::TrueType.new_face(font, 18.0)

# Create canvas
img = CrImage.rgba(900, 700, CrImage::Color::WHITE)

# Helper to draw section titles
def draw_title(img, text, x, y, face)
  drawer = CrImage::Font::Drawer.new(img, CrImage::Uniform.new(CrImage::Color::BLACK), face)
  drawer.draw_text(text, x, y)
end

# =============================================================================
# Section 1: Pattern Fills for Pie/Ring (Accessibility)
# =============================================================================
draw_title(img, "1. Pattern Fills for Pie/Ring (Accessibility)", 20, 30, face_title)

center = CrImage.point(120, 130)
radius = 70

# Pie chart with patterns (accessible without color)
patterns = [
  CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6, thickness: 2),
  CrImage::Draw::Pattern.crosshatch(CrImage::Color::RED, spacing: 8, thickness: 1),
  CrImage::Draw::Pattern.dots(CrImage::Color::GREEN, spacing: 6, size: 2),
  CrImage::Draw::Pattern.horizontal(CrImage::Color::PURPLE, spacing: 5, thickness: 2),
]

angles = [0.0, Math::PI * 0.5, Math::PI, Math::PI * 1.5, Math::PI * 2]
patterns.each_with_index do |pattern, i|
  CrImage::Draw.fill_pie_pattern(img, center, radius, angles[i], angles[i + 1], pattern)
  # Draw outline
  arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color::BLACK, thickness: 1)
  CrImage::Draw.arc(img, center, radius, angles[i], angles[i + 1], arc_style)
end

# Donut chart with patterns
center2 = CrImage.point(300, 130)
inner_r = 35
outer_r = 70

patterns.each_with_index do |pattern, i|
  CrImage::Draw.fill_ring_pattern(img, center2, inner_r, outer_r, angles[i], angles[i + 1], pattern)
  # Draw outlines
  arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color::BLACK, thickness: 1)
  CrImage::Draw.arc(img, center2, outer_r, angles[i], angles[i + 1], arc_style)
  CrImage::Draw.arc(img, center2, inner_r, angles[i], angles[i + 1], arc_style)
end

# Labels
drawer = CrImage::Font::Drawer.new(img, CrImage::Uniform.new(CrImage::Color::BLACK), face_small)
drawer.draw_text("Pie with patterns", 70, 215)
drawer.draw_text("Donut with patterns", 240, 215)

# =============================================================================
# Section 2: Color Utilities
# =============================================================================
draw_title(img, "2. Color Utilities", 420, 30, face_title)

# Show color interpolation
start_color = CrImage::Color::BLUE
end_color = CrImage::Color::RED
y_pos = 60

drawer.draw_text("Color.interpolate:", 420, y_pos)
10.times do |i|
  t = i / 9.0
  color = CrImage::Color.interpolate(start_color, end_color, t)
  rect = CrImage.rect(420 + i * 25, y_pos + 5, 420 + i * 25 + 22, y_pos + 25)
  CrImage::Draw.rectangle(img, rect, CrImage::Draw::RectStyle.new(fill_color: color))
end

# Show luminance-based contrast
y_pos += 50
drawer.draw_text("Color.contrasting (auto text color):", 420, y_pos)
bg_colors = [
  CrImage::Color::WHITE,
  CrImage::Color.rgb(200, 200, 200),
  CrImage::Color.rgb(100, 100, 100),
  CrImage::Color::BLACK,
  CrImage::Color::BLUE,
  CrImage::Color::YELLOW,
]

bg_colors.each_with_index do |bg, i|
  x = 420 + i * 45
  rect = CrImage.rect(x, y_pos + 5, x + 42, y_pos + 30)
  CrImage::Draw.rectangle(img, rect, CrImage::Draw::RectStyle.new(fill_color: bg, outline_color: CrImage::Color::BLACK))

  text_color = CrImage::Color.contrasting(bg)
  text_drawer = CrImage::Font::Drawer.new(img, CrImage::Uniform.new(text_color), face_small)
  text_drawer.draw_text("Txt", x + 8, y_pos + 22)
end

# Show lighten/darken
y_pos += 50
drawer.draw_text("Color.lighten / darken:", 420, y_pos)
base = CrImage::Color::BLUE
[-0.4, -0.2, 0.0, 0.2, 0.4].each_with_index do |amount, i|
  color = amount < 0 ? CrImage::Color.darken(base, -amount) : CrImage::Color.lighten(base, amount)
  rect = CrImage.rect(420 + i * 35, y_pos + 5, 420 + i * 35 + 32, y_pos + 25)
  CrImage::Draw.rectangle(img, rect, CrImage::Draw::RectStyle.new(fill_color: color))
end

# =============================================================================
# Section 3: Chart Legend and Color Scale
# =============================================================================
draw_title(img, "3. Chart Legend & Color Scale", 20, 250, face_title)

# Legend box
items = [
  CrImage::Draw::LegendItem.new("Sales", CrImage::Color::BLUE),
  CrImage::Draw::LegendItem.new("Costs", CrImage::Color::RED),
  CrImage::Draw::LegendItem.new("Profit", CrImage::Color::GREEN),
]

legend_style = CrImage::Draw::LegendStyle.new(
  background: CrImage::Color.rgb(245, 245, 245),
  border_color: CrImage::Color::GRAY,
  text_color: CrImage::Color::BLACK,
  swatch_size: 14,
  padding: 6,
  orientation: :vertical
)

CrImage::Draw.legend_box(img, CrImage.point(20, 270), items, legend_style, face_small)

# Horizontal legend
h_legend_style = CrImage::Draw::LegendStyle.new(
  background: CrImage::Color.rgb(245, 245, 245),
  border_color: CrImage::Color::GRAY,
  text_color: CrImage::Color::BLACK,
  swatch_size: 12,
  padding: 5,
  orientation: :horizontal
)
CrImage::Draw.legend_box(img, CrImage.point(130, 270), items, h_legend_style, face_small)

# Color scale (heatmap legend)
gradient = CrImage::Draw::LinearGradient.new(
  CrImage.point(0, 0), CrImage.point(150, 0),
  [
    CrImage::Draw::ColorStop.new(0.0, CrImage::Color::BLUE),
    CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
    CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
  ]
)

scale_style = CrImage::Draw::ColorScaleStyle.new(
  width: 150,
  height: 15,
  orientation: :horizontal,
  show_labels: true,
  label_count: 5,
  font_size: 9
)

drawer.draw_text("Color Scale:", 20, 360)
CrImage::Draw.color_scale(img, CrImage.point(20, 370), 0.0, 100.0, gradient, scale_style, face_small)

# =============================================================================
# Section 4: Thick Curves (KDE Lines)
# =============================================================================
draw_title(img, "4. Thick Curves (KDE Lines)", 420, 250, face_title)

# Simulate KDE curve points
kde_points = [] of CrImage::Point
20.times do |i|
  x = 420 + i * 20
  # Simulate a bell curve
  t = (i - 10) / 5.0
  y = (320 - 50 * Math.exp(-t * t)).to_i
  kde_points << CrImage.point(x, y)
end

# Draw thick curve (the new method for smooth thick curves)
CrImage::Draw.thick_curve(img, kde_points, CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 200_u8), 6, tension: 0.5)

# Draw thin reference
thin_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(200_u8, 50_u8, 50_u8, 255_u8), thickness: 1)
CrImage::Draw.spline(img, kde_points, thin_style, tension: 0.5)

drawer.draw_text("Blue: thick_curve (6px), Red: spline (1px)", 420, 340)

# Compare with old method (multiple offset lines - shows gaps)
drawer.draw_text("Old workaround (offset lines - has gaps):", 420, 370)
base_y = 420
kde_points2 = kde_points.map { |p| CrImage.point(p.x, p.y + 80) }

# Simulate the old workaround
half_width = 2
(-half_width..half_width).each do |offset_y|
  (-half_width..half_width).each do |offset_x|
    offset_points = kde_points2.map { |p| CrImage.point(p.x + offset_x, p.y + offset_y) }
    thin_style2 = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(100_u8, 100_u8, 100_u8, 50_u8), thickness: 1)
    CrImage::Draw.spline(img, offset_points, thin_style2, tension: 0.5)
  end
end

# =============================================================================
# Section 5: Axes with Ticks
# =============================================================================
draw_title(img, "5. Axes with Ticks and Grid", 20, 450, face_title)

# Chart area
chart_x = 70
chart_y = 480
chart_w = 300
chart_h = 180

# Draw chart background
chart_rect = CrImage.rect(chart_x, chart_y, chart_x + chart_w, chart_y + chart_h)
CrImage::Draw.rectangle(img, chart_rect, CrImage::Draw::RectStyle.new(fill_color: CrImage::Color.rgb(250, 250, 250)))

axis_style = CrImage::Draw::AxisStyle.new(
  color: CrImage::Color::BLACK,
  tick_length: 5,
  tick_count: 6,
  show_grid: true,
  grid_color: CrImage::Color.rgb(220, 220, 220),
  font_size: 9
)

# X axis
CrImage::Draw.x_axis(img,
  CrImage.point(chart_x, chart_y + chart_h),
  CrImage.point(chart_x + chart_w, chart_y + chart_h),
  0.0, 100.0, axis_style, face_small, chart_height: chart_h)

# Y axis
CrImage::Draw.y_axis(img,
  CrImage.point(chart_x, chart_y + chart_h),
  CrImage.point(chart_x, chart_y),
  0.0, 50.0, axis_style, face_small, chart_width: chart_w)

# Draw some sample data points
data = [{10, 15}, {25, 35}, {40, 25}, {55, 40}, {70, 30}, {85, 45}]
marker_style = CrImage::Draw::MarkerStyle.filled_outlined(
  CrImage::Draw::MarkerType::Circle,
  fill: CrImage::Color::BLUE,
  stroke: CrImage::Color::BLACK,
  size: 6
)

data.each do |dx, dy|
  px = chart_x + (dx * chart_w / 100).to_i
  py = chart_y + chart_h - (dy * chart_h / 50).to_i
  CrImage::Draw.marker(img, CrImage.point(px, py), marker_style)
end

# Data labels
CrImage::Draw.data_label(img, "Peak", CrImage.point(chart_x + 255, chart_y + 35), face_small, 9,
  CrImage::Color::BLACK, background: CrImage::Color::WHITE, padding: 2)

# =============================================================================
# Section 6: Bezier Band
# =============================================================================
draw_title(img, "6. Bezier Band", 500, 450, face_title)

# Show the fixed bezier band (was showing checkered pattern before)
top1 = {
  CrImage.point(500, 500),
  CrImage.point(580, 480),
  CrImage.point(700, 520),
  CrImage.point(780, 500),
}

bottom1 = {
  CrImage.point(500, 550),
  CrImage.point(580, 530),
  CrImage.point(700, 570),
  CrImage.point(780, 550),
}

CrImage::Draw.fill_bezier_band(img, top1, bottom1,
  CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 180_u8), segments: 40, anti_alias: true)

top2 = {
  CrImage.point(500, 560),
  CrImage.point(600, 600),
  CrImage.point(700, 580),
  CrImage.point(780, 620),
}

bottom2 = {
  CrImage.point(500, 600),
  CrImage.point(600, 640),
  CrImage.point(700, 620),
  CrImage.point(780, 660),
}

CrImage::Draw.fill_bezier_band(img, top2, bottom2,
  CrImage::Color.rgba(234_u8, 67_u8, 53_u8, 180_u8), segments: 40, anti_alias: true)

drawer.draw_text("Smooth fills (no checkered pattern)", 500, 680)

# Save
CrImage::PNG.write("output/chart_helpers_demo.png", img)
puts "Saved to output/chart_helpers_demo.png"
