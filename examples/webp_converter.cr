require "../src/crimage"
require "option_parser"

# WebP Converter Example
# Demonstrates converting images to/from WebP format with various options

input_file = ""
output_file = ""
use_extended = false
show_info = false

OptionParser.parse do |parser|
  parser.banner = "Usage: webp_converter [options] input_file output_file"

  parser.on("-e", "--extended", "Use extended VP8X format (for metadata support)") do
    use_extended = true
  end

  parser.on("-i", "--info", "Show image information only (no conversion)") do
    show_info = true
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.unknown_args do |args|
    if args.size < 1
      puts "Error: Input file required"
      puts parser
      exit(1)
    end
    input_file = args[0]
    output_file = args[1]? || ""
  end
end

if input_file.empty?
  puts "Error: Input file required"
  exit(1)
end

unless File.exists?(input_file)
  puts "Error: Input file '#{input_file}' not found"
  exit(1)
end

# Read image configuration
puts "Reading: #{input_file}"
config = CrImage.read_config(input_file)
puts "  Format: #{config.color_model.name}"
puts "  Size: #{config.width}x#{config.height}"

if show_info
  # Just show info and exit
  if input_file.ends_with?(".webp")
    # Show WebP-specific info
    img = CrImage::WEBP.read(input_file)
    puts "  Opaque: #{img.opaque?}"
    puts "  Bounds: #{img.bounds}"
  end
  exit(0)
end

if output_file.empty?
  puts "Error: Output file required for conversion"
  exit(1)
end

# Read the full image
puts "\nLoading image..."
img = CrImage.read(input_file)
puts "  Loaded: #{img.bounds.width}x#{img.bounds.height} pixels"

# Determine output format and convert
output_ext = File.extname(output_file).downcase

case output_ext
when ".webp"
  puts "\nConverting to WebP (VP8L lossless)..."
  options = CrImage::WEBP::Options.new(use_extended_format: use_extended)

  if use_extended
    puts "  Using VP8X extended format"
  else
    puts "  Using standard VP8L format"
  end

  CrImage::WEBP.write(output_file, img, options)
when ".png"
  puts "\nConverting to PNG..."
  CrImage::PNG.write(output_file, img)
when ".jpg", ".jpeg"
  puts "\nConverting to JPEG..."
  CrImage::JPEG.write(output_file, img, 90)
when ".bmp"
  puts "\nConverting to BMP..."
  CrImage::BMP.write(output_file, img)
when ".gif"
  puts "\nConverting to GIF..."
  CrImage::GIF.write(output_file, img)
when ".tiff", ".tif"
  puts "\nConverting to TIFF..."
  CrImage::TIFF.write(output_file, img)
else
  puts "Error: Unsupported output format '#{output_ext}'"
  puts "Supported formats: .webp, .png, .jpg, .jpeg, .bmp, .gif, .tiff, .tif"
  exit(1)
end

# Show output file info
output_size = File.size(output_file)
input_size = File.size(input_file)
ratio = (output_size.to_f / input_size.to_f * 100).round(2)

puts "\nConversion complete!"
puts "  Output: #{output_file}"
puts "  Size: #{output_size} bytes (#{ratio}% of input)"

if output_size < input_size
  saved = input_size - output_size
  saved_pct = ((1.0 - output_size.to_f / input_size.to_f) * 100).round(2)
  puts "  Saved: #{saved} bytes (#{saved_pct}% reduction)"
end
