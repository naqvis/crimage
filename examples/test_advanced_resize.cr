require "../src/crimage"

# Create a test image with clear patterns to verify resize quality
def create_test_pattern(width : Int32, height : Int32) : CrImage::RGBA
  img = CrImage.rgba(width, height)

  height.times do |y|
    width.times do |x|
      # Create a pattern with:
      # - Vertical gradient (left to right)
      # - Horizontal stripes
      # - Checkerboard in one corner

      gradient = (x.to_f / width * 255).to_u8

      if x < width // 4 && y < height // 4
        # Checkerboard pattern in top-left
        if ((x // 4) + (y // 4)) % 2 == 0
          img.set(x, y, CrImage::Color::WHITE)
        else
          img.set(x, y, CrImage::Color::BLACK)
        end
      elsif y < height // 3
        # Top third: red gradient
        img.set(x, y, CrImage::Color.rgb(gradient, 0, 0))
      elsif y < 2 * height // 3
        # Middle third: green gradient
        img.set(x, y, CrImage::Color.rgb(0, gradient, 0))
      else
        # Bottom third: blue gradient
        img.set(x, y, CrImage::Color.rgb(0, 0, gradient))
      end
    end
  end

  img
end

puts "Creating test pattern (200x200)..."
original = create_test_pattern(200, 200)
CrImage::PNG.write("test_original.png", original)
puts "Saved test_original.png"

# Test upscaling using high-level resize API
puts "\nUpscaling to 400x400..."
upscale_nearest = original.resize(400, 400, method: :nearest)
CrImage::PNG.write("test_upscale_nearest.png", upscale_nearest)
puts "Saved test_upscale_nearest.png (nearest neighbor)"

upscale_bilinear = original.resize(400, 400, method: :bilinear)
CrImage::PNG.write("test_upscale_bilinear.png", upscale_bilinear)
puts "Saved test_upscale_bilinear.png (bilinear)"

upscale_bicubic = original.resize(400, 400, method: :bicubic)
CrImage::PNG.write("test_upscale_bicubic.png", upscale_bicubic)
puts "Saved test_upscale_bicubic.png (bicubic)"

upscale_lanczos = original.resize(400, 400, method: :lanczos)
CrImage::PNG.write("test_upscale_lanczos.png", upscale_lanczos)
puts "Saved test_upscale_lanczos.png (Lanczos-3)"

# Test downscaling
puts "\nDownscaling to 100x100..."
downscale_nearest = original.resize(100, 100, method: :nearest)
CrImage::PNG.write("test_downscale_nearest.png", downscale_nearest)
puts "Saved test_downscale_nearest.png (nearest neighbor)"

downscale_bilinear = original.resize(100, 100, method: :bilinear)
CrImage::PNG.write("test_downscale_bilinear.png", downscale_bilinear)
puts "Saved test_downscale_bilinear.png (bilinear)"

downscale_bicubic = original.resize(100, 100, method: :bicubic)
CrImage::PNG.write("test_downscale_bicubic.png", downscale_bicubic)
puts "Saved test_downscale_bicubic.png (bicubic)"

downscale_lanczos = original.resize(100, 100, method: :lanczos)
CrImage::PNG.write("test_downscale_lanczos.png", downscale_lanczos)
puts "Saved test_downscale_lanczos.png (Lanczos-3)"

# Test extreme downscaling (checkerboard pattern)
puts "\nTesting checkerboard downscaling (40x40 -> 20x20)..."
checkerboard = CrImage.rgba(40, 40)
40.times do |y|
  40.times do |x|
    if ((x // 2) + (y // 2)) % 2 == 0
      checkerboard.set(x, y, CrImage::Color::WHITE)
    else
      checkerboard.set(x, y, CrImage::Color::BLACK)
    end
  end
end
CrImage::PNG.write("test_checkerboard_original.png", checkerboard)
puts "Saved test_checkerboard_original.png"

checkerboard_nearest = checkerboard.resize(20, 20, method: :nearest)
CrImage::PNG.write("test_checkerboard_nearest.png", checkerboard_nearest)
puts "Saved test_checkerboard_nearest.png (should still be checkerboard)"

checkerboard_lanczos = checkerboard.resize(20, 20, method: :lanczos)
CrImage::PNG.write("test_checkerboard_lanczos.png", checkerboard_lanczos)
puts "Saved test_checkerboard_lanczos.png (should be gray/averaged)"

checkerboard_bicubic = checkerboard.resize(20, 20, method: :bicubic)
CrImage::PNG.write("test_checkerboard_bicubic.png", checkerboard_bicubic)
puts "Saved test_checkerboard_bicubic.png (should be gray/averaged)"

puts "\n" + "="*60
puts "All test images generated successfully!"
puts "="*60
puts "\nCompare the images to verify quality:"
puts "  - Upscaling: Lanczos and bicubic should be smoother than nearest/bilinear"
puts "  - Downscaling: Lanczos and bicubic should preserve detail better"
puts "  - Checkerboard: Lanczos/bicubic should average to gray, nearest stays checkerboard"
