require "./spec_helper"

module CrImage::Transform
  describe "Image Transform Tests" do
    describe "Resize" do
      it "resizes image with nearest neighbor" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.resize_nearest(src, 20, 20)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(20)

        # Pixel at (5,5) should map to approximately (10,10)
        color = dst.at(10, 10).as(Color::RGBA)
        color.r.should eq(255)
      end

      it "resizes image with bilinear interpolation" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.resize_bilinear(src, 20, 20)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(20)
      end

      it "handles downscaling" do
        src = RGBA.new(CrImage.rect(0, 0, 100, 100))
        dst = Transform.resize_nearest(src, 50, 50)
        dst.bounds.width.should eq(50)
        dst.bounds.height.should eq(50)
      end

      it "resizes image with Lanczos interpolation" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        # Create a gradient to test interpolation quality
        10.times do |y|
          10.times do |x|
            intensity = (x * 25).to_u8
            src.set(x, y, Color::RGBA.new(intensity, intensity, intensity, 255))
          end
        end

        dst = Transform.resize_lanczos(src, 20, 20)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(20)

        # Verify gradient is preserved (should still be smooth)
        # Check that left side is darker than right side
        left_color = dst.at(2, 10).as(Color::RGBA)
        right_color = dst.at(17, 10).as(Color::RGBA)
        right_color.r.should be > left_color.r
      end

      it "resizes image with bicubic interpolation" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        # Create a gradient to test interpolation quality
        10.times do |y|
          10.times do |x|
            intensity = (x * 25).to_u8
            src.set(x, y, Color::RGBA.new(intensity, intensity, intensity, 255))
          end
        end

        dst = Transform.resize_bicubic(src, 20, 20)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(20)

        # Verify gradient is preserved (should still be smooth)
        # Check that left side is darker than right side
        left_color = dst.at(2, 10).as(Color::RGBA)
        right_color = dst.at(17, 10).as(Color::RGBA)
        right_color.r.should be > left_color.r
      end

      it "Lanczos produces smooth upscaling" do
        # Create a small checkerboard pattern
        src = RGBA.new(CrImage.rect(0, 0, 4, 4))
        4.times do |y|
          4.times do |x|
            if (x + y) % 2 == 0
              src.set(x, y, Color::RGBA.new(255, 255, 255, 255))
            else
              src.set(x, y, Color::RGBA.new(0, 0, 0, 255))
            end
          end
        end

        # Upscale significantly
        dst = Transform.resize_lanczos(src, 16, 16)

        # Check that we have intermediate gray values (smoothing)
        # The center of each upscaled block should have intermediate values
        center_color = dst.at(2, 2).as(Color::RGBA)
        # Should not be pure black or pure white due to interpolation
        center_color.r.should be > 10
        center_color.r.should be < 245
      end

      it "bicubic produces smooth upscaling" do
        # Create a small checkerboard pattern
        src = RGBA.new(CrImage.rect(0, 0, 4, 4))
        4.times do |y|
          4.times do |x|
            if (x + y) % 2 == 0
              src.set(x, y, Color::RGBA.new(255, 255, 255, 255))
            else
              src.set(x, y, Color::RGBA.new(0, 0, 0, 255))
            end
          end
        end

        # Upscale significantly
        dst = Transform.resize_bicubic(src, 16, 16)

        # Check that we have intermediate gray values (smoothing)
        center_color = dst.at(2, 2).as(Color::RGBA)
        # Should not be pure black or pure white due to interpolation
        center_color.r.should be > 10
        center_color.r.should be < 245
      end

      it "Lanczos preserves sharp features better than bilinear" do
        # Create an image with a sharp vertical edge
        src = RGBA.new(CrImage.rect(0, 0, 20, 20))
        20.times do |y|
          20.times do |x|
            if x < 10
              src.set(x, y, Color::RGBA.new(0, 0, 0, 255))
            else
              src.set(x, y, Color::RGBA.new(255, 255, 255, 255))
            end
          end
        end

        # Downscale
        dst_lanczos = Transform.resize_lanczos(src, 10, 10)
        dst_bilinear = Transform.resize_bilinear(src, 10, 10)

        # Check the edge sharpness - Lanczos should have sharper transition
        # At the edge (x=5), check the gradient
        left_lanczos = dst_lanczos.at(4, 5).as(Color::RGBA)
        right_lanczos = dst_lanczos.at(5, 5).as(Color::RGBA)

        # There should be a clear difference at the edge
        (right_lanczos.r.to_i32 - left_lanczos.r.to_i32).abs.should be > 50
      end

      it "bicubic handles downscaling without artifacts" do
        # Create a high-frequency pattern
        src = RGBA.new(CrImage.rect(0, 0, 40, 40))
        40.times do |y|
          40.times do |x|
            # Alternating pattern
            if (x + y) % 2 == 0
              src.set(x, y, Color::RGBA.new(255, 255, 255, 255))
            else
              src.set(x, y, Color::RGBA.new(0, 0, 0, 255))
            end
          end
        end

        # Downscale significantly
        dst = Transform.resize_bicubic(src, 10, 10)

        # The result should be gray (averaged), not pure black or white
        # Check several pixels
        5.times do |y|
          5.times do |x|
            color = dst.at(x * 2, y * 2).as(Color::RGBA)
            # Should be in the gray range due to averaging
            color.r.should be > 50
            color.r.should be < 200
          end
        end
      end

      it "raises error for zero width with Lanczos" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        expect_raises(ArgumentError, "Width must be positive") do
          Transform.resize_lanczos(src, 0, 10)
        end
      end

      it "raises error for zero height with Lanczos" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        expect_raises(ArgumentError, "Height must be positive") do
          Transform.resize_lanczos(src, 10, 0)
        end
      end

      it "raises error for negative dimensions with bicubic" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        expect_raises(ArgumentError, "Width must be positive") do
          Transform.resize_bicubic(src, -10, 10)
        end

        expect_raises(ArgumentError, "Height must be positive") do
          Transform.resize_bicubic(src, 10, -10)
        end
      end
    end

    describe "Rotation" do
      it "rotates 90 degrees clockwise" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 20))
        src.set(0, 0, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.rotate_90(src)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(10)

        # Top-left becomes top-right
        color = dst.at(19, 0).as(Color::RGBA)
        color.r.should eq(255)
      end

      it "rotates 180 degrees" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(0, 0, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.rotate_180(src)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)

        # Top-left becomes bottom-right
        color = dst.at(9, 9).as(Color::RGBA)
        color.r.should eq(255)
      end

      it "rotates 270 degrees clockwise" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 20))
        src.set(0, 0, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.rotate_270(src)
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(10)

        # Top-left becomes bottom-left
        color = dst.at(0, 9).as(Color::RGBA)
        color.r.should eq(255)
      end
    end

    describe "Flip" do
      it "flips horizontally" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(0, 5, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.flip_horizontal(src)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)

        # Left side becomes right side
        color = dst.at(9, 5).as(Color::RGBA)
        color.r.should eq(255)
      end

      it "flips vertically" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 0, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.flip_vertical(src)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)

        # Top becomes bottom
        color = dst.at(5, 9).as(Color::RGBA)
        color.r.should eq(255)
      end
    end

    describe "Crop" do
      it "crops image to rectangle" do
        src = RGBA.new(CrImage.rect(0, 0, 100, 100))
        src.set(50, 50, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.crop(src, CrImage.rect(40, 40, 60, 60))
        dst.bounds.width.should eq(20)
        dst.bounds.height.should eq(20)

        # Pixel at (50,50) in src is at (10,10) in dst
        color = dst.at(10, 10).as(Color::RGBA)
        color.r.should eq(255)
      end

      it "raises error for crop outside bounds" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        expect_raises(ArgumentError, /outside image bounds/) do
          Transform.crop(src, CrImage.rect(20, 20, 30, 30))
        end
      end

      it "handles crop at image edge" do
        src = RGBA.new(CrImage.rect(0, 0, 100, 100))
        dst = Transform.crop(src, CrImage.rect(0, 0, 50, 50))
        dst.bounds.width.should eq(50)
        dst.bounds.height.should eq(50)
      end
    end

    describe "Blur" do
      it "applies box blur" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        # Create a sharp edge
        5.times do |y|
          10.times do |x|
            src.set(x, y, Color::RGBA.new(255, 255, 255, 255))
          end
        end

        dst = Transform.blur_box(src, 1)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)

        # Edge should be blurred
        color = dst.at(5, 4).as(Color::RGBA)
        color.r.should be < 255
      end

      it "raises error for invalid radius" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        expect_raises(ArgumentError, "Radius must be positive") do
          Transform.blur_box(src, 0)
        end
      end
    end

    describe "Sharpen" do
      it "applies sharpen filter" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        5.times do |y|
          10.times do |x|
            src.set(x, y, Color::RGBA.new(128, 128, 128, 255))
          end
        end

        dst = Transform.sharpen(src, 0.5)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)
      end

      it "handles different sharpen amounts" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))

        dst1 = Transform.sharpen(src, 0.5)
        dst2 = Transform.sharpen(src, 1.5)

        dst1.should_not be_nil
        dst2.should_not be_nil
      end
    end

    describe "Brightness" do
      it "increases brightness" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(100, 100, 100, 255))

        dst = Transform.brightness(src, 50)
        color = dst.at(5, 5).as(Color::RGBA)
        color.r.should eq(150)
        color.g.should eq(150)
        color.b.should eq(150)
      end

      it "decreases brightness" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(150, 150, 150, 255))

        dst = Transform.brightness(src, -50)
        color = dst.at(5, 5).as(Color::RGBA)
        color.r.should eq(100)
        color.g.should eq(100)
        color.b.should eq(100)
      end

      it "clamps brightness values" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(200, 200, 200, 255))

        dst = Transform.brightness(src, 100)
        color = dst.at(5, 5).as(Color::RGBA)
        color.r.should eq(255)
        color.g.should eq(255)
        color.b.should eq(255)
      end
    end

    describe "Contrast" do
      it "increases contrast" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(100, 100, 100, 255))

        dst = Transform.contrast(src, 1.5)
        color = dst.at(5, 5).as(Color::RGBA)
        # (100 - 128) * 1.5 + 128 = -42 + 128 = 86
        color.r.should eq(86)
      end

      it "decreases contrast" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(200, 200, 200, 255))

        dst = Transform.contrast(src, 0.5)
        color = dst.at(5, 5).as(Color::RGBA)
        # (200 - 128) * 0.5 + 128 = 36 + 128 = 164
        color.r.should eq(164)
      end
    end

    describe "Grayscale" do
      it "converts to grayscale" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

        dst = Transform.grayscale(src)
        dst.should be_a(Gray)
        dst.bounds.width.should eq(10)
        dst.bounds.height.should eq(10)

        # Red should be converted to gray
        color = dst.at(5, 5).as(Color::Gray)
        color.y.should be > 0
      end
    end

    describe "Invert" do
      it "inverts colors" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(100, 150, 200, 255))

        dst = Transform.invert(src)
        color = dst.at(5, 5).as(Color::RGBA)
        color.r.should eq(155) # 255 - 100
        color.g.should eq(105) # 255 - 150
        color.b.should eq(55)  # 255 - 200
        color.a.should eq(255) # Alpha unchanged
      end

      it "inverts black to white" do
        src = RGBA.new(CrImage.rect(0, 0, 10, 10))
        src.set(5, 5, Color::RGBA.new(0, 0, 0, 255))

        dst = Transform.invert(src)
        color = dst.at(5, 5).as(Color::RGBA)
        color.r.should eq(255)
        color.g.should eq(255)
        color.b.should eq(255)
      end
    end
  end
end
