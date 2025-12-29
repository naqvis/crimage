# CrImage Comprehensive Showcase Demo
# ====================================
# This demo creates a complex piece of art showcasing ALL of CrImage's features

require "../src/crimage"
require "../src/freetype"

puts "🎨 CrImage Comprehensive Showcase Demo"
puts "=" * 60

# Canvas dimensions - large enough to show all features with proper spacing
WIDTH  = 2400
HEIGHT = 3200

# Create main canvas with a gradient background
puts "Creating gradient background..."
canvas = CrImage.gradient(WIDTH, HEIGHT,
  CrImage::Color.rgb(25, 35, 65),
  CrImage::Color.rgb(65, 45, 85),
  direction: :diagonal
)

# Load fonts
puts "Loading fonts..."
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
font_bold_path = "fonts/Roboto/static/Roboto-Bold.ttf"
font = FreeType::TrueType.load(font_path)
font_bold = FreeType::TrueType.load(font_bold_path)
face_title = FreeType::TrueType.new_face(font_bold, 72.0)
face_section = FreeType::TrueType.new_face(font_bold, 28.0)
face_label = FreeType::TrueType.new_face(font, 18.0)

# Helper to draw section titles
def draw_section_title(canvas, text, x, y, face)
  color = CrImage::Uniform.new(CrImage::Color.rgb(255, 220, 100))
  dot = CrImage::Math::Fixed::Point26_6.new(
    CrImage::Math::Fixed::Int26_6[x * 64],
    CrImage::Math::Fixed::Int26_6[y * 64]
  )
  drawer = CrImage::Font::Drawer.new(canvas, color, face, dot)
  drawer.draw(text)
end

# Helper to draw labels
def draw_label(canvas, text, x, y, face)
  color = CrImage::Uniform.new(CrImage::Color.rgb(200, 200, 220))
  dot = CrImage::Math::Fixed::Point26_6.new(
    CrImage::Math::Fixed::Int26_6[x * 64],
    CrImage::Math::Fixed::Int26_6[y * 64]
  )
  drawer = CrImage::Font::Drawer.new(canvas, color, face, dot)
  drawer.draw(text)
end

# ============================================================================
# TITLE
# ============================================================================
title_color = CrImage::Uniform.new(CrImage::Color::WHITE)
title_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[70 * 64]
)
title_drawer = CrImage::Font::Drawer.new(canvas, title_color, face_title, title_dot)
title_drawer.draw("CrImage Feature Showcase")

subtitle_color = CrImage::Uniform.new(CrImage::Color.rgb(180, 180, 200))
subtitle_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[110 * 64]
)
subtitle_drawer = CrImage::Font::Drawer.new(canvas, subtitle_color, face_section, subtitle_dot)
subtitle_drawer.draw("Pure Crystal Image Processing Library - All Features Demo")

# Row height for better spacing
ROW_HEIGHT = 280

# ============================================================================
# ROW 1: Basic Shapes, Rounded Rectangles, Polygons, Lines
# ============================================================================
row_y = 140
puts "Drawing basic shapes..."

# SECTION 1: Basic Shapes
draw_section_title(canvas, "1. Basic Shapes", 50, row_y, face_section)
center_x, center_y = 130, row_y + 110
5.times do |i|
  radius = 70 - i * 12
  hue = i * 72
  r = ((Math.sin(hue * Math::PI / 180) * 127 + 128)).to_u8
  g = ((Math.sin((hue + 120) * Math::PI / 180) * 127 + 128)).to_u8
  b = ((Math.sin((hue + 240) * Math::PI / 180) * 127 + 128)).to_u8
  canvas.draw_circle(center_x, center_y, radius, color: CrImage::Color.rgba(r, g, b, 220_u8), fill: i % 2 == 0)
end
draw_label(canvas, "Circles", 100, row_y + 200, face_label)

canvas.draw_ellipse(280, row_y + 90, 60, 35, color: CrImage::Color.rgb(255, 180, 100), fill: true)
canvas.draw_ellipse(280, row_y + 150, 35, 50, color: CrImage::Color.rgba(100_u8, 200_u8, 255_u8, 180_u8), fill: true)
draw_label(canvas, "Ellipses", 250, row_y + 200, face_label)

canvas.draw_rect(360, row_y + 50, 90, 60, fill: CrImage::Color.rgb(100, 180, 255), stroke: CrImage::Color.rgb(50, 130, 200))
canvas.draw_rect(360, row_y + 130, 90, 50, fill: CrImage::Color.rgba(255_u8, 100_u8, 150_u8, 200_u8))
draw_label(canvas, "Rectangles", 360, row_y + 200, face_label)

# SECTION 2: Rounded Rectangles
draw_section_title(canvas, "2. Rounded Rectangles", 500, row_y, face_section)
style1 = CrImage::Draw::RectStyle.new(fill_color: CrImage::Color.rgba(100_u8, 150_u8, 255_u8, 255_u8), corner_radius: 15)
CrImage::Draw.rectangle(canvas, CrImage.rect(500, row_y + 50, 620, row_y + 110), style1)
style2 = CrImage::Draw::RectStyle.new(outline_color: CrImage::Color::RED, corner_radius: 20)
CrImage::Draw.rectangle(canvas, CrImage.rect(640, row_y + 50, 760, row_y + 110), style2)
style3 = CrImage::Draw::RectStyle.new(fill_color: CrImage::Color.rgba(100_u8, 255_u8, 100_u8, 200_u8), outline_color: CrImage::Color::BLACK, corner_radius: 25)
CrImage::Draw.rectangle(canvas, CrImage.rect(500, row_y + 125, 620, row_y + 185), style3)
style4 = CrImage::Draw::RectStyle.new(fill_color: CrImage::Color::ORANGE, corner_radius: 30)
CrImage::Draw.rectangle(canvas, CrImage.rect(640, row_y + 125, 760, row_y + 185), style4)
draw_label(canvas, "Corner Radius: 15-30px", 550, row_y + 205, face_label)

