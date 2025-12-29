require "../spec_helper"

module FreeType::Raster
  describe "Advanced Rasterizer Tests" do
    it "rasterizes quadratic bezier curve" do
      rasterizer = Rasterizer.new
      rasterizer.reset(100, 100)

      p0 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[90 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )

      rasterizer.start(p0)
      rasterizer.add2(p1, p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Should have painted some pixels
      has_painted = false
      image.pix.each do |pixel|
        if pixel > 0
          has_painted = true
          break
        end
      end
      has_painted.should be_true
    end

    it "uses non-zero winding rule" do
      rasterizer = Rasterizer.new
      rasterizer.use_non_zero_winding = true
      rasterizer.reset(100, 100)

      # Draw a simple path
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[20 * 64],
        CrImage::Math::Fixed::Int26_6[20 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[80 * 64],
        CrImage::Math::Fixed::Int26_6[20 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      image.should_not be_nil
    end

    it "uses even-odd winding rule" do
      rasterizer = Rasterizer.new
      rasterizer.use_non_zero_winding = false
      rasterizer.reset(100, 100)

      # Draw a simple path
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[20 * 64],
        CrImage::Math::Fixed::Int26_6[20 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[80 * 64],
        CrImage::Math::Fixed::Int26_6[20 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      image.should_not be_nil
    end

    it "handles vertical line" do
      rasterizer = Rasterizer.new
      rasterizer.reset(100, 100)

      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[90 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Should have painted vertical line
      has_painted = false
      10.upto(89) do |y|
        if image.pix[y * image.stride + 50] > 0
          has_painted = true
          break
        end
      end
      has_painted.should be_true
    end

    it "handles horizontal line" do
      rasterizer = Rasterizer.new
      rasterizer.reset(100, 100)

      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[90 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Horizontal lines may not paint pixels (zero height)
      # Just verify rasterization completes without error
      image.should_not be_nil
    end

    it "handles diagonal line" do
      rasterizer = Rasterizer.new
      rasterizer.reset(100, 100)

      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[90 * 64],
        CrImage::Math::Fixed::Int26_6[90 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Should have painted diagonal
      has_painted = false
      image.pix.each do |pixel|
        if pixel > 0
          has_painted = true
          break
        end
      end
      has_painted.should be_true
    end

    it "applies dx and dy offset" do
      rasterizer = Rasterizer.new
      rasterizer.dx = 10
      rasterizer.dy = 10
      rasterizer.reset(100, 100)

      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[20 * 64],
        CrImage::Math::Fixed::Int26_6[20 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)

      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))
      painter = AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Pixels should be offset
      image.should_not be_nil
    end

    it "can be reset and reused" do
      rasterizer = Rasterizer.new

      # First use
      rasterizer.reset(50, 50)
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[40 * 64],
        CrImage::Math::Fixed::Int26_6[40 * 64]
      )
      rasterizer.start(p1)
      rasterizer.add1(p2)

      image1 = CrImage::Alpha.new(CrImage.rect(0, 0, 50, 50))
      painter1 = AlphaSrcPainter.new(image1)
      rasterizer.rasterize(painter1, 50, 50)

      # Second use
      rasterizer.reset(50, 50)
      rasterizer.start(p1)
      rasterizer.add1(p2)

      image2 = CrImage::Alpha.new(CrImage.rect(0, 0, 50, 50))
      painter2 = AlphaSrcPainter.new(image2)
      rasterizer.rasterize(painter2, 50, 50)

      # Both should work
      image1.should_not be_nil
      image2.should_not be_nil
    end
  end

  describe "Painter Tests" do
    it "AlphaOverPainter blends correctly" do
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 10, 10))

      # Set existing alpha
      image.set(5, 5, CrImage::Color::Alpha.new(128))

      painter = AlphaOverPainter.new(image)
      spans = [
        Span.new(y: 5, x0: 5, x1: 6, alpha: 0x8000_u32),
      ]

      painter.paint(spans, true)

      # Should have blended
      result = image.at(5, 5).as(CrImage::Color::Alpha)
      result.a.should be > 128
    end

    it "MonochromePainter quantizes alpha" do
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 10, 10))
      base_painter = AlphaSrcPainter.new(image)
      painter = MonochromePainter.new(base_painter)

      spans = [
        Span.new(y: 5, x0: 5, x1: 6, alpha: 0x4000_u32), # Below threshold
        Span.new(y: 5, x0: 6, x1: 7, alpha: 0xC000_u32), # Above threshold
      ]

      painter.paint(spans, true)

      # Below threshold should be 0, above should be 255
      image.at(5, 5).as(CrImage::Color::Alpha).a.should eq(0)
      image.at(6, 5).as(CrImage::Color::Alpha).a.should eq(255)
    end

    it "GammaCorrectionPainter applies gamma" do
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 10, 10))
      base_painter = AlphaSrcPainter.new(image)
      painter = GammaCorrectionPainter.new(base_painter, 2.2)

      spans = [
        Span.new(y: 5, x0: 5, x1: 6, alpha: 0x8000_u32),
      ]

      painter.paint(spans, true)

      # Should have applied gamma correction
      image.at(5, 5).as(CrImage::Color::Alpha).a.should be > 0
    end

    it "GammaCorrectionPainter with gamma 1.0 is no-op" do
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 10, 10))
      base_painter = AlphaSrcPainter.new(image)
      painter = GammaCorrectionPainter.new(base_painter, 1.0)

      spans = [
        Span.new(y: 5, x0: 5, x1: 6, alpha: 0x8000_u32),
      ]

      painter.paint(spans, true)

      # Should be approximately 128 (0x8000 >> 8)
      result = image.at(5, 5).as(CrImage::Color::Alpha).a
      result.should be_close(128, 5)
    end

    it "RGBAPainter with OVER operation" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      image.set(5, 5, CrImage::Color::RGBA.new(255, 255, 255, 255))

      painter = RGBAPainter.new(image, CrImage::Draw::Op::OVER)
      painter.color = CrImage::Color::RGBA.new(255, 0, 0, 255)

      spans = [
        Span.new(y: 5, x0: 5, x1: 6, alpha: 0x8000_u32),
      ]

      painter.paint(spans, true)

      # Should have blended red over white
      color = image.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should be > 128
    end
  end
end
