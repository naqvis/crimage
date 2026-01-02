# Drawing & Text Guide

Comprehensive guide to drawing primitives, gradients, and text rendering.

## Creating Images

```crystal
require "crimage"

# Solid color background
img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
img = CrImage.rgba(400, 300, CrImage::Color.rgb(200, 220, 240))

# Transparent background
img = CrImage.rgba(400, 300, CrImage::Color::TRANSPARENT)

# Grayscale
gray = CrImage.gray(400, 300)

# Checkerboard (transparency background)
checker = CrImage.checkerboard(400, 300, cell_size: 16)

# Gradient
gradient = CrImage.gradient(400, 300, CrImage::Color::RED, CrImage::Color::BLUE, :horizontal)
```

## Lines

```crystal
# Basic line
img.draw_line(0, 0, 400, 300, color: CrImage::Color::RED)

# With thickness
img.draw_line(50, 50, 350, 50, color: CrImage::Color::BLUE, thickness: 3)

# Anti-aliased (thin)
img.draw_line(50, 100, 350, 200, color: CrImage::Color::GREEN, anti_alias: true)

# Thick anti-aliased line (smooth edges with thickness)
style = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 5, anti_alias: true)
CrImage::Draw.line(img, CrImage::Point.new(50, 150), CrImage::Point.new(350, 250), style)

# Polyline - connected line segments through multiple points
points = [CrImage.point(10, 10), CrImage.point(50, 80), CrImage.point(90, 20), CrImage.point(130, 60)]
style = CrImage::Draw::LineStyle.new(CrImage::Color::BLUE, thickness: 2)
CrImage::Draw.polyline(img, points, style)

# Dashed line
dash_style = CrImage::Draw::DashedLineStyle.new(
  CrImage::Color::RED,
  dash_length: 10,
  gap_length: 5,
  thickness: 2
)
CrImage::Draw.dashed_line(img, CrImage::Point.new(50, 150), CrImage::Point.new(350, 150), dash_style)

# Presets
dotted = CrImage::Draw::DashedLineStyle.dotted(CrImage::Color::BLUE)
dashed = CrImage::Draw::DashedLineStyle.dashed(CrImage::Color::GREEN)
```

## Circles and Ellipses

```crystal
# Circle outline
img.draw_circle(200, 150, 50, color: CrImage::Color::BLUE)

# Filled circle
img.draw_circle(200, 150, 50, color: CrImage::Color::BLUE, fill: true)

# Anti-aliased
img.draw_circle(200, 150, 50, color: CrImage::Color::BLUE, anti_alias: true)

# Thick outline
circle_style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED).with_thickness(5)
CrImage::Draw.circle(img, CrImage::Point.new(200, 150), 50, circle_style)

# Ellipse
img.draw_ellipse(200, 150, 80, 50, color: CrImage::Color::GREEN, fill: true)

# Circle with blend mode
style = CrImage::Draw::CircleStyle.new(CrImage::Color.rgba(255, 0, 0, 200))
  .with_fill(true)
  .with_blend_mode(CrImage::Draw::BlendMode::Multiply)
CrImage::Draw.circle(img, CrImage::Point.new(200, 150), 50, style)
```

## Rectangles

```crystal
# Outline only
img.draw_rect(50, 50, 100, 80, stroke: CrImage::Color::BLACK)

# Filled
img.draw_rect(50, 50, 100, 80, fill: CrImage::Color::YELLOW)

# Both
img.draw_rect(50, 50, 100, 80, stroke: CrImage::Color::BLACK, fill: CrImage::Color::YELLOW)

# Rounded corners
style = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::BLUE,
  outline_color: CrImage::Color::BLACK,
  corner_radius: 20
)
CrImage::Draw.rectangle(img, CrImage.rect(50, 50, 150, 130), style)
```

## Polygons

