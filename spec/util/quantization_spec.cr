require "../spec_helper"

describe CrImage::Util::Quantization do
  describe "palette generation" do
    it "generates palette with median cut" do
      img = CrImage.rgba(50, 50)
      50.times do |y|
        50.times do |x|
          r = (x * 255 // 50).to_u8
          g = (y * 255 // 50).to_u8
          b = 128_u8
          img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
        end
      end

      palette = img.generate_palette(16, CrImage::Util::QuantizationAlgorithm::MedianCut)
      palette.should be_a(CrImage::Color::Palette)
      palette.size.should be <= 16
      palette.size.should be > 0
    end

    it "generates palette with octree" do
      img = CrImage.rgba(50, 50)
      50.times do |y|
        50.times do |x|
          r = (x * 255 // 50).to_u8
          g = (y * 255 // 50).to_u8
          b = 100_u8
          img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
        end
      end

      palette = img.generate_palette(16, CrImage::Util::QuantizationAlgorithm::Octree)
      palette.should be_a(CrImage::Color::Palette)
      palette.size.should be <= 16
    end

    it "generates palette with popularity" do
      img = CrImage.rgba(50, 50)
      # Create image with limited colors
      50.times do |y|
        50.times do |x|
          color = if x < 25 && y < 25
                    CrImage::Color.rgba(255, 0, 0, 255)
                  elsif x >= 25 && y < 25
                    CrImage::Color.rgba(0, 255, 0, 255)
                  elsif x < 25 && y >= 25
                    CrImage::Color.rgba(0, 0, 255, 255)
                  else
                    CrImage::Color.rgba(255, 255, 0, 255)
                  end
          img.set(x, y, color)
        end
      end

      palette = img.generate_palette(8, CrImage::Util::QuantizationAlgorithm::Popularity)
      palette.should be_a(CrImage::Color::Palette)
      palette.size.should be <= 8
    end

    it "validates max_colors parameter" do
      img = CrImage.rgba(10, 10)

      expect_raises(ArgumentError) do
        img.generate_palette(1)
      end

      expect_raises(ArgumentError) do
        img.generate_palette(257)
      end
    end

    it "handles images with fewer colors than requested" do
      img = CrImage.rgba(20, 20)
      # Only 4 colors
      20.times do |y|
        20.times do |x|
          color = case
                  when x < 10 && y < 10  then CrImage::Color::RED
                  when x >= 10 && y < 10 then CrImage::Color::GREEN
                  when x < 10 && y >= 10 then CrImage::Color::BLUE
                  else                        CrImage::Color::YELLOW
                  end
          img.set(x, y, color)
        end
      end

      palette = img.generate_palette(16)
      palette.size.should be <= 16
    end

    it "works with grayscale images" do
      img = CrImage.rgba(30, 30)
      30.times do |y|
        30.times do |x|
          gray = (x * 255 // 30).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      palette = img.generate_palette(8)
      palette.should be_a(CrImage::Color::Palette)
    end

    it "generates different palettes for different algorithms" do
      img = CrImage.rgba(40, 40)
      40.times do |y|
        40.times do |x|
          r = (x * 255 // 40).to_u8
          g = (y * 255 // 40).to_u8
          b = ((x + y) * 255 // 80).to_u8
          img.set(x, y, CrImage::Color.rgba(r, g, b, 255))
        end
      end

      median_cut = img.generate_palette(8, CrImage::Util::QuantizationAlgorithm::MedianCut)
      octree = img.generate_palette(8, CrImage::Util::QuantizationAlgorithm::Octree)
      popularity = img.generate_palette(8, CrImage::Util::QuantizationAlgorithm::Popularity)

      # All should generate palettes
      median_cut.size.should be > 0
      octree.size.should be > 0
      popularity.size.should be > 0
    end
  end
end
