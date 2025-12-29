require "../spec_helper"

describe CrImage::Util::Border do
  describe ".add_border" do
    it "adds border to image" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      bordered = CrImage::Util::Border.add_border(img, 10, CrImage::Color::WHITE)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(120) # 100 + 10*2
      height.should eq(120)
    end

    it "preserves image content in center" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLUE)
      bordered = CrImage::Util::Border.add_border(img, 10, CrImage::Color::WHITE)

      # Check center pixel is blue
      center = bordered.at(30, 30)
      r, g, b, _ = center.rgba
      (r >> 8).should be < 10
      (g >> 8).should be < 10
      (b >> 8).should eq(255)
    end

    it "creates white border" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      bordered = CrImage::Util::Border.add_border(img, 10, CrImage::Color::WHITE)

      # Check border pixel is white
      border_pixel = bordered.at(5, 5)
      r, g, b, _ = border_pixel.rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "raises on invalid width" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "border width must be positive") do
        CrImage::Util::Border.add_border(img, 0)
      end
    end
  end

  describe ".round_corners" do
    it "creates image with rounded corners" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      rounded = CrImage::Util::Border.round_corners(img, 20)

      bounds = rounded.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(100)
      height.should eq(100)
    end

    it "makes corners transparent" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      rounded = CrImage::Util::Border.round_corners(img, 20)

      # Top-left corner should be transparent
      corner = rounded.at(0, 0)
      _, _, _, a = corner.rgba
      (a >> 8).should eq(0)
    end

    it "preserves center content" do
      img = CrImage.rgba(100, 100, CrImage::Color::BLUE)
      rounded = CrImage::Util::Border.round_corners(img, 20)

      # Center should still be blue
      center = rounded.at(50, 50)
      r, g, b, a = center.rgba
      (r >> 8).should be < 10
      (g >> 8).should be < 10
      (b >> 8).should eq(255)
      (a >> 8).should eq(255)
    end

    it "raises on invalid radius" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "radius must be positive") do
        CrImage::Util::Border.round_corners(img, 0)
      end
    end
  end

  describe ".add_border_with_shadow" do
    it "creates bordered image with shadow space" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      bordered = CrImage::Util::Border.add_border_with_shadow(img, 10)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      # Should be larger than simple border due to shadow
      width.should be > 120
      height.should be > 120
    end

    it "raises on invalid parameters" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        CrImage::Util::Border.add_border_with_shadow(img, 0)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::Border.add_border_with_shadow(img, 10, shadow_offset: -1)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::Border.add_border_with_shadow(img, 10, shadow_blur: -1)
      end
    end
  end

  describe ".add_rounded_border" do
    it "creates rounded border" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      bordered = CrImage::Util::Border.add_rounded_border(img, 10, 20)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(120)
      height.should eq(120)
    end

    it "creates rounded border with shadow" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      bordered = CrImage::Util::Border.add_rounded_border(img, 10, 20, shadow: true)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x

      # Should be larger due to shadow
      width.should be > 120
    end

    it "raises on invalid parameters" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        CrImage::Util::Border.add_rounded_border(img, 0, 10)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::Border.add_rounded_border(img, 10, 0)
      end
    end
  end

  describe "Image convenience methods" do
    it "works with add_border" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      bordered = img.add_border(10, CrImage::Color::WHITE)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(70)
    end

    it "works with round_corners" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      rounded = img.round_corners(10)

      bounds = rounded.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(50)
    end

    it "works with add_border_with_shadow" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      bordered = img.add_border_with_shadow(10)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x

      width.should be > 70
    end

    it "works with add_rounded_border" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      bordered = img.add_rounded_border(10, 15)

      bounds = bordered.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(70)
    end
  end
end
