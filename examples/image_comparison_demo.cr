require "../src/crimage"

# Example: Image Comparison and Quality Metrics
#
# Demonstrates various metrics for comparing images and measuring
# similarity, including MSE, PSNR, SSIM, and perceptual hashing.
#
# Usage:
#   crystal run examples/image_comparison_demo.cr

puts "Image Comparison and Quality Metrics Demo"
puts "=" * 50

# Create original image
original = CrImage.rgba(200, 200)

# Create a pattern
200.times do |y|
  200.times do |x|
    r = ((x + y) * 255 // 400).to_u8
    g = (x * 255 // 200).to_u8
    b = (y * 255 // 200).to_u8
    original.set(x, y, CrImage::Color.rgba(r, g, b, 255))
  end
end

# Add some features
original.draw_circle(50, 50, 30, color: CrImage::Color::WHITE, fill: true)
original.draw_rect(100, 100, 80, 80, fill: CrImage::Color::BLACK)

CrImage::PNG.write("compare_original.png", original)
puts "Created original image"

# Create identical copy
identical = CrImage.rgba(200, 200)
200.times do |y|
  200.times do |x|
    identical.set(x, y, original.at(x, y))
  end
end

# Create slightly modified version (brightness adjustment)
slightly_modified = original.brightness(10)
CrImage::PNG.write("compare_slightly_modified.png", slightly_modified)
puts "Created slightly modified version (+10 brightness)"

# Create moderately modified version (blur)
moderately_modified = original.blur(3)
CrImage::PNG.write("compare_moderately_modified.png", moderately_modified)
puts "Created moderately modified version (blur)"

# Create heavily modified version (multiple changes)
heavily_modified = original.brightness(50).contrast(1.5).blur(5)
CrImage::PNG.write("compare_heavily_modified.png", heavily_modified)
puts "Created heavily modified version"

# Create completely different image
different = CrImage.rgba(200, 200, CrImage::Color::WHITE)
different.draw_circle(100, 100, 80, color: CrImage::Color::BLACK, fill: true)
CrImage::PNG.write("compare_different.png", different)
puts "Created completely different image"

puts "\n" + "=" * 50
puts "Comparison Metrics"
puts "=" * 50

# Compare with identical
puts "\nOriginal vs Identical:"
mse = original.mse(identical)
psnr = original.psnr(identical)
ssim = original.ssim(identical)
puts "  MSE:  #{mse.round(4)} (0 = identical)"
puts "  PSNR: #{psnr.round(2)} dB (∞ = identical)"
puts "  SSIM: #{ssim.round(4)} (1.0 = identical)"

# Compare with slightly modified
puts "\nOriginal vs Slightly Modified (+10 brightness):"
mse = original.mse(slightly_modified)
psnr = original.psnr(slightly_modified)
ssim = original.ssim(slightly_modified)
puts "  MSE:  #{mse.round(4)}"
puts "  PSNR: #{psnr.round(2)} dB (>40 = excellent)"
puts "  SSIM: #{ssim.round(4)}"

# Compare with moderately modified
puts "\nOriginal vs Moderately Modified (blur):"
mse = original.mse(moderately_modified)
psnr = original.psnr(moderately_modified)
ssim = original.ssim(moderately_modified)
puts "  MSE:  #{mse.round(4)}"
puts "  PSNR: #{psnr.round(2)} dB (30-40 = good)"
puts "  SSIM: #{ssim.round(4)}"

# Compare with heavily modified
puts "\nOriginal vs Heavily Modified:"
mse = original.mse(heavily_modified)
psnr = original.psnr(heavily_modified)
ssim = original.ssim(heavily_modified)
puts "  MSE:  #{mse.round(4)}"
puts "  PSNR: #{psnr.round(2)} dB (20-30 = acceptable)"
puts "  SSIM: #{ssim.round(4)}"

# Compare with completely different
puts "\nOriginal vs Completely Different:"
mse = original.mse(different)
psnr = original.psnr(different)
ssim = original.ssim(different)
puts "  MSE:  #{mse.round(4)}"
puts "  PSNR: #{psnr.round(2)} dB (<20 = poor)"
puts "  SSIM: #{ssim.round(4)}"

puts "\n" + "=" * 50
puts "Perceptual Hashing (Duplicate Detection)"
puts "=" * 50

# Calculate perceptual hashes
hash_original = original.perceptual_hash
hash_identical = identical.perceptual_hash
hash_slight = slightly_modified.perceptual_hash
hash_moderate = moderately_modified.perceptual_hash
hash_heavy = heavily_modified.perceptual_hash
hash_different = different.perceptual_hash

puts "\nPerceptual Hashes (64-bit):"
puts "  Original:           #{hash_original.to_s(16).rjust(16, '0')}"
puts "  Identical:          #{hash_identical.to_s(16).rjust(16, '0')}"
puts "  Slightly Modified:  #{hash_slight.to_s(16).rjust(16, '0')}"
puts "  Moderately Modified:#{hash_moderate.to_s(16).rjust(16, '0')}"
puts "  Heavily Modified:   #{hash_heavy.to_s(16).rjust(16, '0')}"
puts "  Different:          #{hash_different.to_s(16).rjust(16, '0')}"

puts "\nHamming Distances (bits different):"
puts "  Original vs Identical:          #{CrImage::Util::Metrics.hamming_distance(hash_original, hash_identical)} (<5 = very similar)"
puts "  Original vs Slightly Modified:  #{CrImage::Util::Metrics.hamming_distance(hash_original, hash_slight)} (<10 = similar)"
puts "  Original vs Moderately Modified:#{CrImage::Util::Metrics.hamming_distance(hash_original, hash_moderate)}"
puts "  Original vs Heavily Modified:   #{CrImage::Util::Metrics.hamming_distance(hash_original, hash_heavy)}"
puts "  Original vs Different:          #{CrImage::Util::Metrics.hamming_distance(hash_original, hash_different)} (>10 = different)"

puts "\n" + "=" * 50
puts "Summary"
puts "=" * 50
puts "MSE:  Lower is better (0 = identical)"
puts "PSNR: Higher is better (∞ = identical, >40 dB = excellent)"
puts "SSIM: Higher is better (1.0 = identical, considers structure)"
puts "pHash: Hamming distance <10 typically indicates similar images"
puts "\nOutput files created for visual comparison."
