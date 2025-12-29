require "../src/crimage"

# Example: Channel Operations
#
# Demonstrates extracting, manipulating, and combining
# individual color channels (R, G, B, A).
#
# Usage:
#   crystal run examples/channel_operations_demo.cr

puts "Channel Operations Demo"
puts "=" * 50

# Create a colorful test image
puts "Creating colorful test image..."
img = CrImage.rgba(200, 200)
200.times do |y|
  200.times do |x|
    r = (x * 255 // 200).to_u8
    g = (y * 255 // 200).to_u8
    b = ((200 - x) * 255 // 200).to_u8
    img.set(x, y, CrImage::Color::RGBA.new(r, g, b, 255_u8))
  end
end
CrImage::PNG.write("channels_original.png", img)
puts "  Saved: channels_original.png"

# Extract individual channels
puts "\nExtracting channels..."
red_ch = img.extract_channel(:red)
green_ch = img.extract_channel(:green)
blue_ch = img.extract_channel(:blue)

CrImage::PNG.write("channels_red.png", red_ch)
CrImage::PNG.write("channels_green.png", green_ch)
CrImage::PNG.write("channels_blue.png", blue_ch)
puts "  Saved: channels_red.png"
puts "  Saved: channels_green.png"
puts "  Saved: channels_blue.png"

# Split all channels at once
puts "\nSplitting all channels..."
r, g, b = img.split_rgb
puts "  Split into 3 grayscale images"

# Swap channels (red <-> blue)
puts "\nSwapping red and blue channels..."
swapped = img.swap_channels(:red, :blue)
CrImage::PNG.write("channels_swapped_rb.png", swapped)
puts "  Saved: channels_swapped_rb.png"

# Swap red and green
swapped_rg = img.swap_channels(:red, :green)
CrImage::PNG.write("channels_swapped_rg.png", swapped_rg)
puts "  Saved: channels_swapped_rg.png"

# Boost red channel
puts "\nBoosting red channel by 1.5x..."
boosted = img.multiply_channel(:red, 1.5)
CrImage::PNG.write("channels_boosted_red.png", boosted)
puts "  Saved: channels_boosted_red.png"

# Reduce green channel
puts "Reducing green channel to 50%..."
reduced = img.multiply_channel(:green, 0.5)
CrImage::PNG.write("channels_reduced_green.png", reduced)
puts "  Saved: channels_reduced_green.png"

# Invert blue channel
puts "\nInverting blue channel..."
inverted = img.invert_channel(:blue)
CrImage::PNG.write("channels_inverted_blue.png", inverted)
puts "  Saved: channels_inverted_blue.png"

# Set channel to constant
puts "\nSetting green channel to 128..."
constant = img.set_channel(:green, 128_u8)
CrImage::PNG.write("channels_constant_green.png", constant)
puts "  Saved: channels_constant_green.png"

# Combine channels in different order (RGB -> BGR)
puts "\nRecombining channels as BGR..."
combined = CrImage::Util::Channels.combine(blue_ch, green_ch, red_ch)
CrImage::PNG.write("channels_bgr.png", combined)
puts "  Saved: channels_bgr.png"

# Create false color image
puts "\nCreating false color image (R->G, G->B, B->R)..."
false_color = CrImage::Util::Channels.combine(green_ch, blue_ch, red_ch)
CrImage::PNG.write("channels_false_color.png", false_color)
puts "  Saved: channels_false_color.png"

puts "\nOutput files:"
puts "  - channels_original.png"
puts "  - channels_red/green/blue.png (extracted)"
puts "  - channels_swapped_*.png (channel swaps)"
puts "  - channels_boosted_red.png"
puts "  - channels_reduced_green.png"
puts "  - channels_inverted_blue.png"
puts "  - channels_constant_green.png"
puts "  - channels_bgr.png"
puts "  - channels_false_color.png"
