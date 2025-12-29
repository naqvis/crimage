require "../src/crimage"

# Example: Advanced Shape Drawing
#
# Demonstrates rounded rectangles, dashed/dotted lines,
# arcs, and pie slices.
#
# Usage:
#   crystal run examples/advanced_shapes_demo.cr

puts "Advanced Shape Drawing Demo"
puts "=" * 50

canvas = CrImage.rgba(500, 500, CrImage::Color::WHITE)

# =============================================================================
# Rounded Rectangles
# =============================================================================
puts "\nDrawing rounded rectangles..."

# Filled rounded rectangle
style1 = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::RGBA.new(100_u8, 150_u8, 255_u8, 255_u8),
  corner_radius: 20)
CrImage::Draw.rectangle(canvas, CrImage.rect(20, 20, 150, 100), style1)

# Outlined rounded rectangle
style2 = CrImage::Draw::RectStyle.new(
  outline_color: CrImage::Color::RED,
  corner_radius: 15)
CrImage::Draw.rectangle(canvas, CrImage.rect(170, 20, 300, 100), style2)

# Both fill and outline
style3 = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::RGBA.new(100_u8, 255_u8, 100_u8, 200_u8),
  outline_color: CrImage::Color::BLACK,
  corner_radius: 25)
CrImage::Draw.rectangle(canvas, CrImage.rect(320, 20, 480, 100), style3)

# Very rounded (pill shape)
style4 = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::ORANGE,
  corner_radius: 40)
CrImage::Draw.rectangle(canvas, CrImage.rect(20, 120, 200, 200), style4)

puts "  Drew 4 rounded rectangles"

# =============================================================================
# Dashed and Dotted Lines
# =============================================================================
puts "\nDrawing dashed and dotted lines..."

# Standard dashed line
dashed = CrImage::Draw::DashedLineStyle.dashed(CrImage::Color::BLUE)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(20, 230), CrImage::Point.new(480, 230), dashed)

# Dotted line
dotted = CrImage::Draw::DashedLineStyle.dotted(CrImage::Color::RED)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(20, 250), CrImage::Point.new(480, 250), dotted)

# Long dash
long_dash = CrImage::Draw::DashedLineStyle.long_dash(CrImage::Color::GREEN)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(20, 270), CrImage::Point.new(480, 270), long_dash)

# Custom dash pattern
custom = CrImage::Draw::DashedLineStyle.new(
  CrImage::Color::PURPLE,
  dash_length: 20,
  gap_length: 5,
  thickness: 3)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(20, 295), CrImage::Point.new(480, 295), custom)

# Diagonal dashed line
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(220, 120), CrImage::Point.new(480, 200), dashed)

puts "  Drew 5 dashed/dotted lines"

# =============================================================================
# Arcs
# =============================================================================
puts "\nDrawing arcs..."

# Half circle arc (top)
arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color::BLUE, thickness: 3)
CrImage::Draw.arc(canvas, CrImage::Point.new(80, 380), 50, Math::PI, 2 * Math::PI, arc_style)

# Half circle arc (bottom)
CrImage::Draw.arc(canvas, CrImage::Point.new(80, 380), 50, 0.0, Math::PI, arc_style)

# Quarter arc
arc_style2 = CrImage::Draw::ArcStyle.new(CrImage::Color::RED, thickness: 2)
CrImage::Draw.arc(canvas, CrImage::Point.new(200, 380), 40, 0.0, Math::PI / 2, arc_style2)

# Three-quarter arc
arc_style3 = CrImage::Draw::ArcStyle.new(CrImage::Color::GREEN, thickness: 4)
CrImage::Draw.arc(canvas, CrImage::Point.new(200, 380), 60, Math::PI / 4, 2 * Math::PI - Math::PI / 4, arc_style3)

puts "  Drew 4 arcs"

# =============================================================================
# Pie Slices
# =============================================================================
puts "\nDrawing pie slices..."

