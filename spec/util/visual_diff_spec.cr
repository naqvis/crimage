require "../spec_helper"

describe CrImage::Util::VisualDiff do
  describe ".diff" do
    it "returns identical grayscale for identical images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      diff = CrImage::Util::VisualDiff.diff(img1, img2)

      diff.bounds.width.should eq(10)
      diff.bounds.height.should eq(10)

      # All pixels should be grayscale (dimmed)
      color = diff.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(color.g)
      color.g.should eq(color.b)
    end

    it "highlights different pixels in red" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      # Make one pixel different
      img2.set(5, 5, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      diff = CrImage::Util::VisualDiff.diff(img1, img2)

      # Different pixel should be red
      color = diff.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(255)
      color.g.should eq(0)
      color.b.should eq(0)
    end

    it "uses custom highlight color" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      green = CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8)
      diff = CrImage::Util::VisualDiff.diff(img1, img2, highlight_color: green)

      color = diff.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(0)
      color.g.should eq(255)
      color.b.should eq(0)
    end

    it "respects threshold" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(105_u8, 105_u8, 105_u8, 255_u8))

      # With threshold 10, should not highlight (diff is 5)
      diff1 = CrImage::Util::VisualDiff.diff(img1, img2, threshold: 10)
      color1 = diff1.at(5, 5).as(CrImage::Color::RGBA)
      color1.r.should_not eq(255)

      # With threshold 3, should highlight (diff is 5)
      diff2 = CrImage::Util::VisualDiff.diff(img1, img2, threshold: 3)
      color2 = diff2.at(5, 5).as(CrImage::Color::RGBA)
      color2.r.should eq(255)
    end

    it "raises for different dimensions" do
      img1 = CrImage.rgba(10, 10)
      img2 = CrImage.rgba(20, 20)

      expect_raises(ArgumentError, /same dimensions/) do
        CrImage::Util::VisualDiff.diff(img1, img2)
      end
    end
  end

  describe ".diff_count" do
    it "returns 0 for identical images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      CrImage::Util::VisualDiff.diff_count(img1, img2).should eq(0)
    end

    it "counts different pixels" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      img2.set(0, 0, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))
      img2.set(5, 5, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))
      img2.set(9, 9, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      CrImage::Util::VisualDiff.diff_count(img1, img2).should eq(3)
    end
  end

  describe ".diff_percent" do
    it "returns 0 for identical images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      CrImage::Util::VisualDiff.diff_percent(img1, img2).should eq(0.0)
    end

    it "returns 100 for completely different images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(0_u8, 0_u8, 0_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

      CrImage::Util::VisualDiff.diff_percent(img1, img2).should eq(100.0)
    end

    it "calculates correct percentage" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      # Change 10 pixels out of 100
      10.times { |i| img2.set(i, 0, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8)) }

      CrImage::Util::VisualDiff.diff_percent(img1, img2).should eq(10.0)
    end
  end

  describe ".identical?" do
    it "returns true for identical images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      CrImage::Util::VisualDiff.identical?(img1, img2).should be_true
    end

    it "returns false for different images" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      CrImage::Util::VisualDiff.identical?(img1, img2).should be_false
    end

    it "respects tolerance" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      img2.set(0, 0, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))
      img2.set(1, 0, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      CrImage::Util::VisualDiff.identical?(img1, img2, tolerance: 1).should be_false
      CrImage::Util::VisualDiff.identical?(img1, img2, tolerance: 2).should be_true
    end

    it "returns false for different dimensions" do
      img1 = CrImage.rgba(10, 10)
      img2 = CrImage.rgba(20, 20)

      CrImage::Util::VisualDiff.identical?(img1, img2).should be_false
    end
  end

  describe "Image convenience methods" do
    it "visual_diff works on Image" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      diff = img1.visual_diff(img2)
      diff.bounds.width.should eq(10)
    end

    it "identical? works on Image" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      img2 = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      img1.identical?(img2).should be_true
    end
  end
end