```crystal
# Triangle
points = [
  CrImage::Point.new(200, 50),
  CrImage::Point.new(250, 150),
  CrImage::Point.new(150, 150)
]
img.draw_polygon(points, outline: CrImage::Color::RED, fill: CrImage::Color::RED)

# Regular polygons
style = CrImage::Draw::PolygonStyle.new(
  fill_color: CrImage::Color::BLUE,
  outline_color: CrImage::Color::BLACK
)

CrImage::Draw.triangle(img, CrImage::Point.new(80, 80), 40, style)
CrImage::Draw.pentagon(img, CrImage::Point.new(200, 80), 40, style)
CrImage::Draw.hexagon(img, CrImage::Point.new(320, 80), 40, style)
CrImage::Draw.regular_polygon(img, CrImage::Point.new(440, 80), 40, 8, style)  # Octagon
```

## Arcs and Pie Slices

```crystal
# Arc (portion of circle outline)
arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color::PURPLE, thickness: 3)
CrImage::Draw.arc(img, CrImage::Point.new(200, 100), 50, 0.0, Math::PI, arc_style)

# Pie slice (filled arc)
pie_style = CrImage::Draw::ArcStyle.new(CrImage::Color::ORANGE, fill: true)
CrImage::Draw.pie(img, CrImage::Point.new(200, 200), 60, 0.0, Math::PI / 2, pie_style)

# Ring slice (donut segment) - great for donut charts
ring_style = CrImage::Draw::RingStyle.new(CrImage::Color::BLUE, fill: true)
CrImage::Draw.ring_slice(img, CrImage::Point.new(200, 200), 30, 60, 0.0, Math::PI / 2, ring_style)

# Full donut
CrImage::Draw.ring_slice(img, CrImage::Point.new(200, 200), 40, 80, 0.0, 2 * Math::PI, ring_style)

# Anti-aliased ring slice
aa_ring_style = CrImage::Draw::RingStyle.new(CrImage::Color::RED, fill: true, anti_alias: true)
CrImage::Draw.ring_slice(img, CrImage::Point.new(200, 200), 30, 60, 0.0, Math::PI, aa_ring_style)
```

## Bézier Curves

```crystal
bezier_style = CrImage::Draw::BezierStyle.new(CrImage::Color::GREEN, thickness: 2)

# Quadratic (one control point)
CrImage::Draw.quadratic_bezier(img,
  CrImage::Point.new(50, 200),   # start
  CrImage::Point.new(150, 100),  # control
  CrImage::Point.new(250, 200),  # end
  bezier_style
)

# Cubic (two control points)
CrImage::Draw.cubic_bezier(img,
  CrImage::Point.new(270, 200),  # start
  CrImage::Point.new(320, 100),  # control 1
  CrImage::Point.new(380, 300),  # control 2
  CrImage::Point.new(450, 200),  # end
  bezier_style
)

# Spline through points
points = [
  CrImage::Point.new(50, 300),
  CrImage::Point.new(150, 250),
  CrImage::Point.new(250, 300),
  CrImage::Point.new(350, 250),
]
CrImage::Draw.spline(img, points, bezier_style, tension: 0.5)

# Flatten spline to points (for fills, hit testing, clipping paths)
control_points = [CrImage.point(10, 50), CrImage.point(50, 20), CrImage.point(90, 60)]
curve_points = CrImage::Draw.spline_flatten(control_points, tension: 0.5)
# curve_points is an Array(Point) of interpolated positions along the curve
```

## Paths (SVG-like)

Build complex shapes with lines and curves using the Path builder:

```crystal
# Create a path with bezier curves
path = CrImage::Draw::Path.new
  .move_to(100, 50)
  .bezier_to(150, 50, 200, 100, 200, 150)  # cubic bezier
  .line_to(200, 200)
  .line_to(100, 200)
  .close

# Fill the path
CrImage::Draw.fill_path(img, path, CrImage::Color::BLUE)

# Or stroke the outline
style = CrImage::Draw::PathStyle.new(CrImage::Color::RED, thickness: 2)
CrImage::Draw.stroke_path(img, path, style)

# Anti-aliased fill for smooth edges
CrImage::Draw.fill_path_aa(img, path, CrImage::Color::GREEN)
```

### Path Commands

```crystal
path = CrImage::Draw::Path.new
  .move_to(x, y)                           # Move without drawing
  .line_to(x, y)                           # Straight line
  .quadratic_to(cx, cy, x, y)              # Quadratic bezier (1 control point)
  .bezier_to(c1x, c1y, c2x, c2y, x, y)     # Cubic bezier (2 control points)
  .cubic_to(c1x, c1y, c2x, c2y, x, y)      # Alias for bezier_to
  .close                                    # Close path to start point
```

