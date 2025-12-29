require "../src/crimage"

# Example: Morphological Operations
#
# Morphological operations work on GRAYSCALE images to analyze shape and structure.
# They're used for: noise removal, gap filling, edge detection, and object separation.
#
# Think of them as "shape filters" - they look at brightness patterns, not colors.
#
# Usage:
#   crystal run examples/morphology_demo.cr

puts "Morphological Operations Demo"
puts "=" * 50
puts "Note: Morphology works on grayscale (brightness patterns)"
puts "Output will be black & white showing structure/shape"
puts "=" * 50

# Create a test image with text-like shapes and noise
img = CrImage.rgba(400, 300, CrImage::Color::WHITE)

# Draw some "letters" or shapes
# Letter "H"
img.draw_rect(50, 80, 15, 120, fill: CrImage::Color::BLACK)
img.draw_rect(95, 80, 15, 120, fill: CrImage::Color::BLACK)
img.draw_rect(50, 130, 60, 15, fill: CrImage::Color::BLACK)

# Letter "I"
img.draw_rect(140, 80, 15, 120, fill: CrImage::Color::BLACK)

# Letter "!"
img.draw_rect(185, 80, 15, 90, fill: CrImage::Color::BLACK)
img.draw_rect(185, 180, 15, 20, fill: CrImage::Color::BLACK)

# Add NOISE (small white dots on black areas - simulates scanner noise)
puts "\nAdding noise to simulate real-world imperfections..."
[
  {55, 90}, {60, 100}, {100, 85}, {145, 95}, {190, 90},
  {70, 140}, {85, 145}, {150, 130}, {195, 100},
].each do |x, y|
  img.draw_circle(x, y, 2, color: CrImage::Color::WHITE, fill: true)
end

# Add GAPS (small black dots on white areas - simulates breaks)
[
  {250, 100}, {280, 120}, {320, 110}, {350, 130},
].each do |x, y|
  img.draw_circle(x, y, 3, color: CrImage::Color::BLACK, fill: true)
end

# Draw a broken line (simulates damaged text)
puts "Adding broken line to show gap filling..."
x = 230
while x < 380
  img.draw_rect(x, 150, 8, 8, fill: CrImage::Color::BLACK)
  x += 15 # Gaps between segments
end

CrImage::PNG.write("morph_original.png", img)
puts "Created original image (with noise and gaps)"

puts "\n" + "=" * 50
puts "Applying Morphological Operations"
puts "=" * 50

# EROSION - Removes small bright spots (noise removal)
puts "\n1. EROSION - Removes noise (small white spots)"
puts "   Use case: Clean up scanner noise, remove small artifacts"
eroded = CrImage::Util::Morphology.erode(img, 5)
CrImage::PNG.write("morph_eroded.png", eroded)
puts " Notice: White noise dots are gone!"

# DILATION - Fills small gaps (gap filling)
puts "\n2. DILATION - Fills gaps (small black holes)"
puts "   Use case: Connect broken text, fill small holes"
dilated = CrImage::Util::Morphology.dilate(img, 5)
CrImage::PNG.write("morph_dilated.png", dilated)
puts " Notice: Broken line is now connected!"

# OPENING - Erosion then dilation (best noise removal)
puts "\n3. OPENING - Removes noise while keeping shape"
puts "   Use case: Clean image without changing object size much"
opened = CrImage::Util::Morphology.open(img, 5)
CrImage::PNG.write("morph_opened.png", opened)
puts " Notice: Noise removed, shapes preserved!"

# CLOSING - Dilation then erosion (best gap filling)
puts "\n4. CLOSING - Fills gaps while keeping shape"
puts "   Use case: Repair broken text, connect nearby objects"
closed = CrImage::Util::Morphology.close(img, 5)
CrImage::PNG.write("morph_closed.png", closed)
puts " Notice: Gaps filled, line connected!"

# GRADIENT - Edge detection
puts "\n5. GRADIENT - Detects edges and boundaries"
puts "   Use case: Find object outlines, edge detection"
gradient = CrImage::Util::Morphology.gradient(img, 3)
CrImage::PNG.write("morph_gradient.png", gradient)
puts " Notice: Only edges/outlines are shown!"

puts "\n" + "=" * 50
puts "What Each Operation Does"
puts "=" * 50
puts "EROSION:  Makes dark areas bigger → removes small bright spots"
puts "DILATION: Makes bright areas bigger → fills small dark holes"
puts "OPENING:  Erosion + Dilation → cleans noise without shrinking"
puts "CLOSING:  Dilation + Erosion → fills gaps without growing"
puts "GRADIENT: Dilation - Erosion → shows only edges"

puts "\n" + "=" * 50
puts "Real-World Use Cases"
puts "=" * 50
puts "• Document scanning: Remove noise from scanned text"
puts "• OCR preprocessing: Clean up text before recognition"
puts "• Medical imaging: Separate connected structures"
puts "• Object detection: Find and separate objects"
puts "• Fingerprint analysis: Enhance ridge patterns"

puts "\n" + "=" * 50
puts "Output Files"
puts "=" * 50
puts "  morph_original.png  - Original with noise and gaps"
puts "  morph_eroded.png    - Noise removed (white dots gone)"
puts "  morph_dilated.png   - Gaps filled (line connected)"
puts "  morph_opened.png    - Clean noise removal"
puts "  morph_closed.png    - Clean gap filling"
puts "  morph_gradient.png  - Edge detection"
puts "\nCompare the images to see what each operation does!"
