require "../src/crimage"
require "../src/freetype"

# Load a font
font_path = "fonts/Roboto/static/Roboto-Bold.ttf"
unless File.exists?(font_path)
  puts "Font file not found: #{font_path}"
  puts "Please ensure the font file exists."
  exit 1
end

# Create a face from the font
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, 48.0)

# Create an image with a light blue background
img = CrImage.rgba(800, 400, CrImage::Color.rgb(200, 220, 240))

# Create a drawer with white text
src = CrImage::Uniform.new(CrImage::Color::WHITE)
drawer = CrImage::Font::Drawer.new(img, src, face)

# Clean API - one method with options!
drawer.draw_text("Text with Shadow", 50, 100, shadow: true)
drawer.draw_text("Text with Outline", 50, 180, outline: true)
drawer.draw_text("Normal Text", 50, 260)
drawer.draw_text("Underlined Text", 50, 340, underline: true)

# Save the result
CrImage::PNG.write("text_effects_demo.png", img)
