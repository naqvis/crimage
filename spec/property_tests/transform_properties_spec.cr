require "../spec_helper"

# Helper methods for property tests
def random_image(min_width = 5, max_width = 100, min_height = 5, max_height = 100)
  width = Random.rand(min_width..max_width)
  height = Random.rand(min_height..max_height)
  img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

  # Fill with random colors
  height.times do |y|
    width.times do |x|
      img.set(x, y, CrImage::Color::RGBA.new(
        Random.rand(256).to_u8,
        Random.rand(256).to_u8,
        Random.rand(256).to_u8,
        Random.rand(256).to_u8
      ))
    end
  end

  img
end

# Helper to generate random positive radius
def random_positive_radius(max = 10)
  Random.rand(1..max)
end

module CrImage::Transform
  describe "Transform Property Tests" do
    describe "Gaussian Blur Properties" do
      it "Gaussian blur preserves dimensions and color model" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image
          radius = random_positive_radius

          result = Transform.blur_gaussian(img, radius)

          # Verify dimensions are preserved
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Verify color model is preserved (RGBA)
          result.should be_a(RGBA)
        end
      end

      it "Gaussian blur actually blurs sharp edges" do
        # Create images with sharp edges and verify they get blurred
        5.times do
          width = Random.rand(20..50)
          height = Random.rand(20..50)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Create a sharp horizontal edge in the middle
          mid_y = height // 2
          height.times do |y|
            width.times do |x|
              if y < mid_y
                img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
              else
                img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
              end
            end
          end

          radius = Random.rand(2..5)
          result = Transform.blur_gaussian(img, radius)

          # Check that the edge is blurred - pixels near the edge should have intermediate values
          # The pixel right at the edge should not be pure white or pure black
          edge_x = width // 2
          edge_color = result.at(edge_x, mid_y).as(CrImage::Color::RGBA)

          # After blur, the edge pixel should be gray (between 0 and 255, not at extremes)
          edge_color.r.should be > 10
          edge_color.r.should be < 245
        end
      end

      it "Gaussian blur smooths color transitions" do
        # Verify that blur reduces variance between neighboring pixels
        30.times do
          img = random_image(20, 50, 20, 50)
          radius = Random.rand(2..5)

          result = Transform.blur_gaussian(img, radius)

          # Calculate average color difference between neighbors in original vs blurred
          original_variance = 0.0
          blurred_variance = 0.0
          count = 0

          (1...img.bounds.height - 1).each do |y|
            (1...img.bounds.width - 1).each do |x|
              # Original image neighbor differences
              c1 = img.at(x, y).as(CrImage::Color::RGBA)
              c2 = img.at(x + 1, y).as(CrImage::Color::RGBA)
              original_variance += (c1.r.to_i32 - c2.r.to_i32).abs

              # Blurred image neighbor differences
              b1 = result.at(x, y).as(CrImage::Color::RGBA)
              b2 = result.at(x + 1, y).as(CrImage::Color::RGBA)
              blurred_variance += (b1.r.to_i32 - b2.r.to_i32).abs

              count += 1
            end
          end

          # Blurred image should have lower variance (smoother transitions)
          # Allow some tolerance for very smooth original images
          if original_variance > 100
            blurred_variance.should be < original_variance
          end
        end
      end

      it "Gaussian blur with radius 0 preserves image exactly" do
        # Test with radius 0 specifically - should be pixel-perfect copy
        5.times do
          img = random_image

          result = Transform.blur_gaussian(img, 0)

          # Verify dimensions are preserved
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Verify color model is preserved
          result.should be_a(RGBA)

          # With radius 0, image should be unchanged pixel-by-pixel
          img.bounds.height.times do |y|
            img.bounds.width.times do |x|
              result.at(x, y).should eq(img.at(x, y))
            end
          end
        end
      end

      it "Gaussian blur with custom sigma preserves dimensions" do
        # Test with custom sigma values
        5.times do
          img = random_image
          radius = random_positive_radius
          sigma = Random.rand(0.5..5.0)

          result = Transform.blur_gaussian(img, radius, sigma)

          # Verify dimensions are preserved
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Verify color model is preserved
          result.should be_a(RGBA)
        end
      end

      it "Larger radius produces more blur" do
        # Verify that increasing radius increases blur amount
        20.times do
          width = Random.rand(30..60)
          height = Random.rand(30..60)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Create a single bright pixel in the center
          center_x = width // 2
          center_y = height // 2
          height.times do |y|
            width.times do |x|
              if x == center_x && y == center_y
                img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
              else
                img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
              end
            end
          end

          # Apply blur with two different radii
          small_radius = 2
          large_radius = 5

          result_small = Transform.blur_gaussian(img, small_radius)
          result_large = Transform.blur_gaussian(img, large_radius)

          # Check a pixel 3 units away from center
          test_x = center_x + 3
          test_y = center_y

          if test_x < width
            small_color = result_small.at(test_x, test_y).as(CrImage::Color::RGBA)
            large_color = result_large.at(test_x, test_y).as(CrImage::Color::RGBA)

            # Larger radius should spread the bright pixel further
            # So the pixel 3 units away should be brighter with larger radius
            large_color.r.should be >= small_color.r
          end
        end
      end

      it "Gaussian blur with invalid radius raises error" do
        # Test with negative radii
        10.times do
          img = random_image
          negative_radius = -Random.rand(1..100)

          expect_raises(ArgumentError, "Radius must be non-negative") do
            Transform.blur_gaussian(img, negative_radius)
          end
        end
      end

      it "Gaussian blur rejects various negative values" do
        # Test specific negative values
        img = random_image

        [-1, -5, -10, -100, -1000].each do |negative_radius|
          expect_raises(ArgumentError, "Radius must be non-negative") do
            Transform.blur_gaussian(img, negative_radius)
          end
        end
      end
    end

    describe "Advanced Resize Properties" do
      it "Resize preserves aspect ratio or dimensions" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image

          # Generate random target dimensions
          new_width = Random.rand(5..150)
          new_height = Random.rand(5..150)

          # Test Lanczos resize
          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_lanczos.bounds.width.should eq(new_width)
          result_lanczos.bounds.height.should eq(new_height)
          result_lanczos.should be_a(RGBA)

          # Test bicubic resize
          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)
          result_bicubic.bounds.width.should eq(new_width)
          result_bicubic.bounds.height.should eq(new_height)
          result_bicubic.should be_a(RGBA)
        end
      end

      it "Resize handles upscaling" do
        # Test upscaling specifically
        5.times do
          img = random_image(5, 30, 5, 30)

          # Upscale by 2x to 3x
          scale_factor = Random.rand(2.0..3.0)
          new_width = (img.bounds.width * scale_factor).to_i
          new_height = (img.bounds.height * scale_factor).to_i

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_lanczos.bounds.width.should eq(new_width)
          result_lanczos.bounds.height.should eq(new_height)

          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)
          result_bicubic.bounds.width.should eq(new_width)
          result_bicubic.bounds.height.should eq(new_height)
        end
      end

      it "Resize handles downscaling" do
        # Test downscaling specifically
        5.times do
          img = random_image(50, 100, 50, 100)

          # Downscale by 2x to 4x
          scale_factor = Random.rand(2.0..4.0)
          new_width = (img.bounds.width / scale_factor).to_i.clamp(5, img.bounds.width)
          new_height = (img.bounds.height / scale_factor).to_i.clamp(5, img.bounds.height)

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_lanczos.bounds.width.should eq(new_width)
          result_lanczos.bounds.height.should eq(new_height)

          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)
          result_bicubic.bounds.width.should eq(new_width)
          result_bicubic.bounds.height.should eq(new_height)
        end
      end

      it "Resize to same dimensions preserves image" do
        # Test resizing to same dimensions
        30.times do
          img = random_image
          width = img.bounds.width
          height = img.bounds.height

          result_lanczos = Transform.resize_lanczos(img, width, height)
          result_lanczos.bounds.width.should eq(width)
          result_lanczos.bounds.height.should eq(height)

          result_bicubic = Transform.resize_bicubic(img, width, height)
          result_bicubic.bounds.width.should eq(width)
          result_bicubic.bounds.height.should eq(height)
        end
      end

      it "Resize to very small dimensions" do
        # Test resizing to very small dimensions (1x1, 2x2, etc.)
        30.times do
          img = random_image(20, 50, 20, 50)

          small_width = Random.rand(1..5)
          small_height = Random.rand(1..5)

          result_lanczos = Transform.resize_lanczos(img, small_width, small_height)
          result_lanczos.bounds.width.should eq(small_width)
          result_lanczos.bounds.height.should eq(small_height)

          result_bicubic = Transform.resize_bicubic(img, small_width, small_height)
          result_bicubic.bounds.width.should eq(small_width)
          result_bicubic.bounds.height.should eq(small_height)
        end
      end

      it "Resize maintains non-zero pixels" do
        # Verify that resize doesn't produce all-black images from colored images
        30.times do
          width = Random.rand(10..30)
          height = Random.rand(10..30)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with bright colors
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(
                Random.rand(128..255).to_u8,
                Random.rand(128..255).to_u8,
                Random.rand(128..255).to_u8,
                255_u8
              ))
            end
          end

          new_width = Random.rand(5..50)
          new_height = Random.rand(5..50)

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)

          # Check that at least some pixels are non-black
          has_color_lanczos = false
          has_color_bicubic = false

          new_height.times do |y|
            new_width.times do |x|
              c_lanczos = result_lanczos.at(x, y).as(CrImage::Color::RGBA)
              c_bicubic = result_bicubic.at(x, y).as(CrImage::Color::RGBA)

              has_color_lanczos = true if c_lanczos.r > 50 || c_lanczos.g > 50 || c_lanczos.b > 50
              has_color_bicubic = true if c_bicubic.r > 50 || c_bicubic.g > 50 || c_bicubic.b > 50
            end
          end

          has_color_lanczos.should be_true
          has_color_bicubic.should be_true
        end
      end

      it "Resize preserves monotonic gradients" do
        # Verify that gradients remain monotonic after resize
        30.times do
          width = Random.rand(20..40)
          height = Random.rand(20..40)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Create horizontal gradient (left to right, dark to bright)
          height.times do |y|
            width.times do |x|
              intensity = (x.to_f / width * 255).to_u8
              img.set(x, y, CrImage::Color::RGBA.new(intensity, intensity, intensity, 255_u8))
            end
          end

          new_width = Random.rand(10..60)
          new_height = Random.rand(10..60)

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)

          # Check that gradient is still generally increasing from left to right
          # Sample the middle row
          mid_y = new_height // 2
          prev_lanczos = 0
          prev_bicubic = 0

          # Check every few pixels to allow for minor variations
          (0...new_width).step(new_width // 5).each do |x|
            next if x == 0

            c_lanczos = result_lanczos.at(x, mid_y).as(CrImage::Color::RGBA)
            c_bicubic = result_bicubic.at(x, mid_y).as(CrImage::Color::RGBA)

            # Gradient should generally increase (allow small decreases due to interpolation)
            c_lanczos.r.should be >= (prev_lanczos - 20)
            c_bicubic.r.should be >= (prev_bicubic - 20)

            prev_lanczos = c_lanczos.r.to_i32
            prev_bicubic = c_bicubic.r.to_i32
          end
        end
      end

      it "Resize produces smooth interpolation" do
        # Verify that resize produces smooth transitions, not blocky artifacts
        20.times do
          # Create image with single bright pixel in center
          width = Random.rand(20..30)
          height = Random.rand(20..30)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with black
          height.times do |y|
            width.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Set center pixel to white
          center_x = width // 2
          center_y = height // 2
          img.set(center_x, center_y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

          # Upscale
          new_width = width * 2
          new_height = height * 2

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)

          # Check that the bright spot spreads smoothly
          # Find the brightest pixel and verify it has non-zero neighbors
          max_brightness_lanczos = 0
          max_x_lanczos = 0
          max_y_lanczos = 0

          new_height.times do |y|
            new_width.times do |x|
              c = result_lanczos.at(x, y).as(CrImage::Color::RGBA)
              if c.r > max_brightness_lanczos
                max_brightness_lanczos = c.r.to_i32
                max_x_lanczos = x
                max_y_lanczos = y
              end
            end
          end

          # The brightest pixel should be significantly bright
          max_brightness_lanczos.should be > 100

          # Check that at least one immediate neighbor has some brightness
          # (proving interpolation is working, not just point sampling)
          has_bright_neighbor = false
          [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |(dx, dy)|
            nx = max_x_lanczos + dx
            ny = max_y_lanczos + dy
            next if nx < 0 || nx >= new_width || ny < 0 || ny >= new_height

            neighbor = result_lanczos.at(nx, ny).as(CrImage::Color::RGBA)
            has_bright_neighbor = true if neighbor.r > 0
          end

          has_bright_neighbor.should be_true

          # Same check for bicubic
          max_brightness_bicubic = 0
          new_height.times do |y|
            new_width.times do |x|
              c = result_bicubic.at(x, y).as(CrImage::Color::RGBA)
              max_brightness_bicubic = c.r.to_i32 if c.r > max_brightness_bicubic
            end
          end

          max_brightness_bicubic.should be > 100
        end
      end

      it "Downscaling averages pixel values correctly" do
        # Verify that downscaling produces proper averaging
        20.times do
          # Create 2x2 blocks of solid colors
          width = Random.rand(20..40)
          height = Random.rand(20..40)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with alternating black and white 2x2 blocks
          height.times do |y|
            width.times do |x|
              if ((x // 2) + (y // 2)) % 2 == 0
                img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
              else
                img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
              end
            end
          end

          # Downscale by 2x
          new_width = width // 2
          new_height = height // 2

          result_lanczos = Transform.resize_lanczos(img, new_width, new_height)
          result_bicubic = Transform.resize_bicubic(img, new_width, new_height)

          # Most pixels should be in the gray range (averaged)
          gray_count_lanczos = 0
          gray_count_bicubic = 0

          new_height.times do |y|
            new_width.times do |x|
              c_lanczos = result_lanczos.at(x, y).as(CrImage::Color::RGBA)
              c_bicubic = result_bicubic.at(x, y).as(CrImage::Color::RGBA)

              # Count pixels in gray range (not pure black or white)
              gray_count_lanczos += 1 if c_lanczos.r > 30 && c_lanczos.r < 225
              gray_count_bicubic += 1 if c_bicubic.r > 30 && c_bicubic.r < 225
            end
          end

          total_pixels = new_width * new_height
          # At least 50% should be gray (averaged)
          gray_count_lanczos.should be > (total_pixels // 2)
          gray_count_bicubic.should be > (total_pixels // 2)
        end
      end

      it "Resize with invalid dimensions raises error" do
        # Test with zero and negative dimensions
        10.times do
          img = random_image

          # Test zero width
          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_lanczos(img, 0, Random.rand(1..100))
          end

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_bicubic(img, 0, Random.rand(1..100))
          end

          # Test zero height
          expect_raises(ArgumentError, "Height must be positive") do
            Transform.resize_lanczos(img, Random.rand(1..100), 0)
          end

          expect_raises(ArgumentError, "Height must be positive") do
            Transform.resize_bicubic(img, Random.rand(1..100), 0)
          end

          # Test negative width
          negative_width = -Random.rand(1..100)
          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_lanczos(img, negative_width, Random.rand(1..100))
          end

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_bicubic(img, negative_width, Random.rand(1..100))
          end

          # Test negative height
          negative_height = -Random.rand(1..100)
          expect_raises(ArgumentError, "Height must be positive") do
            Transform.resize_lanczos(img, Random.rand(1..100), negative_height)
          end

          expect_raises(ArgumentError, "Height must be positive") do
            Transform.resize_bicubic(img, Random.rand(1..100), negative_height)
          end
        end
      end

      it "Resize rejects both dimensions zero" do
        # Test with both dimensions zero
        30.times do
          img = random_image

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_lanczos(img, 0, 0)
          end

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_bicubic(img, 0, 0)
          end
        end
      end

      it "Resize rejects both dimensions negative" do
        # Test with both dimensions negative
        30.times do
          img = random_image
          negative_width = -Random.rand(1..100)
          negative_height = -Random.rand(1..100)

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_lanczos(img, negative_width, negative_height)
          end

          expect_raises(ArgumentError, "Width must be positive") do
            Transform.resize_bicubic(img, negative_width, negative_height)
          end
        end
      end

      it "Resize rejects specific invalid values" do
        # Test specific invalid dimension values
        img = random_image

        [0, -1, -10, -100, -1000].each do |invalid_dim|
          expect_raises(ArgumentError) do
            Transform.resize_lanczos(img, invalid_dim, 50)
          end

          expect_raises(ArgumentError) do
            Transform.resize_bicubic(img, invalid_dim, 50)
          end

          expect_raises(ArgumentError) do
            Transform.resize_lanczos(img, 50, invalid_dim)
          end

          expect_raises(ArgumentError) do
            Transform.resize_bicubic(img, 50, invalid_dim)
          end
        end
      end
    end
  end
end