# Pie chart
pie_colors = [
  CrImage::Color::RED,
  CrImage::Color::GREEN,
  CrImage::Color::BLUE,
  CrImage::Color::YELLOW,
  CrImage::Color::PURPLE,
]
# Percentages: 30%, 25%, 20%, 15%, 10%
percentages = [0.30, 0.25, 0.20, 0.15, 0.10]
start_angle = 0.0

percentages.each_with_index do |pct, i|
  end_angle = start_angle + pct * 2 * Math::PI
  pie_style = CrImage::Draw::ArcStyle.new(pie_colors[i], fill: true)
  CrImage::Draw.pie(canvas, CrImage::Point.new(380, 400), 80, start_angle, end_angle, pie_style)
  start_angle = end_angle
end

# Pie outline only
outline_style = CrImage::Draw::ArcStyle.new(CrImage::Color::BLACK, fill: false, thickness: 2)
CrImage::Draw.pie(canvas, CrImage::Point.new(380, 400), 80, 0.0, 2 * Math::PI, outline_style)

# Single pie slice (pac-man style)
pacman_style = CrImage::Draw::ArcStyle.new(CrImage::Color::YELLOW, fill: true)
CrImage::Draw.pie(canvas, CrImage::Point.new(80, 450), 35, Math::PI / 6, 2 * Math::PI - Math::PI / 6, pacman_style)

puts "  Drew pie chart and pac-man"

CrImage::PNG.write("advanced_shapes.png", canvas)
puts "\nSaved: advanced_shapes.png"

# =============================================================================
# Additional examples
# =============================================================================

# Button-like rounded rectangles
puts "\nCreating button examples..."
buttons = CrImage.rgba(400, 100, CrImage::Color::RGBA.new(240_u8, 240_u8, 240_u8, 255_u8))

# Primary button
btn1 = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::RGBA.new(0_u8, 122_u8, 255_u8, 255_u8),
  corner_radius: 8)
CrImage::Draw.rectangle(buttons, CrImage.rect(20, 30, 120, 70), btn1)

# Secondary button
btn2 = CrImage::Draw::RectStyle.new(
  outline_color: CrImage::Color::RGBA.new(0_u8, 122_u8, 255_u8, 255_u8),
  corner_radius: 8)
CrImage::Draw.rectangle(buttons, CrImage.rect(140, 30, 240, 70), btn2)

# Danger button
btn3 = CrImage::Draw::RectStyle.new(
  fill_color: CrImage::Color::RGBA.new(220_u8, 53_u8, 69_u8, 255_u8),
  corner_radius: 8)
CrImage::Draw.rectangle(buttons, CrImage.rect(260, 30, 380, 70), btn3)

CrImage::PNG.write("advanced_shapes_buttons.png", buttons)
puts "Saved: advanced_shapes_buttons.png"

# Progress indicator with arcs
puts "\nCreating progress indicator..."
progress = CrImage.rgba(150, 150, CrImage::Color::WHITE)

# Background circle
bg_style = CrImage::Draw::ArcStyle.new(
  CrImage::Color::RGBA.new(230_u8, 230_u8, 230_u8, 255_u8),
  thickness: 10)
CrImage::Draw.arc(progress, CrImage::Point.new(75, 75), 50, 0.0, 2 * Math::PI, bg_style)

# Progress arc (75% complete)
progress_style = CrImage::Draw::ArcStyle.new(
  CrImage::Color::RGBA.new(0_u8, 200_u8, 83_u8, 255_u8),
  thickness: 10)
CrImage::Draw.arc(progress, CrImage::Point.new(75, 75), 50, -Math::PI / 2, -Math::PI / 2 + 0.75 * 2 * Math::PI, progress_style)

CrImage::PNG.write("advanced_shapes_progress.png", progress)
puts "Saved: advanced_shapes_progress.png"

puts "\nOutput files:"
puts "  - advanced_shapes.png (all shapes)"
puts "  - advanced_shapes_buttons.png (UI buttons)"
puts "  - advanced_shapes_progress.png (progress indicator)"
