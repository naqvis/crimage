require "../src/crimage"
require "../src/freetype"
require "option_parser"

# Example: CAPTCHA Generator
#
# Generates CAPTCHA-like images with distorted text, noise, and interference lines
# to demonstrate text rendering, drawing operations, and image manipulation.
#
# Features:
# - Random text generation
# - Text distortion and rotation
# - Background noise
# - Interference lines
# - Color variations
#
# Usage:
#   crystal run examples/generate_captcha.cr -- [options]
#   crystal run examples/generate_captcha.cr -- -t "ABC123" -o captcha.png

# Configuration
text = ""
output_file = "captcha.png"
font_path = "fonts/Roboto/static/Roboto-Bold.ttf"
width = 300
height = 100
noise_level = 25
line_count = 6

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run examples/generate_captcha.cr -- [options]"

  parser.on("-t TEXT", "--text=TEXT", "CAPTCHA text (default: random 6 chars)") { |t| text = t }
  parser.on("-o FILE", "--output=FILE", "Output file (default: captcha.png)") { |f| output_file = f }
  parser.on("-f FONT", "--font=FONT", "Font file path") { |f| font_path = f }
  parser.on("-w WIDTH", "--width=WIDTH", "Image width (default: 300)") { |w| width = w.to_i }
  parser.on("-h HEIGHT", "--height=HEIGHT", "Image height (default: 100)") { |h| height = h.to_i }
  parser.on("-n LEVEL", "--noise=LEVEL", "Noise level 0-100 (default: 25)") { |n| noise_level = n.to_i }
  parser.on("-l COUNT", "--lines=COUNT", "Number of interference lines (default: 6)") { |l| line_count = l.to_i }
  parser.on("--help", "Show this help") do
    puts parser
    puts ""
    puts "Examples:"
    puts "  # Generate random CAPTCHA"
    puts "  crystal run examples/generate_captcha.cr"
    puts ""
    puts "  # Generate with specific text"
    puts "  crystal run examples/generate_captcha.cr -- -t \"HELLO\" -o hello.png"
    puts ""
    puts "  # Generate as WebP"
    puts "  crystal run examples/generate_captcha.cr -- -o captcha.webp"
    puts ""
    puts "  # High noise CAPTCHA"
    puts "  crystal run examples/generate_captcha.cr -- -n 60 -l 10"
    puts ""
    puts "Note: Requires a TrueType font file. See fonts/README.md for setup."
    exit
  end
end

# Generate random text if not provided
if text.empty?
  text = CrImage::Util::Captcha.random_text
end

# Check font exists
unless File.exists?(font_path)
  puts "Error: Font file not found: #{font_path}"
  puts ""
  puts "Please download a font. Quick options:"
  puts "  1. Download Roboto from https://fonts.google.com/specimen/Roboto"
  puts "  2. Extract Roboto-Bold.ttf to fonts/Roboto/static/"
  puts "  3. Or use a system font with -f option"
  puts ""
  puts "See fonts/README.md for more details."
  exit 1
end

puts "Generating CAPTCHA..."
puts "  Text: #{text}"
puts "  Size: #{width}x#{height}"
puts "  Noise: #{noise_level}%"
puts "  Lines: #{line_count}"

# Generate CAPTCHA using utility
options = CrImage::Util::Captcha::Options.new(
  width: width,
  height: height,
  noise_level: noise_level,
  line_count: line_count
)

image = CrImage::Util::Captcha.generate(text, font_path, options)

# Save output
ext = File.extname(output_file).downcase
case ext
when ".png"
  CrImage::PNG.write(output_file, image)
when ".jpg", ".jpeg"
  CrImage::JPEG.write(output_file, image, 90)
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

puts "CAPTCHA generated: #{output_file}"
puts ""
puts "CAPTCHA Text: #{text}"
puts "(Save this for verification!)"
