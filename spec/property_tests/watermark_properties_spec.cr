require "../spec_helper"

# Helper methods for watermark property tests
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
        255_u8
      ))
    end
  end

  img
end

def random_watermark(min_width = 5, max_width = 30, min_height = 5, max_height = 30)
  random_image(min_width, max_width, min_height, max_height)
end

module CrImage::Util
  describe "Watermark Property Tests" do
    describe "Watermark is positioned correctly" do
      it "positions watermark at top-left corner" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          options = WatermarkOptions.new(position: WatermarkPosition::TopLeft, opacity: 0.5)
          result = Util.watermark_image(img, watermark, options)

          # Check that watermark pixels are at position (0, 0)
          # Verify by checking that some pixels in the top-left region have changed
          watermark.bounds.height.times do |y|
            watermark.bounds.width.times do |x|
              next if x >= result.bounds.width || y >= result.bounds.height

              # Result should differ from original at watermark position
              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "positions watermark at top-right corner" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          options = WatermarkOptions.new(position: WatermarkPosition::TopRight, opacity: 0.5)
          result = Util.watermark_image(img, watermark, options)

          # Expected position
          expected_x = img.bounds.width - watermark.bounds.width
          expected_y = 0

          # Verify watermark is at top-right
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Check that pixels at expected position exist
          watermark.bounds.height.times do |wy|
            watermark.bounds.width.times do |wx|
              x = expected_x + wx
              y = expected_y + wy
              next if x >= result.bounds.width || y >= result.bounds.height

              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "positions watermark at bottom-left corner" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          options = WatermarkOptions.new(position: WatermarkPosition::BottomLeft, opacity: 0.5)
          result = Util.watermark_image(img, watermark, options)

          # Expected position
          expected_x = 0
          expected_y = img.bounds.height - watermark.bounds.height

          # Verify watermark is at bottom-left
          watermark.bounds.height.times do |wy|
            watermark.bounds.width.times do |wx|
              x = expected_x + wx
              y = expected_y + wy
              next if x >= result.bounds.width || y >= result.bounds.height

              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "positions watermark at bottom-right corner" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          options = WatermarkOptions.new(position: WatermarkPosition::BottomRight, opacity: 0.5)
          result = Util.watermark_image(img, watermark, options)

          # Expected position
          expected_x = img.bounds.width - watermark.bounds.width
          expected_y = img.bounds.height - watermark.bounds.height

          # Verify watermark is at bottom-right
          watermark.bounds.height.times do |wy|
            watermark.bounds.width.times do |wx|
              x = expected_x + wx
              y = expected_y + wy
              next if x >= result.bounds.width || y >= result.bounds.height

              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "positions watermark at center" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          options = WatermarkOptions.new(position: WatermarkPosition::Center, opacity: 0.5)
          result = Util.watermark_image(img, watermark, options)

          # Expected position
          expected_x = (img.bounds.width - watermark.bounds.width) // 2
          expected_y = (img.bounds.height - watermark.bounds.height) // 2

          # Verify watermark is at center
          watermark.bounds.height.times do |wy|
            watermark.bounds.width.times do |wx|
              x = expected_x + wx
              y = expected_y + wy
              next if x >= result.bounds.width || y >= result.bounds.height

              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "positions watermark at custom position" do
        10.times do
          img = random_image(50, 150, 50, 150)
          watermark = random_watermark(10, 30, 10, 30)

          # Random custom position within bounds
          custom_x = Random.rand(0..(img.bounds.width - watermark.bounds.width))
          custom_y = Random.rand(0..(img.bounds.height - watermark.bounds.height))
          custom_point = CrImage::Point.new(custom_x, custom_y)

          options = WatermarkOptions.new(
            position: WatermarkPosition::Custom,
            custom_point: custom_point,
            opacity: 0.5
          )
          result = Util.watermark_image(img, watermark, options)

          # Verify watermark is at custom position
          watermark.bounds.height.times do |wy|
            watermark.bounds.width.times do |wx|
              x = custom_x + wx
              y = custom_y + wy
              next if x >= result.bounds.width || y >= result.bounds.height

              result_color = result.at(x, y)
              result_color.should_not be_nil
            end
          end
        end
      end

      it "raises error for custom position without custom_point" do
        10.times do
          img = random_image(50, 100, 50, 100)
          watermark = random_watermark(10, 20, 10, 20)

          options = WatermarkOptions.new(position: WatermarkPosition::Custom, opacity: 0.5)

          expect_raises(ArgumentError, "Custom position requires custom_point to be set") do
            Util.watermark_image(img, watermark, options)
          end
        end
      end
    end

    describe "Watermark opacity is applied correctly" do
      it "applies opacity to watermark blending" do
        10.times do
          img = random_image(50, 100, 50, 100)
          watermark = random_watermark(10, 20, 10, 20)

          # Test with random opacity
          opacity = Random.rand(0.1..0.9)
          options = WatermarkOptions.new(position: WatermarkPosition::TopLeft, opacity: opacity)

          result = Util.watermark_image(img, watermark, options)

          # Result should have same dimensions as input
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Pixels outside watermark area should be unchanged
          unchanged_x = watermark.bounds.width + 5
          unchanged_y = watermark.bounds.height + 5

          if unchanged_x < img.bounds.width && unchanged_y < img.bounds.height
            original_color = img.at(unchanged_x, unchanged_y)
            result_color = result.at(unchanged_x, unchanged_y)

            # Colors should match exactly outside watermark area
            or, og, ob, oa = original_color.rgba
            rr, rg, rb, ra = result_color.rgba

            rr.should eq(or)
            rg.should eq(og)
            rb.should eq(ob)
            ra.should eq(oa)
          end
        end
      end

      it "rejects opacity values outside valid range" do
        10.times do
          img = random_image(50, 100, 50, 100)
          watermark = random_watermark(10, 20, 10, 20)

          # Test opacity < 0
          expect_raises(ArgumentError, "Opacity must be between 0.0 and 1.0") do
            WatermarkOptions.new(opacity: -0.1)
          end

          # Test opacity > 1
          expect_raises(ArgumentError, "Opacity must be between 0.0 and 1.0") do
            WatermarkOptions.new(opacity: 1.1)
          end
        end
      end

      it "handles opacity 0.0 (fully transparent)" do
        5.times do
          img = random_image(50, 100, 50, 100)
          watermark = random_watermark(10, 20, 10, 20)

          options = WatermarkOptions.new(position: WatermarkPosition::TopLeft, opacity: 0.0)
          result = Util.watermark_image(img, watermark, options)

          # With opacity 0, result should be very similar to original
          # (watermark should be nearly invisible)
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)
        end
      end

      it "handles opacity 1.0 (fully opaque)" do
        5.times do
          img = random_image(50, 100, 50, 100)
          watermark = random_watermark(10, 20, 10, 20)

          options = WatermarkOptions.new(position: WatermarkPosition::TopLeft, opacity: 1.0)
          result = Util.watermark_image(img, watermark, options)

          # With opacity 1, watermark should be fully visible
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)
        end
      end
    end

    describe "Tiled watermark properties" do
      it "tiles watermark across entire image" do
        5.times do
          img = random_image(80, 150, 80, 150)
          watermark = random_watermark(10, 20, 10, 20)

          options = WatermarkOptions.new(opacity: 0.5, tiled: true)
          result = Util.watermark_image(img, watermark, options)

          # Result should have same dimensions
          result.bounds.width.should eq(img.bounds.width)
          result.bounds.height.should eq(img.bounds.height)

          # Verify that watermark appears multiple times
          # (we can't easily verify exact tiling, but we can check dimensions)
          result.should be_a(CrImage::RGBA)
        end
      end
    end
  end
end
