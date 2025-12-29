require "../src/crimage"
require "../src/freetype"

# Font Metrics Demo
# Demonstrates extended font metrics (underline, strikeout, x-height, etc.)

puts "Font Metrics Demo"
puts "=" * 60

# Check for font
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"

unless File.exists?(font_path)
  puts "Font not found at #{font_path}"
  puts "Please install fonts. See fonts/README.md"
  exit 1
end

# Load font with extended metrics
puts "Loading font: #{font_path}"
ttf = FreeType::TrueType.load(font_path)
font = FreeType::Metrics.load(ttf)

font_size = 48.0

puts ""
puts "Extended Font Metrics (at #{font_size}pt):"
puts "-" * 60

# Underline metrics
puts "Underline:"
puts "  Position:   #{font.underline_position(font_size)}px"
puts "  Thickness:  #{font.underline_thickness(font_size)}px"
puts "  (Raw: #{font.metrics.underline_position} / #{font.metrics.underline_thickness} font units)"

# Strikeout metrics
puts ""
puts "Strikeout:"
puts "  Position:   #{font.strikeout_position(font_size)}px"
puts "  Size:       #{font.strikeout_size(font_size)}px"
puts "  (Raw: #{font.metrics.strikeout_position} / #{font.metrics.strikeout_size} font units)"

# Typographic metrics
puts ""
puts "Typographic Metrics:"
puts "  x-height:    #{font.x_height(font_size)}px (height of lowercase 'x')"
puts "  Cap height:  #{font.cap_height(font_size)}px (height of uppercase letters)"
puts "  Line gap:    #{font.line_gap(font_size)}px (spacing between lines)"

# Subscript/superscript
puts ""
puts "Subscript/Superscript (raw font units):"
puts "  Subscript size:   #{font.metrics.subscript_x_size} x #{font.metrics.subscript_y_size}"
puts "  Subscript offset: #{font.metrics.subscript_x_offset}, #{font.metrics.subscript_y_offset}"
puts "  Superscript size: #{font.metrics.superscript_x_size} x #{font.metrics.superscript_y_size}"
puts "  Superscript offset: #{font.metrics.superscript_x_offset}, #{font.metrics.superscript_y_offset}"

puts ""
puts "Creating visual demonstration..."

# Create image with white background
width, height = 600, 400
img = CrImage.rgba(width, height, CrImage::Color::WHITE)

# Black text
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)

# Draw text
face = FreeType::TrueType.new_face(ttf, font_size)
text = "Typography"

dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[150 * 64]
)
drawer = CrImage::Font::Drawer.new(img, text_color, face, dot)
drawer.draw(text)

# Baseline position for drawing metric lines
baseline_y = 150

# Draw underline
underline_y = baseline_y - font.underline_position(font_size)
underline_thickness = font.underline_thickness(font_size).clamp(1, 10)
underline_thickness.times do |i|
  img.draw_line(50, underline_y + i, 550, underline_y + i,
    color: CrImage::Color.rgb(255, 0, 0), thickness: 1, anti_alias: false)
end

# Draw strikeout
strikeout_y = baseline_y - font.strikeout_position(font_size)
strikeout_thickness = font.strikeout_size(font_size).clamp(1, 10)
strikeout_thickness.times do |i|
  img.draw_line(50, strikeout_y + i, 550, strikeout_y + i,
    color: CrImage::Color.rgb(0, 128, 255), thickness: 1, anti_alias: false)
end

# Draw baseline
img.draw_line(50, baseline_y, 550, baseline_y,
  color: CrImage::Color.rgb(0, 255, 0), thickness: 1, anti_alias: false)

# Draw x-height line
x_height_y = baseline_y - font.x_height(font_size)
img.draw_line(50, x_height_y, 550, x_height_y,
  color: CrImage::Color.rgb(128, 0, 255), thickness: 1, anti_alias: false)

# Draw cap height line
cap_height_y = baseline_y - font.cap_height(font_size)
img.draw_line(50, cap_height_y, 550, cap_height_y,
  color: CrImage::Color.rgb(255, 128, 0), thickness: 1, anti_alias: false)

# Add labels
label_face = FreeType::TrueType.new_face(ttf, 14.0)

labels = [
  {underline_y + 15, "Underline", CrImage::Color.rgb(255, 0, 0)},
  {strikeout_y + 15, "Strikeout", CrImage::Color.rgb(0, 128, 255)},
  {baseline_y + 15, "Baseline", CrImage::Color.rgb(0, 255, 0)},
  {x_height_y - 5, "x-height", CrImage::Color.rgb(128, 0, 255)},
  {cap_height_y - 5, "Cap height", CrImage::Color.rgb(255, 128, 0)},
]

labels.each do |(y, label, color)|
  label_dot = CrImage::Math::Fixed::Point26_6.new(
    CrImage::Math::Fixed::Int26_6[10 * 64],
    CrImage::Math::Fixed::Int26_6[y * 64]
  )
  label_drawer = CrImage::Font::Drawer.new(img, CrImage::Uniform.new(color), label_face, label_dot)
  label_drawer.draw(label)
end

# Save output
output_path = "font_metrics_demo.png"
CrImage::PNG.write(output_path, img)

puts "✓ Saved to #{output_path}"
