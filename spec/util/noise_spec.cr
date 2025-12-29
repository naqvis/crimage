require "../spec_helper"

describe CrImage::Util::Noise do
  describe ".add_noise" do
    it "adds noise to image" do
      img = CrImage.rgba(100, 100, CrImage::Color.rgb(128, 128, 128))
      noisy = CrImage::Util::Noise.add_noise(img, 0.1)

      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(100)
      height.should eq(100)
    end

    it "preserves image dimensions" do
      img = CrImage.rgba(50, 75, CrImage::Color::RED)
      noisy = CrImage::Util::Noise.add_noise(img, 0.2)

      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(50)
      height.should eq(75)
    end

    it "works with different noise types" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLUE)

      uniform = CrImage::Util::Noise.add_noise(img, 0.1, CrImage::Util::NoiseType::Uniform)
      uniform.bounds.width.should eq(50)

      gaussian = CrImage::Util::Noise.add_noise(img, 0.1, CrImage::Util::NoiseType::Gaussian)
      gaussian.bounds.width.should eq(50)

      salt_pepper = CrImage::Util::Noise.add_noise(img, 0.1, CrImage::Util::NoiseType::SaltAndPepper)
      salt_pepper.bounds.width.should eq(50)

      perlin = CrImage::Util::Noise.add_noise(img, 0.1, CrImage::Util::NoiseType::Perlin)
      perlin.bounds.width.should eq(50)
    end

    it "works with monochrome noise" do
      img = CrImage.rgba(50, 50, CrImage::Color::GREEN)
      noisy = CrImage::Util::Noise.add_noise(img, 0.1, monochrome: true)

      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(50)
    end

    it "raises on invalid amount" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "amount must be between 0.0 and 1.0") do
        CrImage::Util::Noise.add_noise(img, -0.1)
      end
      expect_raises(ArgumentError, "amount must be between 0.0 and 1.0") do
        CrImage::Util::Noise.add_noise(img, 1.5)
      end
    end

    it "handles zero noise amount" do
      img = CrImage.rgba(30, 30, CrImage::Color::RED)
      noisy = CrImage::Util::Noise.add_noise(img, 0.0)

      # Should be nearly identical to original
      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(30)
    end
  end

  describe ".generate_noise_texture" do
    it "generates noise texture" do
      noise = CrImage::Util::Noise.generate_noise_texture(200, 150)

      bounds = noise.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(200)
      height.should eq(150)
    end

    it "works with different noise types" do
      uniform = CrImage::Util::Noise.generate_noise_texture(50, 50, CrImage::Util::NoiseType::Uniform)
      uniform.bounds.width.should eq(50)

      gaussian = CrImage::Util::Noise.generate_noise_texture(50, 50, CrImage::Util::NoiseType::Gaussian)
      gaussian.bounds.width.should eq(50)

      perlin = CrImage::Util::Noise.generate_noise_texture(50, 50, CrImage::Util::NoiseType::Perlin)
      perlin.bounds.width.should eq(50)
    end

    it "works with different scales" do
      noise1 = CrImage::Util::Noise.generate_noise_texture(100, 100, scale: 0.5)
      noise1.bounds.width.should eq(100)

      noise2 = CrImage::Util::Noise.generate_noise_texture(100, 100, scale: 2.0)
      noise2.bounds.width.should eq(100)
    end

    it "raises on invalid dimensions" do
      expect_raises(ArgumentError, "width must be positive") do
        CrImage::Util::Noise.generate_noise_texture(0, 100)
      end
      expect_raises(ArgumentError, "height must be positive") do
        CrImage::Util::Noise.generate_noise_texture(100, -1)
      end
    end

    it "raises on invalid scale" do
      expect_raises(ArgumentError, "scale must be positive") do
        CrImage::Util::Noise.generate_noise_texture(100, 100, scale: 0.0)
      end
    end
  end

  describe "Image#add_noise" do
    it "works as instance method" do
      img = CrImage.rgba(60, 60, CrImage::Color::BLUE)
      noisy = img.add_noise(0.15)

      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(60)
    end

    it "accepts all parameters" do
      img = CrImage.rgba(40, 40, CrImage::Color::GREEN)
      noisy = img.add_noise(0.2, CrImage::Util::NoiseType::Uniform, monochrome: true)

      bounds = noisy.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(40)
    end
  end

  describe "CrImage.generate_noise" do
    it "works as module method" do
      noise = CrImage.generate_noise(150, 100)

      bounds = noise.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(150)
      height.should eq(100)
    end

    it "accepts all parameters" do
      noise = CrImage.generate_noise(80, 80, CrImage::Util::NoiseType::Perlin, scale: 1.5)

      bounds = noise.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(80)
    end
  end
end