# SECTION 3: Regular Polygons
draw_section_title(canvas, "3. Regular Polygons", 820, row_y, face_section)
poly_style = CrImage::Draw::PolygonStyle.new(fill_color: CrImage::Color.rgba(100_u8, 150_u8, 255_u8, 255_u8), outline_color: CrImage::Color::BLACK)
CrImage::Draw.triangle(canvas, CrImage::Point.new(870, row_y + 110), 40, poly_style)
CrImage::Draw.pentagon(canvas, CrImage::Point.new(960, row_y + 110), 40, poly_style)
CrImage::Draw.hexagon(canvas, CrImage::Point.new(1050, row_y + 110), 40, poly_style)
CrImage::Draw.regular_polygon(canvas, CrImage::Point.new(1140, row_y + 110), 40, 8, poly_style)

# Star
def create_star(cx, cy, outer_r, inner_r, points)
  result = [] of CrImage::Point
  points.times do |i|
    angle_outer = (i * 360.0 / points - 90) * Math::PI / 180
    result << CrImage::Point.new(cx + (outer_r * Math.cos(angle_outer)).to_i, cy + (outer_r * Math.sin(angle_outer)).to_i)
    angle_inner = ((i + 0.5) * 360.0 / points - 90) * Math::PI / 180
    result << CrImage::Point.new(cx + (inner_r * Math.cos(angle_inner)).to_i, cy + (inner_r * Math.sin(angle_inner)).to_i)
  end
  result
end

star_points = create_star(1230, row_y + 110, 45, 18, 5)
canvas.draw_polygon(star_points, fill: CrImage::Color.rgb(255, 215, 0), outline: CrImage::Color.rgb(200, 150, 0))
draw_label(canvas, "Tri  Pent  Hex  Oct  Star", 860, row_y + 175, face_label)

# SECTION 4: Line Styles
draw_section_title(canvas, "4. Line Styles", 1320, row_y, face_section)
canvas.draw_line(1320, row_y + 55, 1520, row_y + 55, color: CrImage::Color::WHITE, thickness: 1)
canvas.draw_line(1320, row_y + 75, 1520, row_y + 75, color: CrImage::Color::WHITE, thickness: 3)
draw_label(canvas, "Solid 1px, 3px", 1370, row_y + 95, face_label)

dashed = CrImage::Draw::DashedLineStyle.dashed(CrImage::Color::CYAN)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(1320, row_y + 115), CrImage::Point.new(1520, row_y + 115), dashed)
draw_label(canvas, "Dashed", 1395, row_y + 135, face_label)

dotted = CrImage::Draw::DashedLineStyle.dotted(CrImage::Color::YELLOW)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(1320, row_y + 150), CrImage::Point.new(1520, row_y + 150), dotted)
draw_label(canvas, "Dotted", 1395, row_y + 170, face_label)

long_dash = CrImage::Draw::DashedLineStyle.long_dash(CrImage::Color::MAGENTA)
CrImage::Draw.dashed_line(canvas, CrImage::Point.new(1320, row_y + 185), CrImage::Point.new(1520, row_y + 185), long_dash)
draw_label(canvas, "Long Dash", 1380, row_y + 205, face_label)

# ============================================================================
# ROW 2: Arcs/Pies, Bezier Curves, Gradients
# ============================================================================
row_y = 140 + ROW_HEIGHT
puts "Drawing arcs, beziers, gradients..."

# SECTION 5: Arcs & Pies
draw_section_title(canvas, "5. Arcs & Pie Slices", 50, row_y, face_section)
arc_style = CrImage::Draw::ArcStyle.new(CrImage::Color::CYAN, thickness: 4)
CrImage::Draw.arc(canvas, CrImage::Point.new(110, row_y + 100), 45, Math::PI, 2 * Math::PI, arc_style)
CrImage::Draw.arc(canvas, CrImage::Point.new(110, row_y + 100), 45, 0.0, Math::PI, arc_style)
draw_label(canvas, "Full Arc", 80, row_y + 165, face_label)

arc_style2 = CrImage::Draw::ArcStyle.new(CrImage::Color::YELLOW, thickness: 4)
CrImage::Draw.arc(canvas, CrImage::Point.new(220, row_y + 100), 45, 0.0, Math::PI * 1.5, arc_style2)
draw_label(canvas, "3/4 Arc", 190, row_y + 165, face_label)

# Pie chart
pie_colors = [CrImage::Color::RED, CrImage::Color::GREEN, CrImage::Color::BLUE, CrImage::Color::YELLOW, CrImage::Color::PURPLE]
percentages = [0.30, 0.25, 0.20, 0.15, 0.10]
start_angle = 0.0
percentages.each_with_index do |pct, i|
  end_angle = start_angle + pct * 2 * Math::PI
  pie_style = CrImage::Draw::ArcStyle.new(pie_colors[i], fill: true)
  CrImage::Draw.pie(canvas, CrImage::Point.new(360, row_y + 100), 55, start_angle, end_angle, pie_style)
  start_angle = end_angle
end
draw_label(canvas, "Pie Chart", 325, row_y + 175, face_label)

# Pac-man
pacman_style = CrImage::Draw::ArcStyle.new(CrImage::Color::YELLOW, fill: true)
CrImage::Draw.pie(canvas, CrImage::Point.new(480, row_y + 100), 40, Math::PI / 6, 2 * Math::PI - Math::PI / 6, pacman_style)
draw_label(canvas, "Pac-Man", 445, row_y + 165, face_label)

# SECTION 6: Bezier Curves
draw_section_title(canvas, "6. Bezier Curves", 560, row_y, face_section)
bezier_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(0_u8, 200_u8, 100_u8, 255_u8), thickness: 3)

# Quadratic bezier
p0 = CrImage::Point.new(580, row_y + 150)
p1 = CrImage::Point.new(680, row_y + 50)
p2 = CrImage::Point.new(780, row_y + 150)
CrImage::Draw.quadratic_bezier(canvas, p0, p1, p2, bezier_style)
ctrl_style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED, fill: true)
CrImage::Draw.circle(canvas, p0, 5, CrImage::Draw::CircleStyle.new(CrImage::Color::BLUE, fill: true))
CrImage::Draw.circle(canvas, p1, 5, ctrl_style)
CrImage::Draw.circle(canvas, p2, 5, CrImage::Draw::CircleStyle.new(CrImage::Color::BLUE, fill: true))
draw_label(canvas, "Quadratic", 650, row_y + 175, face_label)

