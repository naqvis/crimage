require "../src/crimage"

# Example: Visual Diff Generation
#
# Demonstrates image comparison and visual diff generation
# for regression testing and change detection.
#
# Usage:
#   crystal run examples/visual_diff_demo.cr

puts "Visual Diff Generation Demo"
puts "=" * 50

# Create two similar images with some differences
img1 = CrImage.rgba(200, 200, CrImage::Color::WHITE)
img2 = CrImage.rgba(200, 200, CrImage::Color::WHITE)

# Add same base content
img1.draw_circle(100, 100, 50, color: CrImage::Color::RED, fill: true)
img2.draw_circle(100, 100, 50, color: CrImage::Color::RED, fill: true)

# Add different elements
img1.draw_rect(20, 20, 40, 40, fill: CrImage::Color::BLUE)
img2.draw_rect(25, 25, 40, 40, fill: CrImage::Color::BLUE) # Slightly offset

img1.draw_circle(160, 40, 20, color: CrImage::Color::GREEN, fill: true)
img2.draw_circle(160, 40, 20, color: CrImage::Color::YELLOW, fill: true) # Different color

CrImage::PNG.write("diff_image1.png", img1)
CrImage::PNG.write("diff_image2.png", img2)
puts "Created two images with differences"
puts "  Saved: diff_image1.png"
puts "  Saved: diff_image2.png"

# Generate visual diff (differences highlighted in red)
puts "\nGenerating visual diff..."
diff_image = img1.visual_diff(img2, threshold: 10)
CrImage::PNG.write("diff_result.png", diff_image)
puts "  Saved: diff_result.png (differences in red)"

# Get diff statistics
diff_count = img1.diff_count(img2, threshold: 10)
diff_percent = CrImage::Util::VisualDiff.diff_percent(img1, img2, threshold: 10)
identical = img1.identical?(img2, threshold: 10, tolerance: 0)

puts "\nDiff Statistics:"
puts "  Different pixels: #{diff_count}"
puts "  Difference: #{diff_percent.round(2)}%"
puts "  Identical: #{identical}"

# Compare with custom highlight color
puts "\nGenerating diff with green highlight..."
diff_green = CrImage::Util::VisualDiff.diff(img1, img2,
  threshold: 10,
  highlight_color: CrImage::Color::GREEN)
CrImage::PNG.write("diff_green_highlight.png", diff_green)
puts "  Saved: diff_green_highlight.png"

# Test with identical images
puts "\nComparing identical images..."
img3 = CrImage.rgba(100, 100, CrImage::Color::RED)
img4 = CrImage.rgba(100, 100, CrImage::Color::RED)

if img3.identical?(img4)
  puts "  Images are identical ✓"
else
  puts "  Images differ"
end

# Test with tolerance
puts "\nTesting tolerance (allowing up to 100 different pixels)..."
if img1.identical?(img2, threshold: 10, tolerance: 100)
  puts "  Images match within tolerance"
else
  puts "  Images differ beyond tolerance"
end

puts "\nOutput files:"
puts "  - diff_image1.png (original)"
puts "  - diff_image2.png (modified)"
puts "  - diff_result.png (diff with red highlights)"
puts "  - diff_green_highlight.png (diff with green highlights)"
puts "\nUse visual diff for regression testing!"
