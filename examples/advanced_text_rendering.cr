require "../src/crimage"
require "../src/freetype"

# Advanced text rendering examples

puts "Advanced Text Rendering Demo"
puts "=" * 50

# Check if font exists
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
unless File.exists?(font_path)
  puts "Error: Font not found at #{font_path}"
  puts "Please download Roboto font from Google Fonts"
  puts "See fonts/README.md for instructions"
  exit 1
end

# Load font
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 48.0)

# Create canvas with gradient background
width, height = 800, 600
img = CrImage.gradient(width, height,
  CrImage::Color::RGBA.new(200, 200, 220, 255),
  CrImage::Color::RGBA.new(150, 150, 170, 255),
  :vertical)

# 1. Basic text rendering
puts "\n1. Basic text rendering"
text_color = CrImage::Uniform.new(CrImage::Color::BLACK)
dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[100 * 64]
)
drawer = CrImage::Font::Drawer.new(img, text_color, face, dot)
drawer.draw("Hello, Crystal!")
puts "Drew basic text"

# 2. Multi-line text with word wrapping
puts "\n2. Multi-line text"
dot2 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[200 * 64]
)
drawer2 = CrImage::Font::Drawer.new(img, text_color, face, dot2)
long_text = "This is a longer text that demonstrates automatic word wrapping. " \
            "The text will break at word boundaries to fit within the specified width."
drawer2.draw_multiline(long_text, max_width: 700, line_spacing: 1.5)
puts "Drew multi-line text with word wrapping"

# 3. Text alignment
puts "\n3. Text alignment"
small_face = FreeType::TrueType.new_face(font, 32.0)

# Center aligned
text_box_center = CrImage::Font::TextBox.new(
  CrImage.rect(50, 350, 750, 400),
  h_align: CrImage::Font::HorizontalAlign::Center,
  v_align: CrImage::Font::VerticalAlign::Middle
)
dot3 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[0],
  CrImage::Math::Fixed::Int26_6[0]
)
drawer3 = CrImage::Font::Drawer.new(img, text_color, small_face, dot3)
drawer3.draw_aligned("Centered Text", text_box_center)
puts "Drew centered text"

# Right aligned
text_box_right = CrImage::Font::TextBox.new(
  CrImage.rect(50, 420, 750, 470),
  h_align: CrImage::Font::HorizontalAlign::Right,
  v_align: CrImage::Font::VerticalAlign::Middle
)
drawer4 = CrImage::Font::Drawer.new(img, text_color, small_face, dot3)
drawer4.draw_aligned("Right Aligned", text_box_right)
puts "Drew right-aligned text"

# Save result
CrImage::PNG.write("output/advanced_text.png", img)
puts "\nSaved: output/advanced_text.png"

# 4. Text with effects (separate image)
puts "\n4. Text with effects"
effects_img = CrImage.rgba(600, 200, CrImage::Color::WHITE)

large_face = FreeType::TrueType.new_face(font, 64.0)
dot5 = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],
  CrImage::Math::Fixed::Int26_6[100 * 64]
)

# Text with shadow
shadow = CrImage::Font::Shadow.new(
  offset_x: 3,
  offset_y: 3,
  blur_radius: 5,
  color: CrImage::Color::RGBA.new(128, 128, 128, 180)
)
style_shadow = CrImage::Font::TextStyle.new(shadow: shadow)
drawer5 = CrImage::Font::Drawer.new(effects_img, text_color, large_face, dot5)
drawer5.draw_styled("Shadow Text", style_shadow)

CrImage::PNG.write("output/text_shadow.png", effects_img)
puts "Saved: output/text_shadow.png"

# Text with outline
outline_img = CrImage.rgba(600, 200, CrImage::Color::WHITE)

outline = CrImage::Font::Outline.new(
  thickness: 3,
  color: CrImage::Color::BLUE
)
style_outline = CrImage::Font::TextStyle.new(outline: outline)
drawer6 = CrImage::Font::Drawer.new(outline_img, text_color, large_face, dot5)
drawer6.draw_styled("Outline Text", style_outline)

CrImage::PNG.write("output/text_outline.png", outline_img)
puts "Saved: output/text_outline.png"

puts "\nText rendering features demonstrated:"
puts "- Basic text rendering with TrueType fonts"
puts "- Multi-line text with word wrapping"
puts "- Text alignment (left, center, right)"
puts "- Text effects (shadows, outlines)"
puts "- Configurable line spacing"
