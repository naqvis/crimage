require "../src/crimage"

# Example: Histogram Operations
#
# Demonstrates histogram analysis and equalization for improving
# image contrast and analyzing pixel distributions.
#
# Usage:
#   crystal run examples/histogram_demo.cr

puts "Histogram Operations Demo"
puts "=" * 50

# Create a low-contrast image
img = CrImage.rgba(300, 300)

# Fill with low-contrast gradient (only using middle range)
300.times do |y|
  300.times do |x|
    # Use only 80-180 range (low contrast)
    gray = (80 + (x + y) * 100 // 600).to_u8
    img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
  end
end

# Add some features
img.draw_circle(100, 100, 40, color: CrImage::Color.rgba(120, 120, 120, 255), fill: true)
img.draw_rect(150, 150, 100, 100, fill: CrImage::Color.rgba(160, 160, 160, 255))

CrImage::PNG.write("histogram_original.png", img)
puts "Created low-contrast image"

# Analyze histogram
hist = img.histogram
puts "\nHistogram Analysis:"
puts "  Mean brightness: #{hist.mean.round(2)}"
puts "  Median: #{hist.median}"
puts "  Std deviation: #{hist.std_dev.round(2)}"
puts "  10th percentile: #{hist.percentile(10)}"
puts "  90th percentile: #{hist.percentile(90)}"

# Apply histogram equalization
equalized = img.equalize
CrImage::PNG.write("histogram_equalized.png", equalized)
puts "\nApplied histogram equalization"

# Analyze equalized histogram
eq_hist = equalized.histogram
puts "\nEqualized Histogram:"
puts "  Mean brightness: #{eq_hist.mean.round(2)}"
puts "  Median: #{eq_hist.median}"
puts "  Std deviation: #{eq_hist.std_dev.round(2)}"
puts "  10th percentile: #{eq_hist.percentile(10)}"
puts "  90th percentile: #{eq_hist.percentile(90)}"

# Apply adaptive histogram equalization (CLAHE)
adaptive = img.equalize_adaptive(tile_size: 16, clip_limit: 2.0)
CrImage::PNG.write("histogram_adaptive.png", adaptive)
puts "\nApplied adaptive histogram equalization (CLAHE)"

# Create a more complex test image
complex_img = CrImage.rgba(400, 400)

# Create regions with different brightness
100.times do |y|
  400.times do |x|
    complex_img.set(x, y, CrImage::Color.rgba(50, 50, 50, 255))
  end
end

(100...200).each do |y|
  400.times do |x|
    complex_img.set(x, y, CrImage::Color.rgba(100, 100, 100, 255))
  end
end

(200...300).each do |y|
  400.times do |x|
    complex_img.set(x, y, CrImage::Color.rgba(150, 150, 150, 255))
  end
end

(300...400).each do |y|
  400.times do |x|
    complex_img.set(x, y, CrImage::Color.rgba(200, 200, 200, 255))
  end
end

CrImage::PNG.write("histogram_complex_original.png", complex_img)

# Apply both methods to complex image
complex_eq = complex_img.equalize
CrImage::PNG.write("histogram_complex_equalized.png", complex_eq)

complex_adaptive = complex_img.equalize_adaptive(tile_size: 32)
CrImage::PNG.write("histogram_complex_adaptive.png", complex_adaptive)

puts "\nProcessed complex multi-region image"

puts "\nOutput files:"
puts "  - histogram_original.png (low contrast)"
puts "  - histogram_equalized.png (global equalization)"
puts "  - histogram_adaptive.png (local CLAHE)"
puts "  - histogram_complex_*.png (multi-region test)"
puts "\nNotice how equalization improves contrast!"