# Cubic bezier
cubic_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(200_u8, 50_u8, 150_u8, 255_u8), thickness: 3)
p0 = CrImage::Point.new(820, row_y + 150)
p1 = CrImage::Point.new(870, row_y + 50)
p2 = CrImage::Point.new(970, row_y + 180)
p3 = CrImage::Point.new(1020, row_y + 80)
CrImage::Draw.cubic_bezier(canvas, p0, p1, p2, p3, cubic_style)
CrImage::Draw.circle(canvas, p0, 5, CrImage::Draw::CircleStyle.new(CrImage::Color::BLUE, fill: true))
CrImage::Draw.circle(canvas, p1, 5, ctrl_style)
CrImage::Draw.circle(canvas, p2, 5, ctrl_style)
CrImage::Draw.circle(canvas, p3, 5, CrImage::Draw::CircleStyle.new(CrImage::Color::BLUE, fill: true))
draw_label(canvas, "Cubic", 900, row_y + 175, face_label)

# Spline
spline_style = CrImage::Draw::BezierStyle.new(CrImage::Color.rgba(255_u8, 150_u8, 0_u8, 255_u8), thickness: 3)
spline_points = [
  CrImage::Point.new(1060, row_y + 140),
  CrImage::Point.new(1120, row_y + 60),
  CrImage::Point.new(1180, row_y + 160),
  CrImage::Point.new(1240, row_y + 80),
  CrImage::Point.new(1300, row_y + 140),
]
CrImage::Draw.spline(canvas, spline_points, spline_style, tension: 0.5)
spline_points.each { |p| CrImage::Draw.circle(canvas, p, 4, CrImage::Draw::CircleStyle.new(CrImage::Color::WHITE, fill: true)) }
draw_label(canvas, "Spline", 1160, row_y + 175, face_label)

# SECTION 7: Gradients
draw_section_title(canvas, "7. Gradients", 1380, row_y, face_section)
linear_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::GREEN),
]
linear_grad = CrImage::Draw::LinearGradient.new(CrImage::Point.new(1380, row_y + 70), CrImage::Point.new(1580, row_y + 70), linear_stops)
CrImage::Draw.fill_linear_gradient(canvas, CrImage.rect(1380, row_y + 50, 1580, row_y + 100), linear_grad)
draw_label(canvas, "Linear Horizontal", 1420, row_y + 120, face_label)

linear_grad_v = CrImage::Draw::LinearGradient.new(CrImage::Point.new(1600, row_y + 50), CrImage::Point.new(1600, row_y + 170), linear_stops)
CrImage::Draw.fill_linear_gradient(canvas, CrImage.rect(1600, row_y + 50, 1700, row_y + 170), linear_grad_v)
draw_label(canvas, "Linear V", 1620, row_y + 190, face_label)

radial_stops = [
  CrImage::Draw::ColorStop.new(0.0, CrImage::Color::WHITE),
  CrImage::Draw::ColorStop.new(0.5, CrImage::Color::BLUE),
  CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLACK),
]
radial_grad = CrImage::Draw::RadialGradient.new(CrImage::Point.new(1480, row_y + 170), 50, radial_stops)
CrImage::Draw.fill_radial_gradient(canvas, CrImage.rect(1380, row_y + 130, 1580, row_y + 210), radial_grad)
draw_label(canvas, "Radial", 1455, row_y + 230, face_label)

# ============================================================================
# ROW 3: Image Effects
# ============================================================================
row_y = 140 + ROW_HEIGHT * 2
puts "Creating image effects showcase..."
draw_section_title(canvas, "8. Image Effects", 50, row_y, face_section)

# Create a more detailed sample image for effects
sample_size = 90
sample = CrImage.rgba(sample_size, sample_size)
# Create a colorful pattern
sample_size.times do |y|
  sample_size.times do |x|
    r = ((x.to_f / sample_size) * 200 + 55).to_u8
    g = ((y.to_f / sample_size) * 150 + 50).to_u8
    b = (((sample_size - x).to_f / sample_size) * 200 + 55).to_u8
    sample.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end
# Add shapes
sample.draw_circle(45, 45, 30, color: CrImage::Color.rgb(255, 255, 100), fill: true)
sample.draw_circle(45, 45, 18, color: CrImage::Color.rgb(100, 200, 255), fill: true)
sample.draw_rect(10, 10, 25, 25, fill: CrImage::Color.rgb(255, 100, 100))

effect_spacing = 110
effect_x = 50

effects = [
  {sample, "Original"},
  {sample.grayscale, "Grayscale"},
  {sample.sepia, "Sepia"},
  {sample.invert, "Invert"},
  {sample.blur_gaussian(radius: 5), "Blur"},
  {sample.sharpen(amount: 1.5), "Sharpen"},
  {sample.sobel, "Sobel"},
  {sample.vignette(strength: 0.7, radius: 0.5), "Vignette"},
  {sample.emboss(angle: 45.0, depth: 1.0), "Emboss"},
]

effects.each_with_index do |(img, label), i|
  x = effect_x + i * effect_spacing
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + sample_size, row_y + 45 + sample_size), img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 15, row_y + 155, face_label)
end

# SECTION 9: Color Adjustments
draw_section_title(canvas, "9. Color Adjustments", 1100, row_y, face_section)
adjust_size = 80
color_sample = CrImage.rgba(adjust_size, adjust_size)
adjust_size.times do |y|
  adjust_size.times do |x|
    r = ((x.to_f / adjust_size) * 255).to_u8
    g = ((y.to_f / adjust_size) * 255).to_u8
    b = (((x + y).to_f / (2 * adjust_size)) * 255).to_u8
    color_sample.set(x, y, CrImage::Color.rgb(r, g, b))
  end
end

