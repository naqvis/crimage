require "../spec_helper"

describe CrImage::Util::Metrics do
  describe "MSE (Mean Squared Error)" do
    it "returns 0 for identical images" do
      img1 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))
      img2 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))

      mse = img1.mse(img2)
      mse.should eq(0.0)
    end

    it "calculates MSE for different images" do
      img1 = CrImage.rgba(50, 50, CrImage::Color.rgba(100, 100, 100, 255))
      img2 = CrImage.rgba(50, 50, CrImage::Color.rgba(150, 150, 150, 255))

      mse = img1.mse(img2)
      mse.should be > 0
      mse.should be_close(2500.0, 100.0) # (50^2) * 3 channels
    end

    it "validates image dimensions" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(60, 60)

      expect_raises(ArgumentError, /dimensions/) do
        img1.mse(img2)
      end
    end
  end

  describe "PSNR (Peak Signal-to-Noise Ratio)" do
    it "returns infinity for identical images" do
      img1 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))
      img2 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))

      psnr = img1.psnr(img2)
      psnr.should eq(Float64::INFINITY)
    end

    it "calculates PSNR for different images" do
      img1 = CrImage.rgba(50, 50, CrImage::Color.rgba(100, 100, 100, 255))
      img2 = CrImage.rgba(50, 50, CrImage::Color.rgba(110, 110, 110, 255))

      psnr = img1.psnr(img2)
      psnr.should be > 0
      psnr.should be < 100 # Reasonable range for PSNR
    end

    it "higher PSNR means better quality" do
      original = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))
      similar = CrImage.rgba(50, 50, CrImage::Color.rgba(130, 130, 130, 255))
      different = CrImage.rgba(50, 50, CrImage::Color.rgba(200, 200, 200, 255))

      psnr_similar = original.psnr(similar)
      psnr_different = original.psnr(different)

      psnr_similar.should be > psnr_different
    end
  end

  describe "SSIM (Structural Similarity Index)" do
    it "returns 1.0 for identical images" do
      img1 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))
      img2 = CrImage.rgba(50, 50, CrImage::Color.rgba(128, 128, 128, 255))

      ssim = img1.ssim(img2)
      ssim.should be_close(1.0, 0.01)
    end

    it "calculates SSIM for different images" do
      img1 = CrImage.rgba(50, 50)
      img1.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)

      img2 = CrImage.rgba(50, 50)
      img2.draw_circle(25, 25, 15, color: CrImage::Color.rgba(50, 50, 50, 255), fill: true)

      ssim = img1.ssim(img2)
      ssim.should be > 0.0
      ssim.should be < 1.0
    end

    it "validates window size" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(50, 50)

      expect_raises(ArgumentError, /Window size/) do
        img1.ssim(img2, window_size: 0)
      end

      expect_raises(ArgumentError, /Window size/) do
        img1.ssim(img2, window_size: 10) # Must be odd
      end
    end

    it "validates image dimensions" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(60, 60)

      expect_raises(ArgumentError, /dimensions/) do
        img1.ssim(img2)
      end
    end
  end

  describe "perceptual hash" do
    it "generates consistent hash for same image" do
      img = CrImage.rgba(100, 100)
      img.draw_circle(50, 50, 30, color: CrImage::Color::BLACK, fill: true)

      hash1 = img.perceptual_hash
      hash2 = img.perceptual_hash

      hash1.should eq(hash2)
    end

    it "generates similar hashes for similar images" do
      img1 = CrImage.rgba(100, 100)
      img1.draw_circle(50, 50, 30, color: CrImage::Color::BLACK, fill: true)

      img2 = CrImage.rgba(100, 100)
      img2.draw_circle(50, 50, 32, color: CrImage::Color::BLACK, fill: true)

      hash1 = img1.perceptual_hash
      hash2 = img2.perceptual_hash

      distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
      distance.should be < 15 # Similar images should have low distance
    end

    it "generates different hashes for different images" do
      img1 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      img2 = CrImage.rgba(100, 100, CrImage::Color::BLACK)

      hash1 = img1.perceptual_hash
      hash2 = img2.perceptual_hash

      distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
      distance.should be > 20 # Very different images
    end
  end

  describe "hamming distance" do
    it "returns 0 for identical hashes" do
      hash = 0x123456789ABCDEF0_u64
      distance = CrImage::Util::Metrics.hamming_distance(hash, hash)
      distance.should eq(0)
    end

    it "counts differing bits" do
      hash1 = 0b0000000000000000_u64
      hash2 = 0b0000000000000011_u64

      distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
      distance.should eq(2)
    end

    it "handles maximum distance" do
      hash1 = 0x0000000000000000_u64
      hash2 = 0xFFFFFFFFFFFFFFFF_u64

      distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
      distance.should eq(64)
    end
  end
end
