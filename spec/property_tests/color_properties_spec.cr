require "../spec_helper"

# Helper to generate random RGBA color (fully opaque for color space conversions)
def random_rgba_color
  CrImage::Color::RGBA.new(
    Random.rand(256).to_u8,
    Random.rand(256).to_u8,
    Random.rand(256).to_u8,
    255_u8 # Always fully opaque for color space conversions
  )
end

# Helper to check if two colors are approximately equal within tolerance
def colors_approximately_equal(c1 : CrImage::Color::RGBA, c2 : CrImage::Color::RGBA, tolerance : Int32 = 1) : Bool
  (c1.r.to_i32 - c2.r.to_i32).abs <= tolerance &&
    (c1.g.to_i32 - c2.g.to_i32).abs <= tolerance &&
    (c1.b.to_i32 - c2.b.to_i32).abs <= tolerance &&
    (c1.a.to_i32 - c2.a.to_i32).abs <= tolerance
end

module CrImage::Color
  describe "Color Space Property Tests" do
    describe "HSV Round-trip Properties" do
      it "Color space round-trip for HSV" do
        # Run 10 iterations with random colors
        10.times do
          original = random_rgba_color

          # Convert to HSV and back
          hsv = original.to_hsv
          back = hsv.to_rgba

          # Colors should be approximately equal (within rounding tolerance)
          colors_approximately_equal(original, back, tolerance: 2).should be_true
        end
      end

      it "HSV round-trip for pure colors" do
        # Test with pure red, green, blue, black, white
        pure_colors = [
          RGBA.new(255_u8, 0_u8, 0_u8, 255_u8),     # Red
          RGBA.new(0_u8, 255_u8, 0_u8, 255_u8),     # Green
          RGBA.new(0_u8, 0_u8, 255_u8, 255_u8),     # Blue
          RGBA.new(0_u8, 0_u8, 0_u8, 255_u8),       # Black
          RGBA.new(255_u8, 255_u8, 255_u8, 255_u8), # White
          RGBA.new(128_u8, 128_u8, 128_u8, 255_u8), # Gray
        ]

        pure_colors.each do |original|
          hsv = original.to_hsv
          back = hsv.to_rgba

          colors_approximately_equal(original, back, tolerance: 2).should be_true
        end
      end

      it "HSV hue is in 0-360 range" do
        # Verify that hue is always in valid range
        10.times do
          color = random_rgba_color
          hsv = color.to_hsv

          hsv.h.should be >= 0.0
          hsv.h.should be < 360.0
        end
      end

      it "HSV saturation and value are in 0-1 range" do
        # Verify that saturation and value are in valid range
        10.times do
          color = random_rgba_color
          hsv = color.to_hsv

          hsv.s.should be >= 0.0
          hsv.s.should be <= 1.0
          hsv.v.should be >= 0.0
          hsv.v.should be <= 1.0
        end
      end

      it "Grayscale colors have zero saturation" do
        # Verify that grayscale colors (R=G=B) have saturation = 0
        5.times do
          intensity = Random.rand(256).to_u8
          gray = RGBA.new(intensity, intensity, intensity, 255_u8)
          hsv = gray.to_hsv

          hsv.s.should be < 0.01 # Allow small floating point error
        end
      end

      it "Black has value = 0" do
        # Verify that black has value = 0
        black = RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
        hsv = black.to_hsv

        hsv.v.should be < 0.01
      end

      it "White has saturation = 0 and value = 1" do
        # Verify that white has correct HSV values
        white = RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
        hsv = white.to_hsv

        hsv.s.should be < 0.01
        hsv.v.should be > 0.99
      end

      it "HSV preserves color relationships" do
        # Verify that brighter colors have higher value
        30.times do
          # Create two colors with same hue but different brightness
          base_color = random_rgba_color
          hsv = base_color.to_hsv

          # Create a darker version
          darker_hsv = HSV.new(hsv.h, hsv.s, hsv.v * 0.5)
          darker_rgb = darker_hsv.to_rgba

          # Darker color should have lower RGB values
          darker_rgb.r.should be <= base_color.r
          darker_rgb.g.should be <= base_color.g
          darker_rgb.b.should be <= base_color.b
        end
      end
    end

    describe "HSL Round-trip Properties" do
      it "Color space round-trip for HSL" do
        # Run 10 iterations with random colors
        10.times do
          original = random_rgba_color

          # Convert to HSL and back
          hsl = original.to_hsl
          back = hsl.to_rgba

          # Colors should be approximately equal (within rounding tolerance)
          colors_approximately_equal(original, back, tolerance: 2).should be_true
        end
      end

      it "HSL round-trip for pure colors" do
        # Test with pure red, green, blue, black, white
        pure_colors = [
          RGBA.new(255_u8, 0_u8, 0_u8, 255_u8),     # Red
          RGBA.new(0_u8, 255_u8, 0_u8, 255_u8),     # Green
          RGBA.new(0_u8, 0_u8, 255_u8, 255_u8),     # Blue
          RGBA.new(0_u8, 0_u8, 0_u8, 255_u8),       # Black
          RGBA.new(255_u8, 255_u8, 255_u8, 255_u8), # White
          RGBA.new(128_u8, 128_u8, 128_u8, 255_u8), # Gray
        ]

        pure_colors.each do |original|
          hsl = original.to_hsl
          back = hsl.to_rgba

          colors_approximately_equal(original, back, tolerance: 2).should be_true
        end
      end

      it "HSL hue is in 0-360 range" do
        # Verify that hue is always in valid range
        10.times do
          color = random_rgba_color
          hsl = color.to_hsl

          hsl.h.should be >= 0.0
          hsl.h.should be < 360.0
        end
      end

      it "HSL saturation and lightness are in 0-1 range" do
        # Verify that saturation and lightness are in valid range
        10.times do
          color = random_rgba_color
          hsl = color.to_hsl

          hsl.s.should be >= 0.0
          hsl.s.should be <= 1.0
          hsl.l.should be >= 0.0
          hsl.l.should be <= 1.0
        end
      end

      it "Grayscale colors have zero saturation" do
        # Verify that grayscale colors (R=G=B) have saturation = 0
        5.times do
          intensity = Random.rand(256).to_u8
          gray = RGBA.new(intensity, intensity, intensity, 255_u8)
          hsl = gray.to_hsl

          hsl.s.should be < 0.01 # Allow small floating point error
        end
      end

      it "Black has lightness = 0" do
        # Verify that black has lightness = 0
        black = RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
        hsl = black.to_hsl

        hsl.l.should be < 0.01
      end

      it "White has lightness = 1" do
        # Verify that white has lightness = 1
        white = RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
        hsl = white.to_hsl

        hsl.l.should be > 0.99
      end

      it "HSL preserves color relationships" do
        # Verify that lighter colors have higher lightness
        30.times do
          # Create two colors with same hue but different lightness
          base_color = random_rgba_color
          hsl = base_color.to_hsl

          # Create a lighter version
          lighter_hsl = HSL.new(hsl.h, hsl.s, (hsl.l + 0.3).clamp(0.0, 1.0))
          lighter_rgb = lighter_hsl.to_rgba

          # Lighter color should generally have higher RGB values
          # (at least one channel should be higher)
          (lighter_rgb.r >= base_color.r ||
            lighter_rgb.g >= base_color.g ||
            lighter_rgb.b >= base_color.b).should be_true
        end
      end
    end

    describe "LAB Round-trip Properties" do
      it "Color space round-trip for LAB" do
        # Run 10 iterations with random colors
        10.times do
          original = random_rgba_color

          # Convert to LAB and back
          lab = original.to_lab
          back = lab.to_rgba

          # Colors should be approximately equal (within rounding tolerance)
          # LAB conversion involves more complex math, so allow slightly higher tolerance
          colors_approximately_equal(original, back, tolerance: 3).should be_true
        end
      end

      it "LAB round-trip for pure colors" do
        # Test with pure red, green, blue, black, white
        pure_colors = [
          RGBA.new(255_u8, 0_u8, 0_u8, 255_u8),     # Red
          RGBA.new(0_u8, 255_u8, 0_u8, 255_u8),     # Green
          RGBA.new(0_u8, 0_u8, 255_u8, 255_u8),     # Blue
          RGBA.new(0_u8, 0_u8, 0_u8, 255_u8),       # Black
          RGBA.new(255_u8, 255_u8, 255_u8, 255_u8), # White
          RGBA.new(128_u8, 128_u8, 128_u8, 255_u8), # Gray
        ]

        pure_colors.each do |original|
          lab = original.to_lab
          back = lab.to_rgba

          colors_approximately_equal(original, back, tolerance: 3).should be_true
        end
      end

      it "LAB L is in 0-100 range" do
        # Verify that L (lightness) is in valid range
        10.times do
          color = random_rgba_color
          lab = color.to_lab

          lab.l.should be >= 0.0
          lab.l.should be <= 100.0
        end
      end

      it "LAB A and B are in valid ranges" do
        # Verify that A and B are in typical ranges
        10.times do
          color = random_rgba_color
          lab = color.to_lab

          # A and B typically range from -128 to 127
          lab.a.should be >= -128.0
          lab.a.should be <= 127.0
          lab.b.should be >= -128.0
          lab.b.should be <= 127.0
        end
      end

      it "Black has L near 0" do
        # Verify that black has L near 0
        black = RGBA.new(0_u8, 0_u8, 0_u8, 255_u8)
        lab = black.to_lab

        lab.l.should be < 1.0
      end

      it "White has L near 100" do
        # Verify that white has L near 100
        white = RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
        lab = white.to_lab

        lab.l.should be > 99.0
      end

      it "Grayscale colors have A and B near 0" do
        # Verify that grayscale colors have A and B near 0
        5.times do
          intensity = Random.rand(256).to_u8
          gray = RGBA.new(intensity, intensity, intensity, 255_u8)
          lab = gray.to_lab

          lab.a.abs.should be < 1.0
          lab.b.abs.should be < 1.0
        end
      end

      it "LAB preserves perceptual ordering" do
        # Verify that brighter colors have higher L values
        30.times do
          # Create a dark color
          dark = RGBA.new(
            Random.rand(0..100).to_u8,
            Random.rand(0..100).to_u8,
            Random.rand(0..100).to_u8,
            255_u8
          )

          # Create a bright color
          bright = RGBA.new(
            Random.rand(150..255).to_u8,
            Random.rand(150..255).to_u8,
            Random.rand(150..255).to_u8,
            255_u8
          )

          dark_lab = dark.to_lab
          bright_lab = bright.to_lab

          # Bright color should have higher L value
          bright_lab.l.should be > dark_lab.l
        end
      end
    end

    describe "Image Color Space Conversion Properties" do
      it "Image color space conversion preserves dimensions" do
        # Run 10 iterations with random images
        10.times do
          width = Random.rand(5..50)
          height = Random.rand(5..50)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with random colors
          height.times do |y|
            width.times do |x|
              img.set(x, y, random_rgba_color)
            end
          end

          # Test HSV conversion
          hsv_img = img.to_hsv
          hsv_img.bounds.width.should eq(width)
          hsv_img.bounds.height.should eq(height)

          # Test HSL conversion
          hsl_img = img.to_hsl
          hsl_img.bounds.width.should eq(width)
          hsl_img.bounds.height.should eq(height)

          # Test LAB conversion
          lab_img = img.to_lab
          lab_img.bounds.width.should eq(width)
          lab_img.bounds.height.should eq(height)
        end
      end

      it "Image conversion preserves pixel count" do
        # Verify that all pixels are converted
        30.times do
          width = Random.rand(5..30)
          height = Random.rand(5..30)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with non-black colors
          height.times do |y|
            width.times do |x|
              img.set(x, y, RGBA.new(
                Random.rand(100..255).to_u8,
                Random.rand(100..255).to_u8,
                Random.rand(100..255).to_u8,
                255_u8
              ))
            end
          end

          # Convert and verify all pixels are non-black
          hsv_img = img.to_hsv
          non_black_count = 0

          height.times do |y|
            width.times do |x|
              c = hsv_img.at(x, y).as(RGBA)
              non_black_count += 1 if c.r > 50 || c.g > 50 || c.b > 50
            end
          end

          # Most pixels should be non-black
          non_black_count.should be > (width * height * 0.9).to_i
        end
      end

      it "Image conversion handles 1x1 images" do
        # Test with minimal 1x1 image
        30.times do
          img = CrImage::RGBA.new(CrImage.rect(0, 0, 1, 1))
          img.set(0, 0, random_rgba_color)

          hsv_img = img.to_hsv
          hsv_img.bounds.width.should eq(1)
          hsv_img.bounds.height.should eq(1)

          hsl_img = img.to_hsl
          hsl_img.bounds.width.should eq(1)
          hsl_img.bounds.height.should eq(1)

          lab_img = img.to_lab
          lab_img.bounds.width.should eq(1)
          lab_img.bounds.height.should eq(1)
        end
      end

      it "Image conversion is approximately reversible" do
        # Verify that converting and back produces similar image
        20.times do
          width = Random.rand(5..20)
          height = Random.rand(5..20)
          img = CrImage::RGBA.new(CrImage.rect(0, 0, width, height))

          # Fill with random colors
          height.times do |y|
            width.times do |x|
              img.set(x, y, random_rgba_color)
            end
          end

          # Convert to HSV and back (round-trip through conversion methods)
          hsv_img = img.to_hsv

          # Check that pixels are approximately the same
          similar_pixels = 0
          height.times do |y|
            width.times do |x|
              original = img.at(x, y).as(RGBA)
              converted = hsv_img.at(x, y).as(RGBA)

              similar_pixels += 1 if colors_approximately_equal(original, converted, tolerance: 3)
            end
          end

          # Most pixels should be similar
          (similar_pixels.to_f / (width * height)).should be > 0.95
        end
      end
    end
  end
end
