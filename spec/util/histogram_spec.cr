require "../spec_helper"

describe CrImage::Util::HistogramOps do
  describe "histogram computation" do
    it "computes histogram for uniform image" do
      img = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))

      hist = img.histogram
      hist.should be_a(CrImage::Util::Histogram)
      hist.total_pixels.should eq(2500)
      hist.mean.should be_close(128.0, 1.0)
      hist.median.should eq(128)
    end

    it "computes histogram statistics" do
      img = CrImage.rgba(100, 100)
      # Create gradient
      100.times do |y|
        100.times do |x|
          gray = (x * 255 // 100).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      hist = img.histogram
      hist.mean.should be_close(127.0, 5.0)
      hist.std_dev.should be > 0
      hist.percentile(50).should be_close(127, 10)
      hist.percentile(0).should be < 10
      hist.percentile(100).should be > 245
    end

    it "validates percentile parameter" do
      img = CrImage.rgba(10, 10)
      hist = img.histogram

      expect_raises(ArgumentError, /Percentile/) do
        hist.percentile(-1)
      end
      expect_raises(ArgumentError, /Percentile/) do
        hist.percentile(101)
      end
    end
  end

  describe "histogram equalization" do
    it "equalizes low-contrast image" do
      img = CrImage.rgba(100, 100)
      # Low contrast: only use 100-150 range
      100.times do |y|
        100.times do |x|
          gray = (100 + (x * 50 // 100)).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      original_hist = img.histogram
      equalized = img.equalize
      equalized_hist = equalized.histogram

      # Equalization should increase standard deviation (spread)
      equalized_hist.std_dev.should be > original_hist.std_dev
    end

    it "preserves image dimensions" do
      img = CrImage.rgba(50, 75)
      equalized = img.equalize

      equalized.bounds.width.should eq(50)
      equalized.bounds.height.should eq(75)
    end

    it "handles uniform image" do
      img = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))
      equalized = img.equalize

      # Should not crash on uniform image
      equalized.should be_a(CrImage::RGBA)
    end
  end

  describe "adaptive histogram equalization (CLAHE)" do
    it "applies CLAHE to image" do
      img = CrImage.rgba(100, 100)
      100.times do |y|
        100.times do |x|
          gray = (100 + (x + y) * 50 // 200).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      adaptive = img.equalize_adaptive
      adaptive.should be_a(CrImage::RGBA)
      adaptive.bounds.width.should eq(100)
      adaptive.bounds.height.should eq(100)
    end

    it "accepts custom tile size and clip limit" do
      img = CrImage.rgba(64, 64)
      adaptive = img.equalize_adaptive(tile_size: 16, clip_limit: 3.0)
      adaptive.should be_a(CrImage::RGBA)
    end

    it "validates parameters" do
      img = CrImage.rgba(50, 50)

      expect_raises(ArgumentError) do
        img.equalize_adaptive(tile_size: 0)
      end

      expect_raises(ArgumentError) do
        img.equalize_adaptive(clip_limit: 0.5)
      end

      expect_raises(ArgumentError) do
        img.equalize_adaptive(clip_limit: 5.0)
      end
    end
  end
end
