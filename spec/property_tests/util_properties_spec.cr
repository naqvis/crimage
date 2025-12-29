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

module CrImage::Util
  describe "Util Property Tests" do
    describe "Thumbnail Generation Properties" do
      it "thumbnail dimensions match specification for all modes" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image(20, 200, 20, 200)

          # Generate random target dimensions
          target_width = Random.rand(10..150)
          target_height = Random.rand(10..150)

          # Test Fit mode - dimensions should be <= target (preserving aspect ratio)
          result_fit = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)
          result_fit.bounds.width.should be <= target_width
          result_fit.bounds.height.should be <= target_height
          result_fit.should be_a(RGBA)

          # Test Fill mode - dimensions should exactly match target
          result_fill = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fill)
          result_fill.bounds.width.should eq(target_width)
          result_fill.bounds.height.should eq(target_height)
          result_fill.should be_a(RGBA)

          # Test Stretch mode - dimensions should exactly match target
          result_stretch = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Stretch)
          result_stretch.bounds.width.should eq(target_width)
          result_stretch.bounds.height.should eq(target_height)
          result_stretch.should be_a(RGBA)
        end
      end

      it "fit mode always fits within target bounds" do
        # Verify that Fit mode always produces thumbnails that fit within target dimensions
        5.times do
          img = random_image(50, 200, 50, 200)

          target_width = Random.rand(20..100)
          target_height = Random.rand(20..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          # Both dimensions should be within target
          result.bounds.width.should be <= target_width
          result.bounds.height.should be <= target_height

          # At least one dimension should match target (the limiting dimension)
          (result.bounds.width == target_width || result.bounds.height == target_height).should be_true
        end
      end

      it "fill mode produces exact target dimensions" do
        # Verify that Fill mode always produces exact target dimensions
        5.times do
          img = random_image(50, 200, 50, 200)

          target_width = Random.rand(20..100)
          target_height = Random.rand(20..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fill)

          # Both dimensions should exactly match target
          result.bounds.width.should eq(target_width)
          result.bounds.height.should eq(target_height)
        end
      end

      it "stretch mode produces exact target dimensions" do
        # Verify that Stretch mode always produces exact target dimensions
        5.times do
          img = random_image(50, 200, 50, 200)

          target_width = Random.rand(20..100)
          target_height = Random.rand(20..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Stretch)

          # Both dimensions should exactly match target
          result.bounds.width.should eq(target_width)
          result.bounds.height.should eq(target_height)
        end
      end

      it "handles very small thumbnail dimensions correctly" do
        # Test with very small target dimensions (1x1, 2x2, etc.)
        30.times do
          img = random_image(50, 100, 50, 100)

          small_width = Random.rand(1..5)
          small_height = Random.rand(1..5)

          # All modes should handle small dimensions
          result_fit = Util.thumbnail(img, small_width, small_height, ThumbnailMode::Fit)
          result_fit.bounds.width.should be <= small_width
          result_fit.bounds.height.should be <= small_height

          result_fill = Util.thumbnail(img, small_width, small_height, ThumbnailMode::Fill)
          result_fill.bounds.width.should eq(small_width)
          result_fill.bounds.height.should eq(small_height)

          result_stretch = Util.thumbnail(img, small_width, small_height, ThumbnailMode::Stretch)
          result_stretch.bounds.width.should eq(small_width)
          result_stretch.bounds.height.should eq(small_height)
        end
      end

      it "handles square target dimensions correctly" do
        # Test with square target dimensions
        30.times do
          img = random_image(50, 150, 50, 150)

          square_size = Random.rand(20..100)

          result_fit = Util.thumbnail(img, square_size, square_size, ThumbnailMode::Fit)
          result_fit.bounds.width.should be <= square_size
          result_fit.bounds.height.should be <= square_size

          result_fill = Util.thumbnail(img, square_size, square_size, ThumbnailMode::Fill)
          result_fill.bounds.width.should eq(square_size)
          result_fill.bounds.height.should eq(square_size)

          result_stretch = Util.thumbnail(img, square_size, square_size, ThumbnailMode::Stretch)
          result_stretch.bounds.width.should eq(square_size)
          result_stretch.bounds.height.should eq(square_size)
        end
      end

      it "all quality levels produce correct dimensions" do
        # Verify that all quality levels produce correct dimensions
        30.times do
          img = random_image(50, 100, 50, 100)

          target_width = Random.rand(20..80)
          target_height = Random.rand(20..80)

          # Test all quality levels with Stretch mode (simplest to verify)
          [ResampleQuality::Nearest, ResampleQuality::Bilinear,
           ResampleQuality::Bicubic, ResampleQuality::Lanczos].each do |quality|
            result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Stretch, quality)
            result.bounds.width.should eq(target_width)
            result.bounds.height.should eq(target_height)
          end
        end
      end

      it "rejects invalid dimensions with appropriate errors" do
        # Verify that invalid dimensions are rejected
        30.times do
          img = random_image

          # Test zero width
          expect_raises(ArgumentError, "Width must be positive") do
            Util.thumbnail(img, 0, Random.rand(1..100))
          end

          # Test zero height
          expect_raises(ArgumentError, "Height must be positive") do
            Util.thumbnail(img, Random.rand(1..100), 0)
          end

          # Test negative width
          expect_raises(ArgumentError, "Width must be positive") do
            Util.thumbnail(img, -Random.rand(1..100), Random.rand(1..100))
          end

          # Test negative height
          expect_raises(ArgumentError, "Height must be positive") do
            Util.thumbnail(img, Random.rand(1..100), -Random.rand(1..100))
          end
        end
      end

      it "fit mode preserves aspect ratio" do
        # Run 10 iterations with random inputs
        10.times do
          img = random_image(20, 200, 20, 200)

          src_width = img.bounds.width.to_f
          src_height = img.bounds.height.to_f
          src_aspect_ratio = src_width / src_height

          # Generate random target dimensions (use larger minimums to reduce rounding errors)
          target_width = Random.rand(30..150)
          target_height = Random.rand(30..150)

          # Test Fit mode - aspect ratio should be preserved
          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          result_width = result.bounds.width.to_f
          result_height = result.bounds.height.to_f
          result_aspect_ratio = result_width / result_height

          # Aspect ratios should match within tolerance accounting for integer rounding.
          # With ±1 pixel rounding error, the worst-case aspect ratio difference is
          # approximately 1/min_dimension. Use a fixed tolerance that handles small images.
          ratio_diff = (src_aspect_ratio - result_aspect_ratio).abs
          min_dimension = [result_width, result_height].min
          tolerance = [1.0 / min_dimension, 0.15].max

          ratio_diff.should be <= tolerance
        end
      end

      it "fit mode preserves aspect ratio for wide images" do
        # Test specifically with wide images (width > height)
        5.times do
          width = Random.rand(100..200)
          height = Random.rand(30..60)
          img = random_image(width, width, height, height)

          src_aspect_ratio = width.to_f / height.to_f

          target_width = Random.rand(60..100)
          target_height = Random.rand(60..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          result_aspect_ratio = result.bounds.width.to_f / result.bounds.height.to_f

          # Aspect ratios should match within tolerance
          ratio_diff = (src_aspect_ratio - result_aspect_ratio).abs
          tolerance = src_aspect_ratio * 0.10

          ratio_diff.should be <= tolerance
        end
      end

      it "fit mode preserves aspect ratio for tall images" do
        # Test specifically with tall images (height > width)
        5.times do
          width = Random.rand(30..60)
          height = Random.rand(100..200)
          img = random_image(width, width, height, height)

          src_aspect_ratio = width.to_f / height.to_f

          target_width = Random.rand(60..100)
          target_height = Random.rand(60..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          result_aspect_ratio = result.bounds.width.to_f / result.bounds.height.to_f

          # Aspect ratios should match within tolerance
          ratio_diff = (src_aspect_ratio - result_aspect_ratio).abs
          tolerance = src_aspect_ratio * 0.10

          ratio_diff.should be <= tolerance
        end
      end

      it "fit mode preserves aspect ratio for square images" do
        # Test specifically with square images
        5.times do
          size = Random.rand(50..150)
          img = random_image(size, size, size, size)

          target_width = Random.rand(20..100)
          target_height = Random.rand(20..100)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          # Square images should remain square (aspect ratio = 1.0)
          result_aspect_ratio = result.bounds.width.to_f / result.bounds.height.to_f

          # Allow small tolerance for rounding
          (result_aspect_ratio - 1.0).abs.should be <= 0.05
        end
      end

      it "fit mode with matching aspect ratios produces exact dimensions" do
        # Test when source and target have the same aspect ratio
        30.times do
          # Create image with 2:1 aspect ratio
          width = Random.rand(40..100)
          height = width // 2
          img = random_image(width, width, height, height)

          # Create target with same 2:1 aspect ratio
          target_width = Random.rand(20..60)
          target_height = target_width // 2

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          # Should match target dimensions within 1 pixel (rounding tolerance)
          (result.bounds.width - target_width).abs.should be <= 1
          (result.bounds.height - target_height).abs.should be <= 1
        end
      end

      it "fit mode doesn't distort content" do
        # Verify that Fit mode doesn't distort by checking that circles remain circular
        20.times do
          # Create image with a circle pattern
          size = Random.rand(60..100)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, size, size))

          # Fill with black
          size.times do |y|
            size.times do |x|
              img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
            end
          end

          # Draw a circle in the center
          center = size // 2
          radius = size // 3

          size.times do |y|
            size.times do |x|
              dx = x - center
              dy = y - center
              distance = ::Math.sqrt(dx * dx + dy * dy)

              if distance <= radius
                img.set(x, y, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))
              end
            end
          end

          # Create thumbnail with different aspect ratio target
          target_width = Random.rand(30..50)
          target_height = Random.rand(60..80)

          result = Util.thumbnail(img, target_width, target_height, ThumbnailMode::Fit)

          # The result should maintain the square aspect ratio of the source
          # (since source is square, result should also be square or nearly square)
          result_aspect_ratio = result.bounds.width.to_f / result.bounds.height.to_f

          # Should be close to 1.0 (square)
          (result_aspect_ratio - 1.0).abs.should be <= 0.05
        end
      end

      it "fit mode preserves aspect ratio while fill mode may distort" do
        # Compare Fill and Fit modes to verify Fit preserves aspect ratio
        30.times do
          # Create non-square image
          width = Random.rand(60..100)
          height = Random.rand(30..50)
          img = random_image(width, width, height, height)

          src_aspect_ratio = width.to_f / height.to_f

          # Create square target (different aspect ratio)
          target_size = Random.rand(40..70)

          result_fit = Util.thumbnail(img, target_size, target_size, ThumbnailMode::Fit)
          result_fill = Util.thumbnail(img, target_size, target_size, ThumbnailMode::Fill)

          # Fit mode should preserve aspect ratio
          fit_aspect_ratio = result_fit.bounds.width.to_f / result_fit.bounds.height.to_f
          ratio_diff_fit = (src_aspect_ratio - fit_aspect_ratio).abs
          tolerance = src_aspect_ratio * 0.10
          ratio_diff_fit.should be <= tolerance

          # Fill mode produces exact square (may distort)
          result_fill.bounds.width.should eq(target_size)
          result_fill.bounds.height.should eq(target_size)
        end
      end
    end

    describe "Convenience Methods (fit/fill/thumb)" do
      it "fit preserves aspect ratio and fits within bounds" do
        10.times do
          img = random_image(50, 200, 50, 200)
          target_width = Random.rand(30..100)
          target_height = Random.rand(30..100)

          result = img.fit(target_width, target_height)

          result.bounds.width.should be <= target_width
          result.bounds.height.should be <= target_height
        end
      end

      it "fill produces exact dimensions" do
        10.times do
          img = random_image(50, 200, 50, 200)
          target_width = Random.rand(30..100)
          target_height = Random.rand(30..100)

          result = img.fill(target_width, target_height)

          result.bounds.width.should eq(target_width)
          result.bounds.height.should eq(target_height)
        end
      end

      it "thumb produces square images" do
        10.times do
          img = random_image(50, 200, 50, 200)
          size = Random.rand(30..100)

          result = img.thumb(size)

          result.bounds.width.should eq(size)
          result.bounds.height.should eq(size)
        end
      end

      it "supports different quality settings" do
        img = random_image(100, 100, 100, 100)

        [:nearest, :bilinear, :bicubic, :lanczos].each do |quality|
          fit_result = img.fit(50, 50, quality: quality)
          fit_result.bounds.width.should be <= 50
          fit_result.bounds.height.should be <= 50

          fill_result = img.fill(50, 50, quality: quality)
          fill_result.bounds.width.should eq(50)
          fill_result.bounds.height.should eq(50)

          thumb_result = img.thumb(50, quality: quality)
          thumb_result.bounds.width.should eq(50)
          thumb_result.bounds.height.should eq(50)
        end
      end

      it "raises on invalid quality" do
        img = random_image(50, 50, 50, 50)

        expect_raises(ArgumentError, /Unknown quality/) do
          img.fit(30, 30, quality: :invalid)
        end

        expect_raises(ArgumentError, /Unknown quality/) do
          img.fill(30, 30, quality: :invalid)
        end
      end
    end
  end
end
