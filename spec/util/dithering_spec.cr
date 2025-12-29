require "../spec_helper"

describe CrImage::Util::Dithering do
  describe "dithering algorithms" do
    palette = CrImage::Color::Palette.new([
      CrImage::Color::BLACK,
      CrImage::Color::WHITE,
    ] of CrImage::Color::Color)

    color_palette = CrImage::Color::Palette.new([
      CrImage::Color.rgba(255, 0, 0, 255),
      CrImage::Color.rgba(0, 255, 0, 255),
      CrImage::Color.rgba(0, 0, 255, 255),
      CrImage::Color.rgba(255, 255, 0, 255),
    ] of CrImage::Color::Color)

    it "applies Floyd-Steinberg dithering" do
      img = CrImage.rgba(50, 50)
      50.times do |y|
        50.times do |x|
          gray = (x * 255 // 50).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      dithered = img.dither(palette)
      dithered.should be_a(CrImage::Paletted)
      dithered.bounds.width.should eq(50)
      dithered.bounds.height.should eq(50)
      dithered.palette.should eq(palette)
    end

    it "applies Atkinson dithering" do
      img = CrImage.rgba(30, 30)
      img.fill(CrImage::Color.rgba(128, 128, 128, 255))

      dithered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Atkinson)
      dithered.should be_a(CrImage::Paletted)
    end

    it "applies Sierra dithering" do
      img = CrImage.rgba(30, 30)
      dithered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Sierra)
      dithered.should be_a(CrImage::Paletted)
    end

    it "applies Burkes dithering" do
      img = CrImage.rgba(30, 30)
      dithered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Burkes)
      dithered.should be_a(CrImage::Paletted)
    end

    it "applies Stucki dithering" do
      img = CrImage.rgba(30, 30)
      dithered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Stucki)
      dithered.should be_a(CrImage::Paletted)
    end

    it "applies ordered (Bayer) dithering" do
      img = CrImage.rgba(50, 50)
      50.times do |y|
        50.times do |x|
          gray = (x * 255 // 50).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      dithered = img.dither(palette, CrImage::Util::DitheringAlgorithm::Ordered)
      dithered.should be_a(CrImage::Paletted)
    end

    it "works with color palettes" do
      img = CrImage.rgba(40, 40)
      40.times do |y|
        40.times do |x|
          r = (x * 255 // 40).to_u8
          g = (y * 255 // 40).to_u8
          img.set(x, y, CrImage::Color.rgba(r, g, 0, 255))
        end
      end

      dithered = img.dither(color_palette)
      dithered.should be_a(CrImage::Paletted)
      dithered.palette.should eq(color_palette)
    end

    it "provides convenience methods" do
      img = CrImage.rgba(20, 20)

      floyd = CrImage::Util::Dithering.floyd_steinberg(img, palette)
      floyd.should be_a(CrImage::Paletted)

      atkinson = CrImage::Util::Dithering.atkinson(img, palette)
      atkinson.should be_a(CrImage::Paletted)

      ordered = CrImage::Util::Dithering.ordered(img, palette)
      ordered.should be_a(CrImage::Paletted)
    end

    it "handles edge pixels correctly" do
      img = CrImage.rgba(10, 10)
      img.fill(CrImage::Color.rgba(128, 128, 128, 255))

      dithered = img.dither(palette)
      # Should not crash on edge pixels
      dithered.should be_a(CrImage::Paletted)
    end

    it "uses only palette colors" do
      img = CrImage.rgba(30, 30)
      30.times do |y|
        30.times do |x|
          gray = (x * 255 // 30).to_u8
          img.set(x, y, CrImage::Color.rgba(gray, gray, gray, 255))
        end
      end

      dithered = img.dither(palette)

      # All pixels should use palette indices
      30.times do |y|
        30.times do |x|
          index = dithered.color_index_at(x, y)
          index.should be < palette.size
        end
      end
    end
  end
end
