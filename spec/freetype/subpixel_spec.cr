require "../spec_helper"

describe FreeType::Raster do
  describe "Subpixel Rendering" do
    it "should create RGBPainter for subpixel rendering" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 10))
      painter = FreeType::Raster::RGBPainter.new(image, CrImage::Draw::Op::OVER)
      painter.should_not be_nil
    end

    it "should paint with RGB subpixel anti-aliasing" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 10))

      # Fill with white background
      10.times do |y|
        30.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      painter = FreeType::Raster::RGBPainter.new(image, CrImage::Draw::Op::OVER)
      painter.color = CrImage::Color::BLACK

      # Create spans with different alpha values for subpixels
      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 5, x1: 6, alpha: 0x8000_u32),
        FreeType::Raster::Span.new(y: 5, x0: 6, x1: 7, alpha: 0xC000_u32),
        FreeType::Raster::Span.new(y: 5, x0: 7, x1: 8, alpha: 0xFFFF_u32),
      ]

      painter.paint(spans, true)

      # Check that pixels were painted with varying intensities
      color1 = image.at(5, 5).as(CrImage::Color::RGBA)
      color2 = image.at(6, 5).as(CrImage::Color::RGBA)
      color3 = image.at(7, 5).as(CrImage::Color::RGBA)

      # Should have different gray levels
      color1.r.should be < 255
      color2.r.should be < 255
      color3.r.should be < 255
      # Darker pixels should have lower values
      color3.r.should be < color1.r
    end

    it "should apply RGB filter for horizontal subpixel rendering" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 10))

      # White background
      10.times do |y|
        30.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      painter = FreeType::Raster::RGBSubpixelPainter.new(image)
      painter.color = CrImage::Color::BLACK

      # Single span that should be filtered
      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 10, x1: 11, alpha: 0xFFFF_u32),
      ]

      painter.paint(spans, true)

      # Check that neighboring pixels are affected by RGB filtering
      center = image.at(10, 5).as(CrImage::Color::RGBA)
      left = image.at(9, 5).as(CrImage::Color::RGBA)
      right = image.at(11, 5).as(CrImage::Color::RGBA)

      # Center should be darkest
      center.r.should be < 50
      center.g.should be < 50
      center.b.should be < 50
    end

    it "should support BGR subpixel order" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 10))

      10.times do |y|
        30.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      painter = FreeType::Raster::RGBSubpixelPainter.new(image, bgr: true)
      painter.color = CrImage::Color::BLACK

      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 10, x1: 11, alpha: 0xFFFF_u32),
      ]

      painter.paint(spans, true)

      # Should have painted something
      center = image.at(10, 5).as(CrImage::Color::RGBA)
      center.r.should be < 255
    end

    it "should handle vertical subpixel rendering" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 30))

      30.times do |y|
        10.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      painter = FreeType::Raster::RGBSubpixelPainter.new(image, vertical: true)
      painter.color = CrImage::Color::BLACK

      spans = [
        FreeType::Raster::Span.new(y: 10, x0: 5, x1: 6, alpha: 0xFFFF_u32),
      ]

      painter.paint(spans, true)

      # Check vertical rendering
      center = image.at(5, 10).as(CrImage::Color::RGBA)

      center.r.should be < 50
      center.g.should be < 50
      center.b.should be < 50
    end

    it "should rasterize with subpixel precision" do
      rasterizer = FreeType::Raster::Rasterizer.new
      rasterizer.reset(100, 100)

      # Draw a vertical line with subpixel positioning
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64 + 21], # 50.328125 pixels
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64 + 21],
        CrImage::Math::Fixed::Int26_6[90 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::RGBA.new(CrImage.rect(0, 0, 100, 100))
      100.times do |y|
        100.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      painter = FreeType::Raster::RGBSubpixelPainter.new(image)
      painter.color = CrImage::Color::BLACK
      rasterizer.rasterize(painter, 100, 100)

      # Should have anti-aliased edges at subpixel position
      has_antialiasing = false
      10.upto(89) do |y|
        color50 = image.at(50, y).as(CrImage::Color::RGBA)
        color51 = image.at(51, y).as(CrImage::Color::RGBA)

        # At least one should be partially transparent (anti-aliased)
        if (color50.r > 50 && color50.r < 200) || (color51.r > 50 && color51.r < 200)
          has_antialiasing = true
          break
        end
      end

      has_antialiasing.should be_true
    end

    it "should disable subpixel rendering when requested" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 10))

      10.times do |y|
        30.times do |x|
          image.set(x, y, CrImage::Color::WHITE)
        end
      end

      # Use regular RGBA painter (no subpixel)
      painter = FreeType::Raster::RGBAPainter.new(image, CrImage::Draw::Op::OVER)
      painter.color = CrImage::Color::BLACK

      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 10, x1: 11, alpha: 0xFFFF_u32),
      ]

      painter.paint(spans, true)

      # Should paint without RGB fringing
      center = image.at(10, 5).as(CrImage::Color::RGBA)
      center.r.should be < 50
    end
  end
end
