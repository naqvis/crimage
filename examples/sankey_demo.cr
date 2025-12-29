# Sankey Diagram Demo
#
# Demonstrates the new Path builder and bezier band features
# for creating Sankey diagrams and flow charts.
#
# Run: crystal run examples/sankey_demo.cr

require "../src/crimage"

puts "=== Sankey Diagram Demo ==="

# Create canvas
img = CrImage.rgba(600, 400, CrImage::Color::WHITE)

# Draw title
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
if File.exists?(font_path)
  font = FreeType::TrueType.load(font_path)
  face = FreeType::TrueType.new_face(font, 24.0)
  text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
  drawer = CrImage::Font::Drawer.new(img, text_color, face)
  drawer.draw_text("Sankey Diagram Demo", 20, 35)
end

# --- Flow 1: Blue flow (top) ---
puts "\n1. Drawing blue flow band..."
top1 = {
  CrImage.point(50, 80),
  CrImage.point(200, 70),
  CrImage.point(400, 100),
  CrImage.point(550, 80),
}
bottom1 = {
  CrImage.point(50, 120),
  CrImage.point(200, 130),
  CrImage.point(400, 150),
  CrImage.point(550, 130),
}
CrImage::Draw.fill_bezier_band(img, top1, bottom1,
  CrImage::Color.rgba(66_u8, 133_u8, 244_u8, 200_u8),
  anti_alias: true)

# --- Flow 2: Red flow (middle) ---
puts "2. Drawing red flow band..."
top2 = {
  CrImage.point(50, 150),
  CrImage.point(150, 160),
  CrImage.point(350, 200),
  CrImage.point(550, 160),
}
bottom2 = {
  CrImage.point(50, 200),
  CrImage.point(150, 220),
  CrImage.point(350, 260),
  CrImage.point(550, 220),
}
CrImage::Draw.fill_bezier_band(img, top2, bottom2,
  CrImage::Color.rgba(234_u8, 67_u8, 53_u8, 200_u8),
  anti_alias: true)

# --- Flow 3: Green flow (bottom) ---
puts "3. Drawing green flow band..."
top3 = {
  CrImage.point(50, 230),
  CrImage.point(200, 280),
  CrImage.point(400, 290),
  CrImage.point(550, 250),
}
bottom3 = {
  CrImage.point(50, 280),
  CrImage.point(200, 340),
  CrImage.point(400, 350),
  CrImage.point(550, 310),
}
CrImage::Draw.fill_bezier_band(img, top3, bottom3,
  CrImage::Color.rgba(52_u8, 168_u8, 83_u8, 200_u8),
  anti_alias: true)

# --- Path demo: Custom shape ---
puts "\n4. Drawing custom path shape..."
path = CrImage::Draw::Path.new
  .move_to(50, 350)
  .bezier_to(100, 320, 150, 380, 200, 350)
  .line_to(200, 390)
  .bezier_to(150, 420, 100, 360, 50, 390)
  .close

CrImage::Draw.fill_path_aa(img, path, CrImage::Color.rgba(255_u8, 193_u8, 7_u8, 220_u8))

# Stroke outline
stroke_style = CrImage::Draw::PathStyle.new(CrImage::Color::BLACK, thickness: 2)
CrImage::Draw.stroke_path(img, path, stroke_style)

# --- Anti-aliased polygon ---
puts "5. Drawing anti-aliased polygon..."
polygon_points = [
  CrImage.point(450, 320),
  CrImage.point(520, 340),
  CrImage.point(550, 390),
  CrImage.point(480, 395),
  CrImage.point(420, 370),
]
CrImage::Draw.fill_polygon_aa(img, polygon_points, CrImage::Color.rgba(156_u8, 39_u8, 176_u8, 200_u8))

# Save output
output_path = "output/sankey_demo.png"
Dir.mkdir_p("output")
CrImage::PNG.write(output_path, img)

puts "\n✓ Saved to #{output_path}"
puts "\nFeatures demonstrated:"
puts "  - fill_bezier_band() for Sankey flow bands"
puts "  - Path builder with bezier curves"
puts "  - fill_path_aa() for anti-aliased path fill"
puts "  - fill_polygon_aa() for smooth polygon edges"