## Bezier Bands (Sankey Diagrams)

Fill the area between two bezier curves - perfect for Sankey diagrams and flow charts:

```crystal
# Define top and bottom curves
top_curve = {
  CrImage.point(50, 100),   # start
  CrImage.point(150, 80),   # control 1
  CrImage.point(250, 80),   # control 2
  CrImage.point(350, 100),  # end
}

bottom_curve = {
  CrImage.point(50, 150),   # start
  CrImage.point(150, 170),  # control 1
  CrImage.point(250, 170),  # control 2
  CrImage.point(350, 150),  # end
}

# Fill the band between curves
CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve, CrImage::Color::BLUE)

# With anti-aliasing for smooth edges
CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve, CrImage::Color::BLUE,
  segments: 64, anti_alias: true)

# Using float coordinates for precision
top = {{50.0, 100.0}, {150.0, 80.0}, {250.0, 80.0}, {350.0, 100.0}}
bottom = {{50.0, 150.0}, {150.0, 170.0}, {250.0, 170.0}, {350.0, 150.0}}
CrImage::Draw.fill_bezier_band(img, top, bottom, CrImage::Color::GREEN)
```

### Sankey Diagram Example

```crystal
# Multiple flow bands with different colors
flows = [
  {top: {...}, bottom: {...}, color: CrImage::Color.rgba(66, 133, 244, 200)},
  {top: {...}, bottom: {...}, color: CrImage::Color.rgba(234, 67, 53, 200)},
  {top: {...}, bottom: {...}, color: CrImage::Color.rgba(52, 168, 83, 200)},
]

flows.each do |flow|
  CrImage::Draw.fill_bezier_band(img, flow[:top], flow[:bottom], flow[:color],
    anti_alias: true)
end
```

## Anti-aliased Polygon Fill

Fill polygons with smooth anti-aliased edges:

```crystal
points = [
  CrImage.point(100, 50),
  CrImage.point(180, 80),
  CrImage.point(200, 150),
  CrImage.point(120, 180),
  CrImage.point(50, 120),
]

# Standard fill (jagged edges)
CrImage::Draw.polygon(img, points, CrImage::Draw::PolygonStyle.new(fill_color: CrImage::Color::RED))

# Anti-aliased fill (smooth edges)
CrImage::Draw.fill_polygon_aa(img, points, CrImage::Color::BLUE)
```

## Gradient Fills for Shapes

Fill polygons and paths with gradients (not just rectangles):

```crystal
# Triangle with linear gradient
points = [
  CrImage.point(200, 50),
  CrImage.point(350, 200),
  CrImage.point(50, 200),
]

gradient = CrImage::Draw::LinearGradient.new(
  CrImage.point(50, 50),
  CrImage.point(350, 200),
  [
    CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
    CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
    CrImage::Draw::ColorStop.new(1.0, CrImage::Color::GREEN),
  ]
)

CrImage::Draw.fill_polygon_gradient(img, points, gradient)

# Path with radial gradient
path = CrImage::Draw::Path.new
  .move_to(100, 100)
  .bezier_to(150, 50, 250, 50, 300, 100)
  .line_to(300, 200)
  .line_to(100, 200)
  .close

radial = CrImage::Draw::RadialGradient.new(
  CrImage.point(200, 150),
  100,
  [
    CrImage::Draw::ColorStop.new(0.0, CrImage::Color::WHITE),
    CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
  ]
)

CrImage::Draw.fill_path_gradient(img, path, radial)
```

## Blend Modes

Control how overlapping semi-transparent shapes combine:

