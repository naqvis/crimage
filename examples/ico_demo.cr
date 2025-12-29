require "../src/crimage"

# Example: ICO (Windows Icon) Format
#
# Demonstrates creating and reading ICO files with multiple resolutions.
# ICO files are commonly used for favicons and application icons.
#
# Usage:
#   crystal run examples/ico_demo.cr

puts "ICO (Windows Icon) Format Demo"
puts "=" * 50

# Create icons at standard sizes
sizes = [16, 32, 48, 64, 128, 256]
icons = [] of CrImage::Image

puts "\nCreating icons at standard sizes..."
sizes.each do |size|
  img = CrImage.rgba(size, size)

  # Create a simple icon design
  # Background gradient
  size.times do |y|
    size.times do |x|
      intensity = (255 * (x + y) // (size * 2)).to_u8
      img.set(x, y, CrImage::Color.rgba(intensity, 100, 255 - intensity, 255))
    end
  end

  # Draw a circle
  center = size // 2
  radius = size // 3
  img.draw_circle(center, center, radius, color: CrImage::Color::WHITE, fill: true)

  # Draw inner circle
  img.draw_circle(center, center, radius // 2, color: CrImage::Color::BLACK, fill: true)

  icons << img
  puts "Created #{size}x#{size} icon"
end

# Write multi-resolution ICO file
CrImage::ICO.write_multi("multi_size.ico", icons)
puts "\nWrote multi_size.ico with #{icons.size} sizes"

# Write single icon
single = CrImage.rgba(32, 32)
32.times do |y|
  32.times do |x|
    r = (x * 255 // 32).to_u8
    g = (y * 255 // 32).to_u8
    single.set(x, y, CrImage::Color.rgba(r, g, 128, 255))
  end
end
CrImage::ICO.write("single.ico", single)
puts "Wrote single.ico (32x32)"

# Read ICO file
puts "\nReading ICO files..."
loaded = CrImage::ICO.read("multi_size.ico")
puts "Loaded largest icon: #{loaded.bounds.width}x#{loaded.bounds.height}"

# Read all sizes
all_icons = CrImage::ICO.read_all("multi_size.ico")
puts "Loaded all #{all_icons.images.size} icons"

# Show available sizes
puts "\nAvailable sizes in multi_size.ico:"
all_icons.entries.each_with_index do |entry, i|
  puts "  #{i + 1}. #{entry.actual_width}x#{entry.actual_height} (#{entry.bit_count}-bit)"
end

# Find specific size
icon_32 = all_icons.find_size(32, 32)
if icon_32
  CrImage::PNG.write("extracted_32.png", icon_32)
  puts "\nExtracted 32x32 icon to PNG"
end

# Get largest and smallest
largest = all_icons.largest
smallest = all_icons.smallest
CrImage::PNG.write("largest.png", largest)
CrImage::PNG.write("smallest.png", smallest)
puts "Extracted largest (#{largest.bounds.width}x#{largest.bounds.height}) and smallest (#{smallest.bounds.width}x#{smallest.bounds.height})"

# Create a favicon
puts "\nCreating favicon.ico..."
favicon_sizes = [16, 32, 48]
favicons = [] of CrImage::Image

favicon_sizes.each do |size|
  fav = CrImage.rgba(size, size, CrImage::Color::WHITE)

  # Draw a simple "F" shape
  bar_width = size // 5
  fav.draw_rect(bar_width, bar_width, bar_width, size - bar_width * 2, fill: CrImage::Color::BLUE)
  fav.draw_rect(bar_width, bar_width, size - bar_width * 2, bar_width, fill: CrImage::Color::BLUE)
  fav.draw_rect(bar_width, size // 2 - bar_width // 2, size // 2, bar_width, fill: CrImage::Color::BLUE)

  favicons << fav
end

CrImage::ICO.write_multi("favicon.ico", favicons)
puts "Created favicon.ico with sizes: #{favicon_sizes.join(", ")}"

puts "\n" + "=" * 50
puts "ICO Format Features"
puts "=" * 50
puts "• Multi-resolution: One file contains multiple sizes"
puts "• Standard sizes: 16, 32, 48, 64, 128, 256 pixels"
puts "• Transparency: Full alpha channel support"
puts "• Compatibility: Works in browsers and Windows"

puts "\n" + "=" * 50
puts "Common Use Cases"
puts "=" * 50
puts "• Website favicons (favicon.ico)"
puts "• Windows application icons"
puts "• Browser bookmarks"
puts "• Desktop shortcuts"

puts "\n" + "=" * 50
puts "Output Files"
puts "=" * 50
puts "  multi_size.ico  - Multi-resolution icon (6 sizes)"
puts "  single.ico      - Single 32x32 icon"
puts "  favicon.ico     - Website favicon (3 sizes)"
puts "  extracted_32.png - Extracted 32x32 as PNG"
puts "  largest.png     - Largest icon as PNG"
puts "  smallest.png    - Smallest icon as PNG"
