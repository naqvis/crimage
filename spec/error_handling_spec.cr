require "./spec_helper"

describe "Error Handling" do
  describe "Transform validations" do
    it "validates resize dimensions" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /Width must be positive/) do
        CrImage::Transform.resize_nearest(img, 0, 100)
      end

      expect_raises(ArgumentError, /Height must be positive/) do
        CrImage::Transform.resize_nearest(img, 100, -1)
      end
    end

    it "validates blur radius" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /Radius must be positive/) do
        CrImage::Transform.blur_box(img, 0)
      end
    end

    it "validates brightness adjustment" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /must be between -255 and 255/) do
        CrImage::Transform.brightness(img, 300)
      end

      expect_raises(ArgumentError, /must be between -255 and 255/) do
        CrImage::Transform.brightness(img, -300)
      end
    end

    it "validates contrast factor" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /must be between 0.0 and 2.0/) do
        CrImage::Transform.contrast(img, -0.5)
      end

      expect_raises(ArgumentError, /must be between 0.0 and 2.0/) do
        CrImage::Transform.contrast(img, 3.0)
      end
    end

    it "validates crop rectangle" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /outside image bounds/) do
        CrImage::Transform.crop(img, CrImage.rect(200, 200, 300, 300))
      end
    end
  end

  describe "Drawing validations" do
    it "validates circle radius" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /Radius must be non-negative/) do
        img.draw_circle(50, 50, -10, color: CrImage::Color::RED)
      end
    end

    it "validates ellipse radii" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /Radii must be non-negative/) do
        img.draw_ellipse(50, 50, -10, 20, color: CrImage::Color::RED)
      end
    end

    it "validates polygon points" do
      img = CrImage.rgba(100, 100)
      points = [CrImage::Point.new(10, 10), CrImage::Point.new(20, 20)]

      expect_raises(CrImage::InsufficientPointsError, /at least 3 points/) do
        img.draw_polygon(points, outline: CrImage::Color::RED)
      end
    end
  end

  describe "Utility validations" do
    it "validates thumbnail dimensions" do
      img = CrImage.rgba(100, 100)

      expect_raises(ArgumentError, /Width must be positive/) do
        CrImage::Util.thumbnail(img, 0, 100)
      end

      expect_raises(ArgumentError, /Height must be positive/) do
        CrImage::Util.thumbnail(img, 100, -1)
      end
    end

    it "validates watermark opacity" do
      img = CrImage.rgba(100, 100)
      watermark = CrImage.rgba(50, 50)

      expect_raises(ArgumentError, /Opacity must be between/) do
        options = CrImage::Util::WatermarkOptions.new(opacity: 1.5)
      end

      expect_raises(ArgumentError, /Opacity must be between/) do
        options = CrImage::Util::WatermarkOptions.new(opacity: -0.5)
      end
    end
  end

  describe "In-place operation validations" do
    it "validates RGBA requirement" do
      gray_img = CrImage.gray(100, 100)

      expect_raises(ArgumentError, /only work on RGBA images/) do
        CrImage::Transform.brightness!(gray_img, 50)
      end
    end
  end

  describe "Color parsing" do
    it "handles invalid color formats" do
      expect_raises(ArgumentError, /Invalid color format/) do
        "invalid".to_color
      end

      expect_raises(ArgumentError, /Invalid/) do
        "#ZZZ".to_color
      end
    end
  end
end
