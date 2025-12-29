require "../src/crimage"
require "../src/freetype"
require "option_parser"

# Example: Draw text on an image using TrueType fonts
#
# Supports multiple output formats: PNG, JPEG, BMP
# Configurable colors, size, and quality
#
# Usage:
#   crystal run examples/draw_text.cr -- [options] <font.ttf> <text>
#
# To get fonts, see fonts/README.md

# Default options
output_file = "text_output.png"
font_path = "fonts/Roboto/static/Roboto-Regular.ttf"
font_size = 72.0
bg_color = "white"
text_color = "black"
quality = 95
width = 800
height = 200
text = ""

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run examples/draw_text.cr -- [options] <text>"

  parser.on("-o FILE", "--output=FILE", "Output file (extension determines format: .png, .jpg, .bmp, .gif, .tiff, .webp)") { |f| output_file = f }
  parser.on("-f FONT", "--font=FONT", "Font file path (default: fonts/Roboto/static/Roboto-Regular.ttf)") { |f| font_path = f }
  parser.on("-s SIZE", "--size=SIZE", "Font size (default: 72)") { |s| font_size = s.to_f }
  parser.on("-b COLOR", "--bg=COLOR", "Background color: white, black, transparent (default: white)") { |c| bg_color = c }
  parser.on("-t COLOR", "--text=COLOR", "Text color: white, black (default: black)") { |c| text_color = c }
  parser.on("-q QUALITY", "--quality=QUALITY", "JPEG quality 1-100 (default: 95)") { |q| quality = q.to_i }
  parser.on("-W WIDTH", "--width=WIDTH", "Image width (default: 800)") { |w| width = w.to_i }
  parser.on("-H HEIGHT", "--height=HEIGHT", "Image height (default: 200)") { |h| height = h.to_i }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    puts ""
    puts "Examples:"
    puts "  # PNG with black text on white (default font)"
    puts "  crystal run examples/draw_text.cr -- 'Hello World'"
    puts ""
    puts "  # JPEG with white text on black, custom font"
    puts "  crystal run examples/draw_text.cr -- -o output.jpg -b black -t white -f fonts/Roboto/static/Roboto-Bold.ttf 'Hello!'"
    puts ""
    puts "  # PNG with transparent background"
    puts "  crystal run examples/draw_text.cr -- -o logo.png -b transparent 'LOGO'"
    puts ""
    puts "  # WebP with transparent background"
    puts "  crystal run examples/draw_text.cr -- -o logo.webp -b transparent 'LOGO'"
    puts ""
    puts "  # High quality JPEG with large font"
    puts "  crystal run examples/draw_text.cr -- -o text.jpg -q 100 -s 96 'Quality 100'"
    exit
  end
end

if ARGV.size < 1
  puts "Error: Missing text argument"
  puts "Usage: crystal run examples/draw_text.cr -- [options] <text>"
  puts "Use --help for more information"
  exit 1
end

text = ARGV[0]

unless File.exists?(font_path)
  puts "Error: Font file not found: #{font_path}"
  puts ""
  puts "Download fonts from:"
  puts "  - Google Fonts: https://fonts.google.com/"
  puts "  - Or see fonts/README.md for more options"
  exit 1
end

# Load TrueType font
font = FreeType::TrueType.load(font_path)
face = FreeType::TrueType.new_face(font, font_size)

# Create image
image = CrImage.rgba(width, height)

# Parse and apply background color
bg = case bg_color.downcase
     when "white"
       CrImage::Uniform.new(CrImage::Color::RGBA.new(255, 255, 255, 255))
     when "black"
       CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
     when "transparent"
       CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 0))
     else
       puts "Warning: Unknown background color '#{bg_color}', using white"
       CrImage::Uniform.new(CrImage::Color::RGBA.new(255, 255, 255, 255))
     end

CrImage::Draw.draw(image, image.bounds, bg, CrImage::Point.zero, CrImage::Draw::Op::SRC)

# Parse and apply text color
txt_color = case text_color.downcase
            when "white"
              CrImage::Uniform.new(CrImage::Color::RGBA.new(255, 255, 255, 255))
            when "black"
              CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
            else
              puts "Warning: Unknown text color '#{text_color}', using black"
              CrImage::Uniform.new(CrImage::Color::RGBA.new(0, 0, 0, 255))
            end

# Create drawer
dot = CrImage::Math::Fixed::Point26_6.new(
  CrImage::Math::Fixed::Int26_6[50 * 64],               # x = 50 pixels
  CrImage::Math::Fixed::Int26_6[(height * 2 // 3) * 64] # y = 2/3 down (baseline)
)
drawer = CrImage::Font::Drawer.new(image, txt_color, face, dot)

# Draw text
drawer.draw(text)

# Save image based on file extension
ext = File.extname(output_file).downcase
case ext
when ".png"
  CrImage::PNG.write(output_file, image)
when ".jpg", ".jpeg"
  CrImage::JPEG.write(output_file, image, quality)
when ".bmp"
  CrImage::BMP.write(output_file, image)
when ".gif"
  CrImage::GIF.write(output_file, image)
when ".tif", ".tiff"
  CrImage::TIFF.write(output_file, image)
when ".webp"
  CrImage::WEBP.write(output_file, image)
else
  puts "Warning: Unknown extension '#{ext}', saving as PNG"
  output_file = output_file.sub(/#{ext}$/, ".png")
  CrImage::PNG.write(output_file, image)
end

puts "Created #{output_file}"
puts "  Size: #{width}x#{height}"
puts "  Font: #{File.basename(font_path)} @ #{font_size}pt"
puts "  Text: '#{text}'"
puts "  Colors: #{text_color} on #{bg_color}"
puts "  Format: #{ext.upcase.sub(".", "")}" + (ext =~ /\.jpe?g/ ? " (quality #{quality})" : "")