```crystal
# Available blend modes
# - Normal    : Standard alpha compositing
# - Multiply  : Darkens (result = src * dst)
# - Screen    : Lightens (result = 1 - (1-src) * (1-dst))
# - Overlay   : Combines multiply and screen
# - SoftLight : Gentle lighting effect

# Fill circle with blend mode
style = CrImage::Draw::CircleStyle.new(CrImage::Color.rgba(255, 0, 0, 180))
  .with_fill(true)
  .with_blend_mode(CrImage::Draw::BlendMode::Multiply)
CrImage::Draw.circle(img, CrImage.point(100, 100), 50, style)

# Fill rectangle with blend mode
rect_style = CrImage::Draw::RectStyle.new
  .with_fill(CrImage::Color.rgba(0, 0, 255, 180))
  .with_blend_mode(CrImage::Draw::BlendMode::Screen)
CrImage::Draw.rectangle(img, CrImage.rect(50, 50, 150, 150), rect_style)

# Fill polygon with blend mode (via style)
poly_style = CrImage::Draw::PolygonStyle.new
  .with_fill(CrImage::Color.rgba(0, 255, 0, 180))
  .with_blend_mode(CrImage::Draw::BlendMode::Overlay)
CrImage::Draw.polygon(img, points, poly_style)

# Fill polygon with blend mode (direct function)
CrImage::Draw.fill_polygon_blended(img, points, color, CrImage::Draw::BlendMode::Multiply)

# Fill path with blend mode
path = CrImage::Draw::Path.new.move_to(...)...
CrImage::Draw.fill_path_blended(img, path, color, CrImage::Draw::BlendMode::Screen)
```

## Pattern Fills (Hatching)

Fill shapes with patterns for accessibility - distinguishes elements without relying on color:

```crystal
# Available pattern types
# - Solid, HorizontalLines, VerticalLines
# - DiagonalUp, DiagonalDown
# - Crosshatch, DiagonalCross
# - Dots

# Preset patterns
pattern = CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6, thickness: 2)
pattern = CrImage::Draw::Pattern.crosshatch(CrImage::Color::RED, spacing: 8)
pattern = CrImage::Draw::Pattern.dots(CrImage::Color::BLACK, spacing: 8, size: 2)
pattern = CrImage::Draw::Pattern.horizontal(CrImage::Color::GREEN, spacing: 4)

# Fill polygon with pattern
CrImage::Draw.fill_polygon_pattern(img, points, pattern)

# Fill rectangle with pattern
CrImage::Draw.fill_rect_pattern(img, rect, pattern)

# Fill path with pattern
CrImage::Draw.fill_path_pattern(img, path, pattern)

# Fill pie slice with pattern (accessible pie charts)
CrImage::Draw.fill_pie_pattern(img, center, radius, start_angle, end_angle, pattern)

# Fill ring/donut slice with pattern (accessible donut charts)
CrImage::Draw.fill_ring_pattern(img, center, inner_radius, outer_radius,
  start_angle, end_angle, pattern)

# Pattern with background color
pattern = CrImage::Draw::Pattern.new(
  CrImage::Draw::PatternType::DiagonalUp,
  CrImage::Color::BLACK,
  background: CrImage::Color::YELLOW,
  spacing: 6,
  thickness: 2
)
```

## Thick Curves (KDE Lines, Smooth Strokes)

Draw thick anti-aliased curves without gaps or artifacts:

```crystal
# Thick bezier curves (thickness > 2 with anti_alias: true uses offset curve polygon)
style = CrImage::Draw::BezierStyle.new(CrImage::Color::BLUE, thickness: 5, anti_alias: true)
CrImage::Draw.cubic_bezier(img, p0, p1, p2, p3, style)
CrImage::Draw.quadratic_bezier(img, p0, p1, p2, style)

# Thick curve through multiple points (ideal for KDE lines in histograms)
points = [CrImage.point(10, 50), CrImage.point(50, 20), CrImage.point(90, 60), ...]
CrImage::Draw.thick_curve(img, points, CrImage::Color::BLUE, thickness: 4, tension: 0.5)
```

## Chart Helpers

Convenience methods for common chart elements:

### Legend Box

```crystal
items = [
  CrImage::Draw::LegendItem.new("Sales", CrImage::Color::BLUE),
  CrImage::Draw::LegendItem.new("Costs", CrImage::Color::RED),
  CrImage::Draw::LegendItem.new("Profit", CrImage::Color::GREEN),
]

style = CrImage::Draw::LegendStyle.new(
  background: CrImage::Color::WHITE,
  border_color: CrImage::Color::BLACK,
  text_color: CrImage::Color::BLACK,
  swatch_size: 16,
  padding: 8,
  orientation: :vertical  # or :horizontal
)

CrImage::Draw.legend_box(img, CrImage.point(10, 10), items, style, font)
```

