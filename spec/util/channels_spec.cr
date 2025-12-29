require "../spec_helper"

describe CrImage::Util::Channels do
  describe ".extract" do
    it "extracts red channel" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      red = CrImage::Util::Channels.extract(img, :red)

      red.bounds.width.should eq(10)
      red.at(5, 5).as(CrImage::Color::Gray).y.should eq(200)
    end

    it "extracts green channel" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      green = CrImage::Util::Channels.extract(img, :green)

      green.at(5, 5).as(CrImage::Color::Gray).y.should eq(100)
    end

    it "extracts blue channel" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      blue = CrImage::Util::Channels.extract(img, :blue)

      blue.at(5, 5).as(CrImage::Color::Gray).y.should eq(50)
    end

    it "extracts alpha channel" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 128_u8))
      alpha = CrImage::Util::Channels.extract(img, :alpha)

      alpha.at(5, 5).as(CrImage::Color::Gray).y.should eq(128)
    end

    it "raises for unknown channel" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, /Unknown channel/) do
        CrImage::Util::Channels.extract(img, :invalid)
      end
    end
  end

  describe ".combine" do
    it "combines RGB channels" do
      red = CrImage.gray(10, 10)
      green = CrImage.gray(10, 10)
      blue = CrImage.gray(10, 10)

      red.set(5, 5, CrImage::Color::Gray.new(200_u8))
      green.set(5, 5, CrImage::Color::Gray.new(100_u8))
      blue.set(5, 5, CrImage::Color::Gray.new(50_u8))

      result = CrImage::Util::Channels.combine(red, green, blue)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(200)
      color.g.should eq(100)
      color.b.should eq(50)
      color.a.should eq(255)
    end

    it "combines RGBA channels" do
      red = CrImage.gray(10, 10)
      green = CrImage.gray(10, 10)
      blue = CrImage.gray(10, 10)
      alpha = CrImage.gray(10, 10)

      red.set(5, 5, CrImage::Color::Gray.new(200_u8))
      green.set(5, 5, CrImage::Color::Gray.new(100_u8))
      blue.set(5, 5, CrImage::Color::Gray.new(50_u8))
      alpha.set(5, 5, CrImage::Color::Gray.new(128_u8))

      result = CrImage::Util::Channels.combine(red, green, blue, alpha)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(200)
      color.g.should eq(100)
      color.b.should eq(50)
      color.a.should eq(128)
    end

    it "raises for mismatched dimensions" do
      red = CrImage.gray(10, 10)
      green = CrImage.gray(20, 20)
      blue = CrImage.gray(10, 10)

      expect_raises(ArgumentError, /dimensions must match/) do
        CrImage::Util::Channels.combine(red, green, blue)
      end
    end
  end

  describe ".swap" do
    it "swaps red and blue channels" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      result = CrImage::Util::Channels.swap(img, :red, :blue)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(50)
      color.g.should eq(100)
      color.b.should eq(200)
    end

    it "swaps red and green channels" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      result = CrImage::Util::Channels.swap(img, :red, :green)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(100)
      color.g.should eq(200)
      color.b.should eq(50)
    end
  end

  describe ".invert_channel" do
    it "inverts red channel" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      result = CrImage::Util::Channels.invert_channel(img, :red)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(55)
      color.g.should eq(100)
      color.b.should eq(50)
    end
  end

  describe ".set_channel" do
    it "sets red channel to constant" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      result = CrImage::Util::Channels.set_channel(img, :red, 128_u8)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(128)
      color.g.should eq(100)
      color.b.should eq(50)
    end
  end

  describe ".multiply_channel" do
    it "multiplies channel by factor" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      result = CrImage::Util::Channels.multiply_channel(img, :red, 2.0)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(200)
    end

    it "clamps to 255" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 100_u8, 255_u8))
      result = CrImage::Util::Channels.multiply_channel(img, :red, 2.0)

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(255)
    end
  end

  describe ".split_rgb" do
    it "splits into three channels" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      r, g, b = CrImage::Util::Channels.split_rgb(img)

      r.at(5, 5).as(CrImage::Color::Gray).y.should eq(200)
      g.at(5, 5).as(CrImage::Color::Gray).y.should eq(100)
      b.at(5, 5).as(CrImage::Color::Gray).y.should eq(50)
    end
  end

  describe ".split_rgba" do
    it "splits into four channels" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 128_u8))
      r, g, b, a = CrImage::Util::Channels.split_rgba(img)

      r.at(5, 5).as(CrImage::Color::Gray).y.should eq(200)
      g.at(5, 5).as(CrImage::Color::Gray).y.should eq(100)
      b.at(5, 5).as(CrImage::Color::Gray).y.should eq(50)
      a.at(5, 5).as(CrImage::Color::Gray).y.should eq(128)
    end
  end

  describe "Image convenience methods" do
    it "extract_channel works" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      red = img.extract_channel(:red)
      red.at(5, 5).as(CrImage::Color::Gray).y.should eq(200)
    end

    it "swap_channels works" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      result = img.swap_channels(:red, :blue)
      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(50)
      color.b.should eq(200)
    end

    it "split_rgb works" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8))
      r, g, b = img.split_rgb
      r.bounds.width.should eq(10)
    end
  end
end
