require "../src/crimage"

# This example demonstrates decompression bomb protection in CrImage
#
# Run with: crystal run examples/decompression_bomb_demo.cr

puts "=== Decompression Bomb Protection Demo ===\n"

# Example 1: Normal image (should work fine)
puts "1. Creating and decoding a normal image..."
normal_img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
io = IO::Memory.new
CrImage::PNG.write(io, normal_img)
io.rewind

decoded = CrImage::PNG.read(io)
puts " Successfully decoded #{decoded.bounds.width}x#{decoded.bounds.height} image"
puts "   Compressed size: #{io.size} bytes\n\n"

# Example 2: Demonstrate protection with strict limits
puts "2. Testing with strict limits..."
begin
  # Set strict limits globally
  CrImage::DecompressionGuard.default_config =
    CrImage::DecompressionGuard::Config.strict

  # Create a larger image that exceeds strict limits
  large_img = CrImage.rgba(5000, 5000, CrImage::Color::WHITE)
  io2 = IO::Memory.new
  CrImage::PNG.write(io2, large_img)
  io2.rewind

  puts "   Attempting to decode #{io2.size} byte PNG..."
  decoded2 = CrImage::PNG.read(io2)
  puts " Decoded successfully (within strict limits)"
rescue ex : CrImage::MemoryError
  puts "   ✗ Rejected: #{ex.message}"
end

# Reset to default config
CrImage::DecompressionGuard.default_config =
  CrImage::DecompressionGuard::Config.new

puts "\n3. Decompression statistics example..."

# Create a guard to track statistics
guard = CrImage::DecompressionGuard.create("DEMO")

# Simulate compression tracking
guard.add_compressed(1024)      # 1KB compressed
guard.add_decompressed(102_400) # 100KB decompressed

stats = guard.stats
puts "   Compressed: #{stats[:compressed]} bytes"
puts "   Decompressed: #{stats[:decompressed]} bytes"
puts "   Expansion ratio: #{stats[:ratio].round(2)}:1"

# Check if this would trigger protection
if stats[:ratio] > 1000
  puts "   ⚠ This would trigger decompression bomb protection!"
else
  puts " Within safe limits"
end

puts "\n4. Configuration options..."
puts "   Default config:"
default_config = CrImage::DecompressionGuard::Config.new
puts "     - Max expansion ratio: #{default_config.max_expansion_ratio}:1"
puts "     - Max decompressed size: #{default_config.max_decompressed_size / 1_000_000}MB"

puts "\n   Strict config:"
strict_config = CrImage::DecompressionGuard::Config.strict
puts "     - Max expansion ratio: #{strict_config.max_expansion_ratio}:1"
puts "     - Max decompressed size: #{strict_config.max_decompressed_size / 1_000_000}MB"

puts "\n   Permissive config:"
permissive_config = CrImage::DecompressionGuard::Config.permissive
puts "     - Max expansion ratio: #{permissive_config.max_expansion_ratio}:1"
puts "     - Max decompressed size: #{permissive_config.max_decompressed_size / 1_000_000}MB"

puts "\n=== Demo Complete ===\n"
puts "The decompression bomb protection is automatically enabled for:"
puts "  • PNG (zlib-compressed IDAT chunks)"
puts "  • GIF (LZW-compressed image data)"
puts "\nFor more information, see guide/DECOMPRESSION_BOMB_PROTECTION.md"