### Color Scale (Heatmap Legend)

```crystal
gradient = CrImage::Draw::LinearGradient.new(
  CrImage.point(0, 0), CrImage.point(200, 0),
  [
    CrImage::Draw::ColorStop.new(0.0, CrImage::Color::BLUE),
    CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
    CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
  ]
)

style = CrImage::Draw::ColorScaleStyle.new(
  width: 200,
  height: 20,
  orientation: :horizontal,
  show_labels: true,
  label_count: 5
)

CrImage::Draw.color_scale(img, CrImage.point(10, 10), 0.0, 100.0, gradient, style, font)
```

### Axes with Ticks and Labels

```crystal
axis_style = CrImage::Draw::AxisStyle.new(
  color: CrImage::Color::BLACK,
  tick_length: 5,
  tick_count: 5,
  show_grid: true,
  grid_color: CrImage::Color::GRAY
)

# X axis
CrImage::Draw.x_axis(img, CrImage.point(50, 250), CrImage.point(350, 250),
  0.0, 100.0, axis_style, font, chart_height: 200)

# Y axis
CrImage::Draw.y_axis(img, CrImage.point(50, 250), CrImage.point(50, 50),
  0.0, 100.0, axis_style, font, chart_width: 300)
```

### Data Labels

```crystal
CrImage::Draw.data_label(img, "42.5", CrImage.point(100, 50), font, 12,
  CrImage::Color::BLACK,
  background: CrImage::Color::WHITE,
  padding: 2)
```

## Color Utilities

Public helper methods for color manipulation:

```crystal
# Interpolate between colors (alias for blend)
mid = CrImage::Color.interpolate(CrImage::Color::RED, CrImage::Color::BLUE, 0.5)

# Create color with different alpha
semi = CrImage::Color.with_alpha(CrImage::Color::RED, 128)

# Calculate perceived luminance (0.0 to 1.0)
lum = CrImage::Color.luminance(color)

# Check if color is light or dark
CrImage::Color.light?(color)  # luminance > 0.5
CrImage::Color.dark?(color)   # luminance <= 0.5

# Get contrasting color for text (black or white)
text_color = CrImage::Color.contrasting(background_color)

# Lighten/darken by percentage
lighter = CrImage::Color.lighten(color, 0.2)  # 20% lighter
darker = CrImage::Color.darken(color, 0.2)    # 20% darker
```

## Per-Corner Rounded Rectangles

Control individual corner radii - useful for bar charts with rounded tops:

```crystal
# Uniform corners
radii = CrImage::Draw::CornerRadii.uniform(10)

# Top corners only (bar charts)
radii = CrImage::Draw::CornerRadii.top(10)

# Bottom corners only
radii = CrImage::Draw::CornerRadii.bottom(10)

# Left or right corners
radii = CrImage::Draw::CornerRadii.left(10)
radii = CrImage::Draw::CornerRadii.right(10)

# Custom per-corner
radii = CrImage::Draw::CornerRadii.new(
  top_left: 20,
  top_right: 5,
  bottom_right: 20,
  bottom_left: 5
)

# Draw rounded rectangle
CrImage::Draw.rounded_rect(img, rect, radii,
  fill: CrImage::Color::BLUE,
  stroke: CrImage::Color::BLACK,
  stroke_thickness: 2)
```

## Arrows

Lines with configurable arrow heads for flow diagrams and annotations:

```crystal
# Arrow head types: Triangle, Open, Stealth, Circle, Diamond, Square

# Single arrow (head at end)
style = CrImage::Draw::ArrowStyle.single(CrImage::Color::BLACK, thickness: 2, head_size: 12)
CrImage::Draw.arrow(img, CrImage.point(50, 100), CrImage.point(200, 100), style)

# Double-headed arrow
style = CrImage::Draw::ArrowStyle.double(CrImage::Color::RED, thickness: 2)
CrImage::Draw.arrow(img, start_point, end_point, style)

# Open arrow head (V shape)
style = CrImage::Draw::ArrowStyle.open(CrImage::Color::BLUE)
CrImage::Draw.arrow(img, p1, p2, style)

# Custom arrow style
style = CrImage::Draw::ArrowStyle.new(
  CrImage::Color::BLACK,
  thickness: 3,
  head_type: CrImage::Draw::ArrowHeadType::Stealth,
  head_size: 15,
  head_at_start: false,
  head_at_end: true
)
```

