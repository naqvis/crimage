require "../src/crimage"

# Example: Advanced Color Quantization
#
# Demonstrates different palette generation algorithms for optimal
# color reduction: median cut, octree, and popularity.
#
# Usage:
#   crystal run examples/quantization_demo.cr

puts "Advanced Color Quantization Demo"
puts "=" * 50

# Create a colorful test image
img = CrImage.rgba(400, 400)

# Create regions with different colors
100.times do |y|
  400.times do |x|
    r = (x * 255 // 400).to_u8
    g = (y * 255 // 100).to_u8
    b = 128_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

(100...200).each do |y|
  400.times do |x|
    r = 200_u8
    g = (x * 255 // 400).to_u8
    b = ((y - 100) * 255 // 100).to_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

(200...300).each do |y|
  400.times do |x|
    r = ((x + y - 200) * 255 // 500).to_u8
    g = 150_u8
    b = (x * 255 // 400).to_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

(300...400).each do |y|
  400.times do |x|
    r = ((y - 300) * 255 // 100).to_u8
    g = (x * 255 // 400).to_u8
    b = ((x + y - 300) * 255 // 800).to_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

CrImage::PNG.write("quant_original.png", img)
puts "Created colorful test image"

# Test different palette sizes
[16, 32, 64].each do |colors|
  puts "\nGenerating #{colors}-color palettes..."

  # Median Cut algorithm
  palette_mc = CrImage::Util::Quantization.generate_palette(
    img, colors, CrImage::Util::QuantizationAlgorithm::MedianCut
  )
  dithered_mc = img.dither(palette_mc)
  CrImage::PNG.write("quant_mediancut_#{colors}.png", dithered_mc)
  puts "Median Cut (divides color space by median)"

  # Octree algorithm
  palette_oct = CrImage::Util::Quantization.generate_palette(
    img, colors, CrImage::Util::QuantizationAlgorithm::Octree
  )
  dithered_oct = img.dither(palette_oct)
  CrImage::PNG.write("quant_octree_#{colors}.png", dithered_oct)
  puts "Octree (tree-based color clustering)"

  # Popularity algorithm
  palette_pop = CrImage::Util::Quantization.generate_palette(
    img, colors, CrImage::Util::QuantizationAlgorithm::Popularity
  )
  dithered_pop = img.dither(palette_pop)
  CrImage::PNG.write("quant_popularity_#{colors}.png", dithered_pop)
  puts "Popularity (most frequent colors)"
end

# Compare with simple uniform quantization
puts "\nComparing with uniform quantization..."
simple_colors = [
  CrImage::Color.rgba(0, 0, 0, 255),
  CrImage::Color.rgba(128, 0, 0, 255),
  CrImage::Color.rgba(255, 0, 0, 255),
  CrImage::Color.rgba(0, 128, 0, 255),
  CrImage::Color.rgba(128, 128, 0, 255),
  CrImage::Color.rgba(255, 128, 0, 255),
  CrImage::Color.rgba(0, 255, 0, 255),
  CrImage::Color.rgba(128, 255, 0, 255),
  CrImage::Color.rgba(255, 255, 0, 255),
  CrImage::Color.rgba(0, 0, 128, 255),
  CrImage::Color.rgba(128, 0, 128, 255),
  CrImage::Color.rgba(255, 0, 128, 255),
  CrImage::Color.rgba(0, 128, 128, 255),
  CrImage::Color.rgba(128, 128, 128, 255),
  CrImage::Color.rgba(255, 128, 128, 255),
  CrImage::Color.rgba(255, 255, 255, 255),
] of CrImage::Color::Color

simple_palette = CrImage::Color::Palette.new(simple_colors)
simple_dithered = img.dither(simple_palette)
CrImage::PNG.write("quant_simple_16.png", simple_dithered)
puts "Simple uniform palette (for comparison)"

puts "\n" + "=" * 50
puts "Algorithm Comparison"
puts "=" * 50
puts "Median Cut:"
puts "  • Divides color space recursively by median values"
puts "  • Good balance of quality and speed"
puts "  • Best for images with varied colors"
puts ""
puts "Octree:"
puts "  • Uses tree structure for hierarchical clustering"
puts "  • Excellent quality, slightly slower"
puts "  • Best for natural images"
puts ""
puts "Popularity:"
puts "  • Selects most frequently occurring colors"
puts "  • Very fast, simpler results"
puts "  • Best for images with dominant colors"
puts ""
puts "Simple Uniform:"
puts "  • Fixed palette, no analysis"
puts "  • Fastest but lowest quality"
puts "  • Notice the difference!"

puts "\n" + "=" * 50
puts "Output Files"
puts "=" * 50
puts "  quant_original.png           - Original full-color image"
puts "  quant_mediancut_*.png        - Median cut algorithm"
puts "  quant_octree_*.png           - Octree algorithm"
puts "  quant_popularity_*.png       - Popularity algorithm"
puts "  quant_simple_16.png          - Simple uniform palette"
puts "\nCompare the quality differences between algorithms!"
