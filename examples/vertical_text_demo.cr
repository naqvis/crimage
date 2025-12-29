require "../src/crimage"
require "../src/freetype"

puts "Vertical Text Layout Demo"
puts "=" * 50

font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
unless File.exists?(font_path)
  puts "Error: Font not found at #{font_path}"
  exit 1
end

font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 32.0)

puts "\n1. Font Metrics Comparison"
puts "-" * 40
puts "Font: #{font_path}"
puts "Has vertical metrics: #{font.has_vertical_metrics?}"
puts ""
puts "Horizontal metrics:"
puts "  Ascent: #{font.ascent}"
puts "  Descent: #{font.descent}"
puts ""
if font.has_vertical_metrics?
  puts "Vertical metrics:"
  puts "  Vertical ascent: #{font.vertical_ascent}"
  puts "  Vertical descent: #{font.vertical_descent}"
else
  puts "Note: This font doesn't have vhea/vmtx tables"
  puts "We'll simulate vertical layout using horizontal metrics"
end

puts "\n2. Creating Comparison Image"
puts "-" * 40

width, height = 800, 600
img = CrImage.rgba(width, height, CrImage::Color::WHITE)

text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
text = "VERTICAL"

# Create drawer (reusable for all text)
drawer = CrImage::Font::Drawer.new(img, text_color, face)
label_face = FreeType::TrueType.new_face(font, 16.0)
label_drawer = CrImage::Font::Drawer.new(img, text_color, label_face)

# Draw horizontal text (normal)
puts "Drawing horizontal text..."
label_drawer.draw_text("Horizontal Layout", 50, 70)
drawer.draw_text(text, 50, 100)

# Draw vertical text using the high-level API
puts "Drawing vertical text..."
label_drawer.draw_text("Vertical Layout", 350, 130)
label_drawer.draw_text("(draw_vertical_text)", 350, 150)
drawer.draw_vertical_text(text, 400, 180)

# Draw rotated text (90 degrees clockwise)
puts "Drawing rotated text..."
label_drawer.draw_text("Rotated 90°", 580, 130)

# Create a separate image for rotation
rot_img = CrImage.rgba(300, 100, CrImage::Color::WHITE)
rot_drawer = CrImage::Font::Drawer.new(rot_img, text_color, face)
rot_drawer.draw_text(text, 10, 60)

# Rotate 90 degrees clockwise and composite
rotated = rot_img.rotate_90
x_offset, y_offset = 600, 200
rotated.bounds.height.times do |y|
  rotated.bounds.width.times do |x|
    dst_x = x_offset + x
    dst_y = y_offset + y
    next if dst_x >= width || dst_y >= height

    color = rotated.at(x, y).as(CrImage::Color::RGBA)
    # Only copy non-white pixels
    if color.r < 250 || color.g < 250 || color.b < 250
      img.set(dst_x, dst_y, color)
    end
  end
end

CrImage::PNG.write("vertical_text.png", img)
puts "\nSaved: vertical_text.png"

puts "\n3. Metrics Comparison"
puts "-" * 40
test_chars = ['V', 'E', 'R', 'T']
test_chars.each do |char|
  glyph_idx = font.glyph_index(char)
  if glyph_idx > 0
    h_advance, h_lsb = font.h_metrics(glyph_idx)
    v_advance, v_tsb = font.v_metrics(glyph_idx)

    puts "Glyph '#{char}':"
    puts "  Horizontal: advance=#{h_advance}, lsb=#{h_lsb}"
    if font.has_vertical_metrics?
      puts "  Vertical: advance=#{v_advance}, tsb=#{v_tsb}"
    else
      puts "  Vertical: (using line height fallback)"
    end
  end
end

puts "\n" + "=" * 50
puts "Summary:"
puts "=" * 50
puts "✓ Horizontal text: draw_text(text, x, y)"
puts "✓ Vertical text: draw_vertical_text(text, x, y)"
puts "✓ Rotated text: image rotation"
puts "\nFor true vertical CJK text, you need:"
puts "  • Font with vhea/vmtx tables"
puts "  • Glyph rotation for punctuation"
puts "  • Vertical glyph variants"