## Markers (Scatter Plot Symbols)

Pre-built marker shapes for scatter plots:

```crystal
# Marker types: Circle, Square, Diamond, Triangle, TriangleDown, Cross, Plus, Star

# Filled marker
style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED, size: 8)

# Outlined marker
style = CrImage::Draw::MarkerStyle.outlined(CrImage::Draw::MarkerType::Square, CrImage::Color::BLUE, size: 10)

# Filled with outline
style = CrImage::Draw::MarkerStyle.filled_outlined(
  CrImage::Draw::MarkerType::Diamond,
  fill: CrImage::Color::YELLOW,
  stroke: CrImage::Color::BLACK,
  size: 12
)

# Draw single marker
CrImage::Draw.marker(img, CrImage.point(100, 50), style)

# Draw multiple markers (scatter plot)
data_points = [CrImage.point(50, 80), CrImage.point(100, 60), CrImage.point(150, 90)]
CrImage::Draw.markers(img, data_points, style)
```

## Text Along Curves

Draw text that follows bezier curves or arcs - useful for circular labels:

```crystal
# Text along a bezier curve (offset above the curve)
curve = CrImage::Draw::CubicBezier.new(
  {50.0, 200.0}, {150.0, 50.0}, {250.0, 50.0}, {350.0, 200.0}
)
CrImage::Draw.text_on_curve(img, "Curved Text!", curve, face, CrImage::Color::BLACK,
  text_offset: -15)  # Negative = above curve

# Text along an arc (for pie/donut chart labels)
CrImage::Draw.text_on_arc(img, "LABEL", center, radius,
  start_angle, end_angle, face, CrImage::Color::BLACK,
  align: :center,    # :start, :center, or :end
  text_offset: -20)  # Negative = toward center (above for top arcs)
```

## Annotation Helpers

Callouts, dimension lines, and brackets for annotating charts:

```crystal
# Callout box with leader line
style = CrImage::Draw::CalloutStyle.new(
  background: CrImage::Color::WHITE,
  border: CrImage::Color::BLACK,
  corner_radius: 5,
  padding: 8
)
CrImage::Draw.callout(img, "Note!", box_position, target_point, style, face, CrImage::Color::BLACK)

# Dimension line with measurements
dim_style = CrImage::Draw::DimensionStyle.new(
  color: CrImage::Color::BLACK,
  arrow_size: 8,
  extension_length: 10
)
CrImage::Draw.dimension_line(img, p1, p2, "100 px", dim_style, face, offset: 25)

# Curly bracket
bracket_style = CrImage::Draw::BracketStyle.new(color: CrImage::Color::BLACK, thickness: 2)
CrImage::Draw.bracket(img, p1, p2, bracket_style, side: :right)

# Square bracket
CrImage::Draw.square_bracket(img, p1, p2, bracket_style, side: :left)
```

## Gradient Strokes

Apply gradients to stroked paths (not just fills):

```crystal
# Gradient along a path (progress indicators, intensity lines)
path = CrImage::Draw::Path.new
  .move_to(50, 100)
  .bezier_to(150, 50, 250, 150, 350, 100)

stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
]

CrImage::Draw.stroke_path_gradient(img, path, stops, thickness: 3)

# Gradient line
CrImage::Draw.stroke_line_gradient(img, p1, p2, stops, thickness: 2)

# Gradient bezier curve
curve = CrImage::Draw::CubicBezier.new(...)
CrImage::Draw.stroke_bezier_gradient(img, curve, stops, thickness: 3)

# Gradient arc (progress indicators)
CrImage::Draw.stroke_arc_gradient(img, center, radius, start_angle, end_angle, stops, thickness: 5)

# Gradient ring (gauge charts)
CrImage::Draw.stroke_ring_gradient(img, center, inner_radius, outer_radius,
  start_angle, end_angle, stops)
```

## Gradients