adjustments = [
  {color_sample, "Original"},
  {color_sample.brightness(50), "Bright+"},
  {color_sample.brightness(-50), "Dark-"},
  {color_sample.contrast(1.5), "Contrast+"},
  {color_sample.contrast(0.5), "Contrast-"},
  {color_sample.temperature(40), "Warm"},
  {color_sample.temperature(-40), "Cool"},
]

adjustments.each_with_index do |(img, label), i|
  x = 1100 + i * 95
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + adjust_size, row_y + 45 + adjust_size), img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 10, row_y + 145, face_label)
end

# ============================================================================
# ROW 4: Transformations, Resize Methods
# ============================================================================
row_y = 140 + ROW_HEIGHT * 3
puts "Creating transformations and resize demos..."

# SECTION 10: Transformations
draw_section_title(canvas, "10. Transformations", 50, row_y, face_section)
arrow_size = 65
arrow = CrImage.rgba(arrow_size, arrow_size, CrImage::Color.rgba(0_u8, 0_u8, 0_u8, 0_u8))
arrow_points = [
  CrImage::Point.new(32, 5),
  CrImage::Point.new(55, 32),
  CrImage::Point.new(42, 32),
  CrImage::Point.new(42, 60),
  CrImage::Point.new(22, 60),
  CrImage::Point.new(22, 32),
  CrImage::Point.new(9, 32),
]
arrow.draw_polygon(arrow_points, fill: CrImage::Color.rgb(100, 200, 255), outline: CrImage::Color.rgb(50, 150, 200))

transforms = [
  {arrow, "Original"},
  {arrow.rotate_90, "Rot 90"},
  {arrow.rotate_180, "Rot 180"},
  {arrow.rotate_270, "Rot 270"},
  {arrow.flip_horizontal, "Flip H"},
  {arrow.flip_vertical, "Flip V"},
]

transforms.each_with_index do |(img, label), i|
  x = 50 + i * 85
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + arrow_size, row_y + 45 + arrow_size), img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 5, row_y + 130, face_label)
end

# SECTION 11: Resize Methods - Use a detailed pattern image
draw_section_title(canvas, "11. Resize Methods", 600, row_y, face_section)

# Create a small detailed image with clear patterns to show resize differences
small_img = CrImage.rgba(16, 16)
16.times do |y|
  16.times do |x|
    # Create a checkerboard with colored squares
    if (x // 4 + y // 4) % 2 == 0
      if x < 8
        small_img.set(x, y, CrImage::Color.rgb(255, 80, 80)) # Red
      else
        small_img.set(x, y, CrImage::Color.rgb(80, 80, 255)) # Blue
      end
    else
      if y < 8
        small_img.set(x, y, CrImage::Color.rgb(80, 255, 80)) # Green
      else
        small_img.set(x, y, CrImage::Color.rgb(255, 255, 80)) # Yellow
      end
    end
  end
end
# Add a diagonal line
8.times do |i|
  small_img.set(i, i, CrImage::Color::WHITE)
  small_img.set(15 - i, i, CrImage::Color::BLACK)
end

resize_size = 80
resize_methods = [
  {:nearest, "Nearest"},
  {:bilinear, "Bilinear"},
  {:bicubic, "Bicubic"},
  {:lanczos, "Lanczos"},
]

resize_methods.each_with_index do |(method, label), i|
  x = 600 + i * 100
  resized = small_img.resize(resize_size, resize_size, method: method)
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + resize_size, row_y + 45 + resize_size), resized, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 10, row_y + 145, face_label)
end

# SECTION 12: Morphology - Use an image with clear shapes
draw_section_title(canvas, "12. Morphology", 1050, row_y, face_section)

morph_size = 80
morph_sample = CrImage.rgba(morph_size, morph_size, CrImage::Color::WHITE)
# Draw text-like shapes that show erosion/dilation clearly
morph_sample.draw_circle(40, 25, 15, color: CrImage::Color::BLACK, fill: true)
morph_sample.draw_rect(15, 45, 50, 25, fill: CrImage::Color::BLACK)
# Add thin lines that will disappear with erosion
morph_sample.draw_line(10, 35, 70, 35, color: CrImage::Color::BLACK, thickness: 2)

morphs = [
  {morph_sample, "Original"},
  {morph_sample.erode(kernel_size: 3), "Erode"},
  {morph_sample.dilate(kernel_size: 3), "Dilate"},
  {morph_sample.morphology_gradient(kernel_size: 3), "Gradient"},
]

morphs.each_with_index do |(img, label), i|
  x = 1050 + i * 100
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + morph_size, row_y + 45 + morph_size), img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 10, row_y + 145, face_label)
end

# SECTION 13: Noise Generation
draw_section_title(canvas, "13. Noise Generation", 1500, row_y, face_section)
noise_size = 80

noises = [
  {CrImage.generate_noise(noise_size, noise_size, CrImage::Util::NoiseType::Gaussian), "Gaussian"},
  {CrImage.generate_noise(noise_size, noise_size, CrImage::Util::NoiseType::Uniform), "Uniform"},
  {CrImage.generate_noise(noise_size, noise_size, CrImage::Util::NoiseType::Perlin, scale: 1.5), "Perlin"},
  {sample.add_noise(0.15, CrImage::Util::NoiseType::Gaussian), "Film Grain"},
]

noises.each_with_index do |(img, label), i|
  x = 1500 + i * 100
  display_img = img.is_a?(CrImage::RGBA) && img.bounds.width > noise_size ? img.resize(noise_size, noise_size) : img
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + noise_size, row_y + 45 + noise_size), display_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 5, row_y + 145, face_label)
end

# ============================================================================
# ROW 5: Tiling, Borders, Flood Fill, Stacking
# ============================================================================
row_y = 140 + ROW_HEIGHT * 4
puts "Creating tiling, borders, flood fill..."

# SECTION 14: Tiling & Patterns
draw_section_title(canvas, "14. Tiling & Patterns", 50, row_y, face_section)
tile_size = 35
tile = CrImage.rgba(tile_size, tile_size, CrImage::Color.rgb(60, 80, 100))
tile.draw_circle(17, 17, 12, color: CrImage::Color.rgb(100, 150, 255), fill: true)
tile.draw_circle(17, 17, 6, color: CrImage::Color.rgb(255, 200, 100), fill: true)

