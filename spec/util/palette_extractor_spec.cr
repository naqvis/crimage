require "../spec_helper"

describe CrImage::Util::PaletteExtractor do
  describe ".extract" do
    it "extracts dominant colors from an image" do
      img = CrImage.rgba(100, 100)
      50.times do |y|
        100.times { |x| img.set(x, y, CrImage::Color::RED) }
      end
      50.times do |y|
        100.times { |x| img.set(x, y + 50, CrImage::Color::BLUE) }
      end

      colors = CrImage::Util::PaletteExtractor.extract(img, 2)
      colors.size.should eq(2)
    end

    it "respects the count parameter" do
      img = CrImage.rgba(50, 50)
      25.times { |y| 50.times { |x| img.set(x, y, CrImage::Color::RED) } }
      25.times { |y| 50.times { |x| img.set(x, y + 25, CrImage::Color::BLUE) } }

      colors = CrImage::Util::PaletteExtractor.extract(img, 5)
      colors.size.should be <= 5
      colors.size.should be >= 2
    end

    it "raises on invalid count" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        CrImage::Util::PaletteExtractor.extract(img, 0)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::PaletteExtractor.extract(img, 300)
      end
    end
  end

  describe ".extract_with_weights" do
    it "returns colors with their frequencies" do
      img = CrImage.rgba(100, 100)
      50.times do |y|
        100.times { |x| img.set(x, y, CrImage::Color::RED) }
      end
      50.times do |y|
        100.times { |x| img.set(x, y + 50, CrImage::Color::BLUE) }
      end

      weighted = CrImage::Util::PaletteExtractor.extract_with_weights(img, 2)
      weighted.size.should eq(2)

      total_weight = weighted.sum { |_, w| w }
      total_weight.should be_close(1.0, 0.01)
    end
  end

  describe ".dominant_color" do
    it "returns the most dominant color" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      dominant = CrImage::Util::PaletteExtractor.dominant_color(img)
      dominant.should_not be_nil
    end
  end

  describe "Image#extract_palette" do
    it "works as instance method" do
      img = CrImage.rgba(60, 60)
      20.times { |y| 60.times { |x| img.set(x, y, CrImage::Color::RED) } }
      20.times { |y| 60.times { |x| img.set(x, y + 20, CrImage::Color::GREEN) } }
      20.times { |y| 60.times { |x| img.set(x, y + 40, CrImage::Color::BLUE) } }

      colors = img.extract_palette(3)
      colors.size.should eq(3)
    end
  end

  describe "Image#dominant_color" do
    it "works as instance method" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLUE)
      color = img.dominant_color
      color.should_not be_nil
    end
  end
end