```crystal
# Define color stops
stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color::GREEN),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE)
]

# Linear gradient
linear = CrImage::Draw::LinearGradient.new(
  CrImage::Point.new(0, 0),      # start
  CrImage::Point.new(400, 0),    # end
  stops
)
CrImage::Draw.fill_linear_gradient(img, img.bounds, linear)

# Radial gradient
radial = CrImage::Draw::RadialGradient.new(
  CrImage::Point.new(200, 150),  # center
  radius: 100,
  stops: stops
)
CrImage::Draw.fill_radial_gradient(img, img.bounds, radial)

# Conic/angular gradient (great for gauges and color wheels)
conic = CrImage::Draw::ConicGradient.new(
  CrImage::Point.new(200, 200),
  stops,
  start_angle: -Math::PI / 2  # Start from top
)
CrImage::Draw.fill_conic_gradient(img, img.bounds, conic)

# Conic gradient in a ring (perfect for gauge charts)
gauge_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(0, 255, 0)),   # Green
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(255, 255, 0)), # Yellow
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(255, 0, 0)),   # Red
]
gauge_gradient = CrImage::Draw::ConicGradient.new(
  CrImage::Point.new(200, 200),
  gauge_stops,
  start_angle: -Math::PI * 0.75
)
CrImage::Draw.fill_conic_ring(img, CrImage::Point.new(200, 200), 60, 100, gauge_gradient,
  start_angle: -Math::PI * 0.75, end_angle: Math::PI * 0.75)
```

## Flood Fill

```crystal
# Fill connected region
filled_count = img.flood_fill(100, 100, CrImage::Color::BLUE, tolerance: 10)

# Replace all instances of a color
result = img.replace_color(CrImage::Color::RED, CrImage::Color::GREEN, tolerance: 10)

# Create selection mask
mask = img.select_by_color(100, 100, tolerance: 10, contiguous: true)
```

## Clipping Regions

Restrict drawing operations to a specific area:

```crystal
img = CrImage.rgba(400, 300, CrImage::Color::WHITE)

# Draw within a clipped region
img.with_clip(50, 50, 200, 150) do |clipped|
  # This circle will be clipped to the 200x150 region
  style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED, fill: true)
  CrImage::Draw.circle(clipped, CrImage::Point.new(100, 100), 80, style)
end

# Using rectangle
plot_area = CrImage.rect(50, 50, 350, 250)
img.with_clip(plot_area) do |clipped|
  # All drawing here is restricted to plot_area
  # Useful for charts where data points shouldn't overflow axes
end
```

---

# Text Rendering

## Loading Fonts

```crystal
require "freetype"

# TrueType
font = FreeType::TrueType.load("path/to/font.ttf")

# OpenType/CFF
font = FreeType::TrueType.load("path/to/font.otf")

# WOFF (auto-decompresses)
woff = FreeType::WOFF.load("path/to/font.woff")
font = woff.to_truetype

# TrueType Collection (multiple fonts)
collection = FreeType::TrueType.load_collection("fonts.ttc")
font1 = collection.font(0)
font2 = collection.font(1)

# Create face at specific size
face = FreeType::TrueType.new_face(font, 48.0)  # 48pt
```

## Basic Text Drawing

```crystal
img = CrImage.rgba(400, 100, CrImage::Color::WHITE)

# Create drawer
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
drawer = CrImage::Font::Drawer.new(img, text_color, face)

# Draw at position (x=20, y=60 baseline)
drawer.draw_text("Hello, World!", 20, 60)

CrImage::PNG.write("text.png", img)
```

## Text with Effects

```crystal
# Shadow
drawer.draw_text("Shadow", 20, 60,
  shadow: true,
  shadow_offset_x: 3,
  shadow_offset_y: 3,
  shadow_blur: 5,
  shadow_color: CrImage::Color.rgba(0, 0, 0, 128)
)

# Outline
drawer.draw_text("Outline", 20, 120,
  outline: true,
  outline_thickness: 2,
  outline_color: CrImage::Color::WHITE
)

# Decorations
drawer.draw_text("Underlined", 20, 180, underline: true)
drawer.draw_text("Strikethrough", 20, 240, strikethrough: true)
drawer.draw_text("Red underline", 20, 300,
  underline: true,
  decoration_color: CrImage::Color::RED
)

# Combined
drawer.draw_text("Fancy", 20, 360,
  shadow: true,
  outline: true,
  underline: true
)
```