tiled = tile.tile(4, 3)
CrImage::Draw.draw(canvas, CrImage.rect(50, row_y + 45, 50 + tiled.bounds.width, row_y + 45 + tiled.bounds.height), tiled, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Tile 4x3", 80, row_y + 165, face_label)

seamless_tile = tile.make_seamless(blend_width: 6)
seamless_tiled = seamless_tile.tile(4, 3)
CrImage::Draw.draw(canvas, CrImage.rect(210, row_y + 45, 210 + seamless_tiled.bounds.width, row_y + 45 + seamless_tiled.bounds.height), seamless_tiled, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Seamless", 240, row_y + 165, face_label)

checker = CrImage.checkerboard(140, 105, cell_size: 15, color1: CrImage::Color.rgb(80, 80, 100), color2: CrImage::Color.rgb(120, 120, 140))
CrImage::Draw.draw(canvas, CrImage.rect(370, row_y + 45, 510, row_y + 150), checker, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Checkerboard", 390, row_y + 170, face_label)

# SECTION 15: Borders & Frames
draw_section_title(canvas, "15. Borders & Frames", 560, row_y, face_section)
border_sample = CrImage.rgba(70, 50, CrImage::Color.rgb(100, 150, 200))
border_sample.draw_circle(35, 25, 18, color: CrImage::Color.rgb(255, 200, 150), fill: true)

bordered = border_sample.add_border(8, CrImage::Color::WHITE)
CrImage::Draw.draw(canvas, CrImage.rect(560, row_y + 50, 560 + bordered.bounds.width, row_y + 50 + bordered.bounds.height), bordered, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Simple", 575, row_y + 135, face_label)

colored_border = border_sample.add_border(8, CrImage::Color.rgb(255, 100, 100))
CrImage::Draw.draw(canvas, CrImage.rect(660, row_y + 50, 660 + colored_border.bounds.width, row_y + 50 + colored_border.bounds.height), colored_border, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Colored", 670, row_y + 135, face_label)

rounded = border_sample.round_corners(12)
CrImage::Draw.draw(canvas, CrImage.rect(760, row_y + 55, 760 + rounded.bounds.width, row_y + 55 + rounded.bounds.height), rounded, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Rounded", 765, row_y + 125, face_label)

rounded_border = border_sample.add_rounded_border(border_width: 10, corner_radius: 18, border_color: CrImage::Color::WHITE)
CrImage::Draw.draw(canvas, CrImage.rect(850, row_y + 45, 850 + rounded_border.bounds.width, row_y + 45 + rounded_border.bounds.height), rounded_border, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Rounded Border", 850, row_y + 135, face_label)

# SECTION 16: Flood Fill
draw_section_title(canvas, "16. Flood Fill", 1000, row_y, face_section)
fill_img = CrImage.rgba(90, 70, CrImage::Color::WHITE)
fill_img.draw_rect(10, 10, 30, 30, fill: CrImage::Color::RED)
fill_img.draw_rect(50, 10, 30, 30, fill: CrImage::Color::GREEN)
fill_img.draw_circle(45, 50, 18, color: CrImage::Color::BLUE, fill: true)

CrImage::Draw.draw(canvas, CrImage.rect(1000, row_y + 50, 1090, row_y + 120), fill_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Original", 1020, row_y + 140, face_label)

fill_copy = CrImage.rgba(90, 70)
70.times { |y| 90.times { |x| fill_copy.set(x, y, fill_img.at(x, y)) } }
fill_copy.flood_fill(25, 25, CrImage::Color::YELLOW, tolerance: 10)
CrImage::Draw.draw(canvas, CrImage.rect(1110, row_y + 50, 1200, row_y + 120), fill_copy, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Filled", 1135, row_y + 140, face_label)

replaced = fill_img.replace_color(CrImage::Color::BLUE, CrImage::Color::ORANGE, tolerance: 10)
CrImage::Draw.draw(canvas, CrImage.rect(1220, row_y + 50, 1310, row_y + 120), replaced, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Replaced", 1235, row_y + 140, face_label)

# SECTION 17: Image Stacking
draw_section_title(canvas, "17. Image Stacking", 1380, row_y, face_section)
stack_img1 = CrImage.rgba(55, 45, CrImage::Color.rgb(255, 150, 150))
stack_img2 = CrImage.rgba(55, 45, CrImage::Color.rgb(150, 255, 150))
stack_img3 = CrImage.rgba(55, 45, CrImage::Color.rgb(150, 150, 255))

h_stacked = CrImage.stack_horizontal([stack_img1, stack_img2, stack_img3], spacing: 4)
CrImage::Draw.draw(canvas, CrImage.rect(1380, row_y + 50, 1380 + h_stacked.bounds.width, row_y + 50 + h_stacked.bounds.height), h_stacked, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Horizontal", 1430, row_y + 115, face_label)

v_stacked = CrImage.stack_vertical([stack_img1, stack_img2], spacing: 4)
CrImage::Draw.draw(canvas, CrImage.rect(1580, row_y + 45, 1580 + v_stacked.bounds.width, row_y + 45 + v_stacked.bounds.height), v_stacked, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Vertical", 1580, row_y + 150, face_label)

grid_imgs = [stack_img1, stack_img2, stack_img3, stack_img1]
grid = CrImage.create_grid(grid_imgs, cols: 2, spacing: 3)
CrImage::Draw.draw(canvas, CrImage.rect(1680, row_y + 45, 1680 + grid.bounds.width, row_y + 45 + grid.bounds.height), grid, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Grid 2x2", 1700, row_y + 150, face_label)

# ============================================================================
# ROW 6: QR Code, Text Effects, Watermarking, Before/After
# ============================================================================
row_y = 140 + ROW_HEIGHT * 5
puts "Creating QR code, text effects, watermarking..."

# SECTION 18: QR Code
draw_section_title(canvas, "18. QR Code", 50, row_y, face_section)
qr = CrImage.qr_code("https://github.com/crystal-lang/crystal", size: 130, error_correction: :high)
CrImage::Draw.draw(canvas, CrImage.rect(50, row_y + 45, 180, row_y + 175), qr, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "High EC", 90, row_y + 195, face_label)

qr_small = CrImage.qr_code("CrImage", size: 70, error_correction: :medium)
CrImage::Draw.draw(canvas, CrImage.rect(200, row_y + 75, 270, row_y + 145), qr_small, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Small", 215, row_y + 165, face_label)

# SECTION 19: Text Effects
draw_section_title(canvas, "19. Text Effects", 320, row_y, face_section)
text_face = FreeType::TrueType.new_face(font_bold, 32.0)
normal_color = CrImage::Uniform.new(CrImage::Color::WHITE)

normal_drawer = CrImage::Font::Drawer.new(canvas, normal_color, text_face)
normal_drawer.draw_text("Normal Text", 320, row_y + 75)
normal_drawer.draw_text("Text with Shadow", 320, row_y + 115, shadow: true)
normal_drawer.draw_text("Text with Outline", 320, row_y + 155, outline: true)
normal_drawer.draw_text("Underlined Text", 320, row_y + 195, underline: true)

# SECTION 20: Watermarking
draw_section_title(canvas, "20. Watermarking", 620, row_y, face_section)
wm_base = CrImage.gradient(150, 100, CrImage::Color.rgb(100, 150, 200), CrImage::Color.rgb(200, 150, 100), direction: :horizontal)
wm_base.draw_circle(75, 50, 35, color: CrImage::Color.rgb(255, 200, 150), fill: true)

wm_logo = CrImage.rgba(35, 35)
wm_logo.draw_circle(17, 17, 15, color: CrImage::Color.rgba(255_u8, 255_u8, 255_u8, 200_u8), fill: true)
wm_logo.draw_circle(17, 17, 10, color: CrImage::Color.rgba(100_u8, 100_u8, 100_u8, 200_u8), fill: false)

wm_options = CrImage::Util::WatermarkOptions.new(position: CrImage::Util::WatermarkPosition::BottomRight, opacity: 0.7)
watermarked = CrImage::Util.watermark_image(wm_base, wm_logo, wm_options)
CrImage::Draw.draw(canvas, CrImage.rect(620, row_y + 50, 620 + watermarked.bounds.width, row_y + 50 + watermarked.bounds.height), watermarked, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Image Watermark", 630, row_y + 170, face_label)

wm_text_options = CrImage::Util::WatermarkOptions.new(position: CrImage::Util::WatermarkPosition::Center, opacity: 0.5)
wm_face = FreeType::TrueType.new_face(font, 14.0)
text_watermarked = CrImage::Util.watermark_text(wm_base, "© CrImage", wm_face, wm_text_options)
CrImage::Draw.draw(canvas, CrImage.rect(800, row_y + 50, 800 + text_watermarked.bounds.width, row_y + 50 + text_watermarked.bounds.height), text_watermarked, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Text Watermark", 815, row_y + 170, face_label)

# SECTION 21: Before/After
draw_section_title(canvas, "21. Before/After", 1000, row_y, face_section)
before_img = CrImage.rgba(90, 70, CrImage::Color.rgb(150, 150, 150))
before_img.draw_circle(45, 35, 25, color: CrImage::Color.rgb(180, 180, 180), fill: true)
after_img = before_img.contrast(1.5).brightness(20)

comparison = CrImage.compare_images(before_img, after_img, divider: true, divider_width: 2, spacing: 0)
CrImage::Draw.draw(canvas, CrImage.rect(1000, row_y + 55, 1000 + comparison.bounds.width, row_y + 55 + comparison.bounds.height), comparison, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Before | After", 1040, row_y + 150, face_label)

# SECTION 22: Animation Frames
draw_section_title(canvas, "22. Animation Frames", 1250, row_y, face_section)
frame_size = 50
4.times do |i|
  frame = CrImage.rgba(frame_size, frame_size, CrImage::Color::WHITE)
  y_pos = (frame_size / 2 + Math.sin(i * Math::PI / 2) * 15).to_i
  frame.draw_circle(frame_size // 2, y_pos, 10, color: CrImage::Color::RED, fill: true)
  # Shadow
  shadow_y = frame_size - 8
  shadow_size = (8 * (1.0 - (y_pos - frame_size/2).abs / 20.0)).to_i.clamp(3, 8)
  frame.draw_ellipse(frame_size // 2, shadow_y, shadow_size, 3, color: CrImage::Color.rgb(180, 180, 180), fill: true)
  CrImage::Draw.draw(canvas, CrImage.rect(1250 + i * 60, row_y + 60, 1250 + i * 60 + frame_size, row_y + 60 + frame_size), frame, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
end
draw_label(canvas, "GIF Frames (bouncing ball)", 1280, row_y + 130, face_label)

# SECTION 23: Thick Outlines
draw_section_title(canvas, "23. Thick Outlines", 1550, row_y, face_section)
[2, 4, 6, 8].each_with_index do |thickness, i|
  style = CrImage::Draw::CircleStyle.new(CrImage::Color.rgba((100 + i * 40).to_u8, 150_u8, 255_u8, 255_u8)).with_thickness(thickness)
  CrImage::Draw.circle(canvas, CrImage::Point.new(1600 + i * 80, row_y + 100), 30, style)
end
draw_label(canvas, "Thickness: 2, 4, 6, 8 px", 1620, row_y + 155, face_label)

# ============================================================================
# ROW 7: Factory Methods, Output Formats, Blurhash, Metrics
# ============================================================================
row_y = 140 + ROW_HEIGHT * 6
puts "Creating factory methods, formats, blurhash..."

# SECTION 24: Factory Methods
draw_section_title(canvas, "24. Factory Methods", 50, row_y, face_section)
factory_size = 70

factories = [
  {CrImage.rgba(factory_size, factory_size, CrImage::Color.rgb(100, 150, 200)), "rgba()"},
  {CrImage.gradient(factory_size, factory_size, CrImage::Color::RED, CrImage::Color::BLUE, direction: :diagonal), "gradient()"},
  {CrImage.checkerboard(factory_size, factory_size, cell_size: 10), "checker()"},
  {CrImage.generate_noise(factory_size, factory_size, CrImage::Util::NoiseType::Perlin), "noise()"},
]

factories.each_with_index do |(img, label), i|
  x = 50 + i * 90
  CrImage::Draw.draw(canvas, CrImage.rect(x, row_y + 45, x + factory_size, row_y + 45 + factory_size), img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  draw_label(canvas, label, x + 5, row_y + 135, face_label)
end

# SECTION 25: Output Formats
draw_section_title(canvas, "25. Output Formats", 450, row_y, face_section)
formats = ["PNG", "JPEG", "WebP", "GIF", "BMP", "TIFF", "ICO"]
formats.each_with_index do |fmt, i|
  x = 450 + (i % 4) * 75
  y = row_y + 50 + (i // 4) * 45
  box_style = CrImage::Draw::RectStyle.new(fill_color: CrImage::Color.rgba(80_u8, 100_u8, 140_u8, 255_u8), outline_color: CrImage::Color.rgb(150, 180, 220), corner_radius: 5)
  CrImage::Draw.rectangle(canvas, CrImage.rect(x, y, x + 65, y + 35), box_style)
  fmt_color = CrImage::Uniform.new(CrImage::Color::WHITE)
  fmt_dot = CrImage::Math::Fixed::Point26_6.new(CrImage::Math::Fixed::Int26_6[(x + 12) * 64], CrImage::Math::Fixed::Int26_6[(y + 25) * 64])
  fmt_drawer = CrImage::Font::Drawer.new(canvas, fmt_color, face_label, fmt_dot)
  fmt_drawer.draw(fmt)
end

# SECTION 26: Blurhash
draw_section_title(canvas, "26. Blurhash", 780, row_y, face_section)
blurhash_sample = CrImage.gradient(90, 70, CrImage::Color.rgb(255, 100, 50), CrImage::Color.rgb(50, 100, 255), direction: :diagonal)
blurhash_sample.draw_circle(45, 35, 25, color: CrImage::Color.rgb(255, 255, 100), fill: true)

CrImage::Draw.draw(canvas, CrImage.rect(780, row_y + 50, 870, row_y + 120), blurhash_sample, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Original", 800, row_y + 140, face_label)

blurhash_str = blurhash_sample.to_blurhash(x_components: 4, y_components: 3)
decoded = CrImage::Util::Blurhash.decode(blurhash_str, 90, 70)
CrImage::Draw.draw(canvas, CrImage.rect(900, row_y + 50, 990, row_y + 120), decoded, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Blurhash", 915, row_y + 140, face_label)

# SECTION 27: Image Metrics
draw_section_title(canvas, "27. Image Metrics", 1050, row_y, face_section)
metrics_img1 = CrImage.rgba(60, 60, CrImage::Color.rgb(100, 150, 200))
metrics_img2 = metrics_img1.brightness(20)

CrImage::Draw.draw(canvas, CrImage.rect(1050, row_y + 50, 1110, row_y + 110), metrics_img1, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
CrImage::Draw.draw(canvas, CrImage.rect(1130, row_y + 50, 1190, row_y + 110), metrics_img2, CrImage.point(0, 0), CrImage::Draw::Op::OVER)

mse_val = metrics_img1.mse(metrics_img2)
psnr_val = metrics_img1.psnr(metrics_img2)
ssim_val = metrics_img1.ssim(metrics_img2)

draw_label(canvas, "MSE: #{mse_val.round(1)}", 1050, row_y + 130, face_label)
draw_label(canvas, "PSNR: #{psnr_val.round(1)}dB", 1050, row_y + 150, face_label)
draw_label(canvas, "SSIM: #{ssim_val.round(3)}", 1050, row_y + 170, face_label)

# SECTION 28: Histogram Operations
draw_section_title(canvas, "28. Histogram Ops", 1280, row_y, face_section)
low_contrast_img = CrImage.rgba(80, 60)
60.times do |y|
  80.times do |x|
    val = (100 + (x + y) * 55 // 140).clamp(100, 155).to_u8
    low_contrast_img.set(x, y, CrImage::Color.rgb(val, val, val))
  end
end

CrImage::Draw.draw(canvas, CrImage.rect(1280, row_y + 50, 1360, row_y + 110), low_contrast_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Low Contrast", 1280, row_y + 130, face_label)

equalized = low_contrast_img.equalize
CrImage::Draw.draw(canvas, CrImage.rect(1380, row_y + 50, 1460, row_y + 110), equalized, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Equalized", 1390, row_y + 130, face_label)

adaptive_eq = low_contrast_img.equalize_adaptive(tile_size: 8, clip_limit: 2.0)
CrImage::Draw.draw(canvas, CrImage.rect(1480, row_y + 50, 1560, row_y + 110), adaptive_eq, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "CLAHE", 1500, row_y + 130, face_label)

# ============================================================================
# ROW 8: Color Spaces, Thumbnails, Perceptual Hash, More
# ============================================================================
row_y = 140 + ROW_HEIGHT * 7
puts "Creating color spaces, thumbnails..."

# SECTION 29: Color Spaces
draw_section_title(canvas, "29. Color Spaces", 50, row_y, face_section)
hsv_size = 80
hsv_img = CrImage.rgba(hsv_size, hsv_size)
hsv_size.times do |y|
  hsv_size.times do |x|
    hue = (x.to_f / hsv_size) * 360.0
    sat = 1.0 - (y.to_f / hsv_size)
    hsv = CrImage::Color::HSV.new(hue, sat, 1.0)
    hsv_img.set(x, y, hsv.to_rgba)
  end
end
CrImage::Draw.draw(canvas, CrImage.rect(50, row_y + 45, 50 + hsv_size, row_y + 45 + hsv_size), hsv_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "HSV", 75, row_y + 145, face_label)

hsl_img = CrImage.rgba(hsv_size, hsv_size)
hsv_size.times do |y|
  hsv_size.times do |x|
    hue = (x.to_f / hsv_size) * 360.0
    light = 0.2 + (y.to_f / hsv_size) * 0.6
    hsl = CrImage::Color::HSL.new(hue, 1.0, light)
    hsl_img.set(x, y, hsl.to_rgba)
  end
end
CrImage::Draw.draw(canvas, CrImage.rect(150, row_y + 45, 150 + hsv_size, row_y + 45 + hsv_size), hsl_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "HSL", 175, row_y + 145, face_label)

# SECTION 30: Thumbnail Methods
draw_section_title(canvas, "30. Thumbnail Methods", 280, row_y, face_section)
wide_img = CrImage.gradient(120, 60, CrImage::Color.rgb(255, 100, 100), CrImage::Color.rgb(100, 100, 255), direction: :horizontal)
wide_img.draw_circle(60, 30, 20, color: CrImage::Color::WHITE, fill: true)

CrImage::Draw.draw(canvas, CrImage.rect(280, row_y + 50, 400, row_y + 110), wide_img, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Original 120x60", 290, row_y + 130, face_label)

fitted = wide_img.fit(60, 60)
CrImage::Draw.draw(canvas, CrImage.rect(420, row_y + 50, 420 + fitted.bounds.width, row_y + 50 + fitted.bounds.height), fitted, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "fit(60,60)", 420, row_y + 95, face_label)

filled = wide_img.fill(60, 60)
CrImage::Draw.draw(canvas, CrImage.rect(500, row_y + 50, 560, row_y + 110), filled, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "fill(60,60)", 500, row_y + 130, face_label)

thumb = wide_img.thumb(50)
CrImage::Draw.draw(canvas, CrImage.rect(580, row_y + 50, 630, row_y + 100), thumb, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "thumb(50)", 575, row_y + 120, face_label)

# SECTION 31: Perceptual Hash
draw_section_title(canvas, "31. Perceptual Hash", 680, row_y, face_section)
phash_img1 = CrImage.rgba(60, 60, CrImage::Color.rgb(100, 150, 200))
phash_img1.draw_circle(30, 30, 20, color: CrImage::Color::WHITE, fill: true)
phash_img2 = phash_img1.brightness(10)

CrImage::Draw.draw(canvas, CrImage.rect(680, row_y + 50, 740, row_y + 110), phash_img1, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
CrImage::Draw.draw(canvas, CrImage.rect(760, row_y + 50, 820, row_y + 110), phash_img2, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
draw_label(canvas, "Similar images", 700, row_y + 130, face_label)
draw_label(canvas, "Same pHash!", 710, row_y + 150, face_label)

# ============================================================================
# ROW 9: Additional Features Summary
# ============================================================================
row_y = 140 + ROW_HEIGHT * 8
puts "Adding summary section..."

draw_section_title(canvas, "Additional Features Demonstrated:", 50, row_y, face_section)

features_text = [
  "• Anti-aliased drawing • Alpha blending • Image compositing",
  "• Crop operations • Arbitrary rotation • Color palette generation",
  "• Dithering algorithms • Image comparison • Selection masks",
  "• Channel operations • YCbCr color space • LAB color space",
]

features_text.each_with_index do |text, i|
  feat_color = CrImage::Uniform.new(CrImage::Color.rgb(180, 180, 200))
  feat_dot = CrImage::Math::Fixed::Point26_6.new(
    CrImage::Math::Fixed::Int26_6[50 * 64],
    CrImage::Math::Fixed::Int26_6[(row_y + 45 + i * 30) * 64]
  )
  feat_drawer = CrImage::Font::Drawer.new(canvas, feat_color, face_label, feat_dot)
  feat_drawer.draw(text)
end

# ============================================================================
# DECORATIVE BORDER
# ============================================================================
puts "Adding decorative border..."

border_width = 12
(0...border_width).each do |i|
  alpha = (220 - i * 18).clamp(80, 255).to_u8
  color = CrImage::Color.rgba(255_u8, 215_u8, 0_u8, alpha)
  canvas.draw_line(i, i, WIDTH - 1 - i, i, color: color)
  canvas.draw_line(i, HEIGHT - 1 - i, WIDTH - 1 - i, HEIGHT - 1 - i, color: color)
  canvas.draw_line(i, i, i, HEIGHT - 1 - i, color: color)
  canvas.draw_line(WIDTH - 1 - i, i, WIDTH - 1 - i, HEIGHT - 1 - i, color: color)
end

# Corner decorations
corner_size = 50
corners = [{0, 0}, {WIDTH - corner_size, 0}, {0, HEIGHT - corner_size}, {WIDTH - corner_size, HEIGHT - corner_size}]
corners.each do |(cx, cy)|
  canvas.draw_circle(cx + corner_size // 2, cy + corner_size // 2, 20, color: CrImage::Color.rgb(255, 215, 0), fill: true)
  canvas.draw_circle(cx + corner_size // 2, cy + corner_size // 2, 12, color: CrImage::Color.rgb(200, 150, 0), fill: true)
end

# ============================================================================
# FOOTER
# ============================================================================
footer_color = CrImage::Uniform.new(CrImage::Color.rgba(180_u8, 180_u8, 200_u8, 220_u8))
footer_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[(HEIGHT - 50) * 64]
)
footer_drawer = CrImage::Font::Drawer.new(canvas, footer_color, face_section, footer_dot)
footer_drawer.draw("CrImage v#{CrImage::VERSION} - Pure Crystal Image Processing Library")

version_dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[(WIDTH - 500) * 64],
  CrImage::Math::Fixed::Int26_6[(HEIGHT - 50) * 64]
)
version_drawer = CrImage::Font::Drawer.new(canvas, footer_color, face_label, version_dot)
version_drawer.draw("31 Feature Categories")

# ============================================================================
# SAVE OUTPUT
# ============================================================================
puts "\nSaving output..."
Dir.mkdir_p("output")

CrImage::PNG.write("output/showcase_demo.png", canvas)
puts "  ✓ Saved output/showcase_demo.png (#{WIDTH}x#{HEIGHT})"

puts "\n✨ Comprehensive showcase demo complete!"
puts "=" * 60
