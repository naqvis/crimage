require "../src/crimage"

# Example: Advanced Dithering
#
# Demonstrates various dithering algorithms for reducing color depth
# while maintaining visual quality through error diffusion.
#
# Usage:
#   crystal run examples/dithering_demo.cr

puts "Advanced Dithering Demo"
puts "=" * 50

# Create a colorful gradient image
img = CrImage.rgba(400, 400)

400.times do |y|
  400.times do |x|
    r = (x * 255 // 400).to_u8
    g = (y * 255 // 400).to_u8
    b = ((x + y) * 255 // 800).to_u8
    img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

CrImage::PNG.write("dither_original.png", img)
puts "Created gradient image"

# Create a limited palette (16 colors)
palette = CrImage::Color::Palette.new([
  CrImage::Color.rgba(0, 0, 0, 255),
  CrImage::Color.rgba(128, 0, 0, 255),
  CrImage::Color.rgba(0, 128, 0, 255),
  CrImage::Color.rgba(128, 128, 0, 255),
  CrImage::Color.rgba(0, 0, 128, 255),
  CrImage::Color.rgba(128, 0, 128, 255),
  CrImage::Color.rgba(0, 128, 128, 255),
  CrImage::Color.rgba(192, 192, 192, 255),
  CrImage::Color.rgba(128, 128, 128, 255),
  CrImage::Color.rgba(255, 0, 0, 255),
  CrImage::Color.rgba(0, 255, 0, 255),
  CrImage::Color.rgba(255, 255, 0, 255),
  CrImage::Color.rgba(0, 0, 255, 255),
  CrImage::Color.rgba(255, 0, 255, 255),
  CrImage::Color.rgba(0, 255, 255, 255),
  CrImage::Color.rgba(255, 255, 255, 255),
] of CrImage::Color::Color)

puts "Created 16-color palette"

# Floyd-Steinberg dithering (most common)
floyd = img.dither(palette, CrImage::Util::DitheringAlgorithm::FloydSteinberg)
CrImage::PNG.write("dither_floyd_steinberg.png", floyd)
puts "Applied Floyd-Steinberg dithering"

# Atkinson dithering (lighter, more artistic)
atkinson = img.dither(palette, CrImage::Util::DitheringAlgorithm::Atkinson)
CrImage::PNG.write("dither_atkinson.png", atkinson)
puts "Applied Atkinson dithering"

# Sierra dithering (more error diffusion)
sierra = img.dither(palette, CrImage::Util::DitheringAlgorithm::Sierra)
CrImage::PNG.write("dither_sierra.png", sierra)
puts "Applied Sierra dithering"

# Burkes dithering
burkes = img.dither(palette, CrImage::Util::DitheringAlgorithm::Burkes)
CrImage::PNG.write("dither_burkes.png", burkes)
puts "Applied Burkes dithering"

# Stucki dithering
stucki = img.dither(palette, CrImage::Util::DitheringAlgorithm::Stucki)
CrImage::PNG.write("dither_stucki.png", stucki)
puts "Applied Stucki dithering"

# Ordered (Bayer matrix) dithering
ordered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Ordered)
CrImage::PNG.write("dither_ordered.png", ordered)
puts "Applied ordered (Bayer) dithering"

# Create a simple 2-color (black & white) palette
bw_palette = CrImage::Color::Palette.new([
  CrImage::Color::BLACK,
  CrImage::Color::WHITE,
] of CrImage::Color::Color)

# Apply to grayscale version
gray = img.grayscale
bw_floyd = gray.dither(bw_palette)
CrImage::PNG.write("dither_bw_floyd.png", bw_floyd)
puts "Applied black & white Floyd-Steinberg"

bw_atkinson = gray.dither(bw_palette, CrImage::Util::DitheringAlgorithm::Atkinson)
CrImage::PNG.write("dither_bw_atkinson.png", bw_atkinson)
puts "Applied black & white Atkinson"

bw_ordered = gray.dither(bw_palette, CrImage::Util::DitheringAlgorithm::Ordered)
CrImage::PNG.write("dither_bw_ordered.png", bw_ordered)
puts "Applied black & white ordered"

puts "\nOutput files:"
puts "  - dither_original.png (full color gradient)"
puts "  - dither_floyd_steinberg.png (most common)"
puts "  - dither_atkinson.png (lighter, artistic)"
puts "  - dither_sierra.png (more diffusion)"
puts "  - dither_burkes.png"
puts "  - dither_stucki.png"
puts "  - dither_ordered.png (Bayer matrix, regular pattern)"
puts "  - dither_bw_*.png (black & white versions)"
puts "\nCompare the different algorithms to see their characteristics!"
