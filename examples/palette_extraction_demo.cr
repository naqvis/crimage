require "../src/crimage"

# Palette Extraction Demo
# Demonstrates extracting dominant colors from images

puts "=== Palette Extraction Demo ===\n"

# Create a sample image with multiple colors
puts "Creating sample image..."
img = CrImage.rgba(200, 200)

# Fill with gradient and shapes
200.times do |y|
  200.times do |x|
    if x < 50
      img.set(x, y, CrImage::Color::RED)
    elsif x < 100
      img.set(x, y, CrImage::Color::BLUE)
    elsif x < 150
      img.set(x, y, CrImage::Color::GREEN)
    else
      img.set(x, y, CrImage::Color::YELLOW)
    end
  end
end

# Add some circles
img.draw_circle(50, 50, 30, color: CrImage::Color::PURPLE, fill: true)
img.draw_circle(150, 150, 40, color: CrImage::Color::ORANGE, fill: true)

CrImage::PNG.write("sample_palette.png", img)
puts "Loaded image: #{img.bounds.width}x#{img.bounds.height}"

# Extract 5 dominant colors
puts "\n1. Extract 5 dominant colors:"
colors = img.extract_palette(5)
colors.each_with_index do |color, i|
  r, g, b, _ = color.rgba
  hex = "#%02X%02X%02X" % [r >> 8, g >> 8, b >> 8]
  puts "  Color #{i + 1}: #{hex}"
end

# Extract colors with weights
puts "\n2. Extract colors with frequency:"
weighted_colors = img.extract_palette_with_weights(5)
weighted_colors.each_with_index do |(color, weight), i|
  r, g, b, _ = color.rgba
  hex = "#%02X%02X%02X" % [r >> 8, g >> 8, b >> 8]
  percentage = (weight * 100).round(1)
  puts "  Color #{i + 1}: #{hex} (#{percentage}%)"
end

# Get single dominant color
puts "\n3. Most dominant color:"
dominant = img.dominant_color
r, g, b, _ = dominant.rgba
hex = "#%02X%02X%02X" % [r >> 8, g >> 8, b >> 8]
puts "  #{hex}"

# Try different algorithms
puts "\n4. Compare algorithms:"
[:median_cut, :octree, :popularity].each do |algo|
  colors = img.extract_palette(3, CrImage::Util::QuantizationAlgorithm.parse(algo.to_s))
  print "  #{algo}: "
  colors.each do |color|
    r, g, b, _ = color.rgba
    hex = "#%02X%02X%02X" % [r >> 8, g >> 8, b >> 8]
    print "#{hex} "
  end
  puts
end

# Visualize palette
puts "\n5. Creating palette visualization..."
palette_colors = img.extract_palette(8)
swatch_width = 100
swatch_height = 100
palette_img = CrImage.rgba(swatch_width * palette_colors.size, swatch_height)

palette_colors.each_with_index do |color, i|
  x_start = i * swatch_width
  swatch_height.times do |y|
    swatch_width.times do |x|
      palette_img.set(x_start + x, y, color)
    end
  end
end

CrImage::PNG.write("palette_swatches.png", palette_img)
puts "  Saved palette_swatches.png"