## Multi-line Text

```crystal
# Using fixed-point coordinates
dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[20 * 64],
  CrImage::Math::Fixed::Int26_6[50 * 64]
)
drawer = CrImage::Font::Drawer.new(img, text_color, face, dot)

# Word wrapping
text = "This is a long text that will automatically wrap at word boundaries."
drawer.draw_multiline(text, max_width: 360, line_spacing: 1.5)
```

## Text Alignment

```crystal
# Create bounding box
text_box = CrImage::Font::TextBox.new(
  CrImage.rect(20, 50, 380, 250),
  h_align: CrImage::Font::HorizontalAlign::Center,
  v_align: CrImage::Font::VerticalAlign::Middle
)

drawer.draw_aligned("Centered Text", text_box)
```

## Text Measurement

```crystal
# Simple measurement (convenience methods)
width = face.measure("Hello")              # Width in pixels
bounds = face.text_bounds("Hello")         # Bounding rectangle
width, height = face.text_size("Hello")    # Width and height tuple

# Font metrics
line_height = face.line_height             # Recommended line spacing
ascent = face.ascent                       # Distance above baseline
descent = face.descent                     # Distance below baseline

# Using drawer
bounds, advance = drawer.bounds("Hello")
width = advance.to_i // 64  # Convert from 26.6 fixed point

# Low-level measurement (26.6 fixed point)
bounds, advance = CrImage::Font.bounds(face, "Hello")
```

## Font Information

```crystal
font = FreeType::TrueType.load("font.ttf")
info = FreeType::Info.load(font)

# Metadata
puts info.info.family_name      # "Roboto"
puts info.info.style_name       # "Regular"
puts info.info.full_name        # "Roboto Regular"
puts info.info.version          # "Version 3.009"
puts info.info.copyright

# Capabilities
puts info.glyph_count
puts info.has_kerning?
puts info.has_vertical_metrics?

# Character coverage
info.has_char?('€')
info.has_chars?("Hello")
info.missing_chars("Héllo")  # Returns missing chars
```

## Font Metrics

```crystal
metrics = FreeType::Metrics.load(font)

# At specific size (48pt)
puts metrics.underline_position(48.0)
puts metrics.underline_thickness(48.0)
puts metrics.strikeout_position(48.0)
puts metrics.x_height(48.0)
puts metrics.cap_height(48.0)
```

## Variable Fonts

```crystal
var_font = FreeType::Variable.load(font)

if var_font.is_variable?
  puts "Axes:"
  var_font.axes.each do |axis|
    puts "  #{axis.tag_name}: #{axis.min_value} - #{axis.max_value}"
  end

  # Check specific axis
  if weight = var_font.axis("wght")
    puts "Weight range: #{weight.min_value} - #{weight.max_value}"
  end
end
```

## OpenType Features

```crystal
layout = FreeType::Layout.load(font)

if layout.has_gpos?
  puts "GPOS features:"
  layout.gpos.not_nil!.features.each do |f|
    puts "  #{f.tag_name}"  # kern, mark, etc.
  end
end

if layout.has_gsub?
  puts "GSUB features:"
  layout.gsub.not_nil!.features.each do |f|
    puts "  #{f.tag_name}"  # liga, calt, etc.
  end
end
```

## Font Limitations

| Feature               | Status                       |
| --------------------- | ---------------------------- |
| TrueType/OpenType/CFF | ✅ Full support              |
| WOFF                  | ✅ Auto-decompression        |
| Legacy kern table     | ✅ Pair kerning              |
| GPOS kerning          | ✅ Modern pair positioning   |
| Standard ligatures    | ✅ fi, fl, ffi, ffl via GSUB |
| Complex scripts       | ❌ Requires HarfBuzz         |
| Contextual alternates | ❌ Requires GSUB chaining    |

> **Note:** For Arabic, Hebrew, Thai, Indic scripts, or advanced OpenType features (contextual alternates, mark positioning), use an external shaping engine like HarfBuzz.
