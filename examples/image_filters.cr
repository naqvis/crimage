require "../src/crimage"
require "option_parser"

# Example: Apply various image filters and transformations
#
# Usage:
#   crystal run examples/image_filters.cr -- <input> <output> [options]

input_file = ""
output_file = ""
operation = "resize"
width = 800
height = 600
radius = 2
amount = 1.0
adjustment = 50
angle = 90

OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run examples/image_filters.cr -- <input> <output> [options]"

  parser.on("-o OP", "--operation=OP", "Operation: resize, rotate, flip-h, flip-v, blur, sharpen, brightness, contrast, grayscale, invert, crop") { |op| operation = op }
  parser.on("-w WIDTH", "--width=WIDTH", "Width for resize (default: 800)") { |w| width = w.to_i }
  parser.on("-h HEIGHT", "--height=HEIGHT", "Height for resize (default: 600)") { |h| height = h.to_i }
  parser.on("-r RADIUS", "--radius=RADIUS", "Radius for blur (default: 2)") { |r| radius = r.to_i }
  parser.on("-a AMOUNT", "--amount=AMOUNT", "Amount for sharpen (default: 1.0)") { |a| amount = a.to_f }
  parser.on("-b ADJUST", "--brightness=ADJUST", "Brightness adjustment -255 to 255 (default: 50)") { |b| adjustment = b.to_i }
  parser.on("-c FACTOR", "--contrast=FACTOR", "Contrast factor 0.0 to 2.0 (default: 1.5)") { |c| amount = c.to_f }
  parser.on("-A ANGLE", "--angle=ANGLE", "Rotation angle: 90, 180, 270 (default: 90)") { |a| angle = a.to_i }
  parser.on("--help", "Show this help") do
    puts parser
    puts ""
    puts "Examples:"
    puts "  # Resize image"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o resize -w 400 -h 300"
    puts ""
    puts "  # Convert WEBP to PNG"
    puts "  crystal run examples/image_filters.cr -- input.webp output.png -o resize -w 800 -h 600"
    puts ""
    puts "  # Convert PNG to WEBP"
    puts "  crystal run examples/image_filters.cr -- input.png output.webp -o resize -w 800 -h 600"
    puts ""
    puts "  # Rotate 90 degrees"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o rotate -A 90"
    puts ""
    puts "  # Apply blur"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o blur -r 3"
    puts ""
    puts "  # Sharpen image"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o sharpen -a 1.5"
    puts ""
    puts "  # Adjust brightness"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o brightness -b 50"
    puts ""
    puts "  # Convert to grayscale"
    puts "  crystal run examples/image_filters.cr -- input.png output.png -o grayscale"
    exit
  end
end

if ARGV.size < 2
  puts "Error: Missing input and output files"
  puts "Usage: crystal run examples/image_filters.cr -- <input> <output> [options]"
  puts "Use --help for more information"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]

unless File.exists?(input_file)
  puts "Error: Input file not found: #{input_file}"
  exit 1
end

puts "Loading image: #{input_file}"
src = CrImage.read(input_file)
puts "  Size: #{src.bounds.width}x#{src.bounds.height}"

puts "Applying operation: #{operation}"
result = case operation
         when "resize"
           puts "  Resizing to #{width}x#{height} (bilinear)"
           CrImage::Transform.resize_bilinear(src, width, height)
         when "resize-fast"
           puts "  Resizing to #{width}x#{height} (nearest neighbor)"
           CrImage::Transform.resize_nearest(src, width, height)
         when "rotate"
           case angle
           when 90
             puts "  Rotating 90° clockwise"
             CrImage::Transform.rotate_90(src)
           when 180
             puts "  Rotating 180°"
             CrImage::Transform.rotate_180(src)
           when 270
             puts "  Rotating 270° clockwise"
             CrImage::Transform.rotate_270(src)
           else
             puts "Error: Invalid angle #{angle}. Use 90, 180, or 270"
             exit 1
           end
         when "flip-h"
           puts "  Flipping horizontally"
           CrImage::Transform.flip_horizontal(src)
         when "flip-v"
           puts "  Flipping vertically"
           CrImage::Transform.flip_vertical(src)
         when "blur"
           puts "  Applying box blur (radius: #{radius})"
           CrImage::Transform.blur_box(src, radius)
         when "sharpen"
           puts "  Sharpening (amount: #{amount})"
           CrImage::Transform.sharpen(src, amount)
         when "brightness"
           puts "  Adjusting brightness (#{adjustment > 0 ? "+" : ""}#{adjustment})"
           CrImage::Transform.brightness(src, adjustment)
         when "contrast"
           puts "  Adjusting contrast (factor: #{amount})"
           CrImage::Transform.contrast(src, amount)
         when "grayscale"
           puts "  Converting to grayscale"
           CrImage::Transform.grayscale(src)
         when "invert"
           puts "  Inverting colors"
           CrImage::Transform.invert(src)
         when "crop"
           crop_rect = CrImage.rect(
             src.bounds.width // 4,
             src.bounds.height // 4,
             src.bounds.width * 3 // 4,
             src.bounds.height * 3 // 4
           )
           puts "  Cropping to center 50%"
           CrImage::Transform.crop(src, crop_rect)
         else
           puts "Error: Unknown operation '#{operation}'"
           puts "Valid operations: resize, rotate, flip-h, flip-v, blur, sharpen, brightness, contrast, grayscale, invert, crop"
           exit 1
         end

puts "Saving result: #{output_file}"
ext = File.extname(output_file).downcase
case ext
when ".png"
  CrImage::PNG.write(output_file, result)
when ".jpg", ".jpeg"
  CrImage::JPEG.write(output_file, result, 95)
when ".bmp"
  CrImage::BMP.write(output_file, result)
when ".gif"
  CrImage::GIF.write(output_file, result)
when ".tif", ".tiff"
  CrImage::TIFF.write(output_file, result)
when ".webp"
  CrImage::WEBP.write(output_file, result)
else
  puts "Warning: Unknown extension '#{ext}', saving as PNG"
  output_file = output_file.sub(/#{ext}$/, ".png")
  CrImage::PNG.write(output_file, result)
end

puts "Done!"
puts "  Output size: #{result.bounds.width}x#{result.bounds.height}"
puts "  Format: #{ext.upcase.sub(".", "")}"
