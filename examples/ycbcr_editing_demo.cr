require "../src/crimage"

# Demonstrate YCbCr image editing
# YCbCr is the native color space for JPEG images

puts "YCbCr Image Editing Demo"
puts "=" * 50

# Create a YCbCr image with 4:2:0 subsampling (like JPEG)
width, height = 400, 300
rect = CrImage.rect(0, 0, width, height)
img = CrImage::YCbCr.new(rect, CrImage::YCbCrSubSampleRatio::YCbCrSubsampleRatio420)

puts "Created YCbCr image: #{width}x#{height}"
puts "Subsampling: 4:2:0 (like JPEG)"

# Fill with a gradient in YCbCr space
# Y = luminance (brightness), Cb/Cr = chrominance (color)
height.times do |y|
  width.times do |x|
    # Create a gradient effect
    luma = ((y.to_f / height) * 255).to_u8
    cb = 128_u8 # Neutral chroma
    cr = ((x.to_f / width) * 255).to_u8

    # Now we can set pixels directly in YCbCr space!
    ycbcr_color = CrImage::Color::YCbCr.new(luma, cb, cr)
    img.set_ycbcr(x, y, ycbcr_color)
  end
end

puts "Filled with YCbCr gradient"

# Convert to RGBA for saving as PNG
rgba_img = CrImage::RGBA.new(rect)
height.times do |y|
  width.times do |x|
    rgba_img.set(x, y, img.at(x, y))
  end
end

CrImage::PNG.write("output/ycbcr_gradient.png", rgba_img)
puts "Saved: output/ycbcr_gradient.png"

# Demonstrate editing existing JPEG in YCbCr space
# This avoids RGB conversion, preserving quality
puts "\nEditing JPEG in native YCbCr space..."

# Create a test JPEG-like image
test_img = CrImage::RGBA.new(CrImage.rect(0, 0, 200, 200))
200.times do |y|
  200.times do |x|
    # Create a simple pattern
    r = ((x + y) % 256).to_u8
    g = ((x * 2) % 256).to_u8
    b = ((y * 2) % 256).to_u8
    test_img.set(x, y, CrImage::Color::RGBA.new(r, g, b, 255))
  end
end

# Convert to YCbCr (simulating JPEG decode)
ycbcr_test = CrImage::YCbCr.new(test_img.bounds, CrImage::YCbCrSubSampleRatio::YCbCrSubsampleRatio420)
200.times do |y|
  200.times do |x|
    color = test_img.at(x, y)
    r, g, b, _ = color.rgba
    y_val, cb_val, cr_val = CrImage::Color.rgb_to_ycbcr((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8)
    ycbcr_test.set_ycbcr(x, y, CrImage::Color::YCbCr.new(y_val, cb_val, cr_val))
  end
end

# Edit in YCbCr space - adjust brightness without affecting color
100.times do |y|
  100.times do |x|
    color = ycbcr_test.ycbcr_at(x + 50, y + 50).as(CrImage::Color::YCbCr)
    # Increase brightness by 50
    new_y = [color.y.to_i + 50, 255].min.to_u8
    ycbcr_test.set_ycbcr(x + 50, y + 50, CrImage::Color::YCbCr.new(new_y, color.cb, color.cr))
  end
end

# Convert back to RGBA for display
result = CrImage::RGBA.new(ycbcr_test.bounds)
200.times do |y|
  200.times do |x|
    result.set(x, y, ycbcr_test.at(x, y))
  end
end

CrImage::PNG.write("output/ycbcr_brightness_edit.png", result)
puts "Saved: output/ycbcr_brightness_edit.png"

puts "\nBenefits of YCbCr editing:"
puts "- No RGB conversion (preserves JPEG quality)"
puts "- Separate brightness and color adjustments"
puts "- Memory efficient with chroma subsampling"
puts "- Native JPEG/video color space"
