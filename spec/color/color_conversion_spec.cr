require "../spec_helper"

module CrImage::Color
  describe "Color Conversion Tests" do
    it "converts RGBA to NRGBA" do
      # Premultiplied to non-premultiplied
      rgba = RGBA.new(128, 128, 128, 128)
      nrgba = nrgba_model.convert(rgba).as(NRGBA)

      # Should double the RGB values since alpha is 0.5
      nrgba.r.should be_close(255, 1)
      nrgba.g.should be_close(255, 1)
      nrgba.b.should be_close(255, 1)
      nrgba.a.should eq(128)
    end

    it "converts NRGBA to RGBA" do
      # Non-premultiplied to premultiplied
      nrgba = NRGBA.new(255, 255, 255, 128)
      rgba = rgba_model.convert(nrgba).as(RGBA)

      # Should halve the RGB values since alpha is 0.5
      rgba.r.should be_close(128, 1)
      rgba.g.should be_close(128, 1)
      rgba.b.should be_close(128, 1)
      rgba.a.should eq(128)
    end

    it "converts Gray to RGBA" do
      gray = Gray.new(128)
      rgba = rgba_model.convert(gray).as(RGBA)

      rgba.r.should eq(128)
      rgba.g.should eq(128)
      rgba.b.should eq(128)
      rgba.a.should eq(255)
    end

    it "converts RGBA to Gray" do
      rgba = RGBA.new(100, 150, 50, 255)
      gray = gray_model.convert(rgba).as(Gray)

      # Should use weighted average (0.299*R + 0.587*G + 0.114*B)
      gray.y.should be > 0
      gray.y.should be < 255
    end

    it "converts RGB to YCbCr" do
      y, cb, cr = rgb_to_ycbcr(255_u8, 0_u8, 0_u8)

      # Red should have high Y, low Cb, high Cr
      y.should be > 0
      cb.should be < 128
      cr.should be > 128
    end

    it "converts YCbCr to RGB" do
      r, g, b = ycbcr_to_rgb(128_u8, 128_u8, 128_u8)

      # Neutral gray
      r.should be_close(128, 5)
      g.should be_close(128, 5)
      b.should be_close(128, 5)
    end

    it "converts RGB to CMYK" do
      c, m, y, k = rgb_to_cmyk(255_u8, 0_u8, 0_u8)

      # Pure red
      c.should eq(0)
      m.should eq(255)
      y.should eq(255)
      k.should eq(0)
    end

    it "converts CMYK to RGB" do
      r, g, b = cmyk_to_rgb(0_u8, 255_u8, 255_u8, 0_u8)

      # Should be red
      r.should be > 200
      g.should be < 50
      b.should be < 50
    end

    it "handles zero alpha in NRGBA conversion" do
      nrgba = NRGBA.new(255, 255, 255, 0)
      rgba = rgba_model.convert(nrgba).as(RGBA)

      rgba.r.should eq(0)
      rgba.g.should eq(0)
      rgba.b.should eq(0)
      rgba.a.should eq(0)
    end

    it "handles full alpha in NRGBA conversion" do
      nrgba = NRGBA.new(128, 128, 128, 255)
      rgba = rgba_model.convert(nrgba).as(RGBA)

      rgba.r.should eq(128)
      rgba.g.should eq(128)
      rgba.b.should eq(128)
      rgba.a.should eq(255)
    end

    it "tests sq_diff function" do
      # Test squared difference calculation
      diff = sq_diff(100_u32, 150_u32)
      diff.should eq(625_u32) # (50*50)/4 = 625

      diff = sq_diff(150_u32, 100_u32)
      diff.should eq(625_u32) # Should be symmetric

      diff = sq_diff(100_u32, 100_u32)
      diff.should eq(0_u32)
    end

    it "converts between 16-bit color models" do
      rgba64 = RGBA64.new(0x8000, 0x8000, 0x8000, 0x8000)
      nrgba64 = nrgba64_model.convert(rgba64).as(NRGBA64)

      # Should double RGB values
      nrgba64.r.should be_close(0xffff, 100)
      nrgba64.a.should eq(0x8000)
    end

    it "converts Alpha to RGBA" do
      alpha = Alpha.new(128)
      rgba = rgba_model.convert(alpha).as(RGBA)

      rgba.r.should eq(128)
      rgba.g.should eq(128)
      rgba.b.should eq(128)
      rgba.a.should eq(128)
    end
  end

  describe "Palette Tests" do
    it "finds closest color in palette" do
      palette = Palette.new([
        RGBA.new(0, 0, 0, 255).as(Color),
        RGBA.new(255, 255, 255, 255).as(Color),
        RGBA.new(255, 0, 0, 255).as(Color),
      ])

      # Black should match index 0
      idx = palette.index(RGBA.new(10, 10, 10, 255))
      idx.should eq(0)

      # White should match index 1
      idx = palette.index(RGBA.new(250, 250, 250, 255))
      idx.should eq(1)

      # Red should match index 2
      idx = palette.index(RGBA.new(250, 10, 10, 255))
      idx.should eq(2)
    end

    it "converts color using palette" do
      palette = Palette.new([
        RGBA.new(0, 0, 0, 255).as(Color),
        RGBA.new(255, 255, 255, 255).as(Color),
      ])

      color = palette.convert(RGBA.new(128, 128, 128, 255))
      # Should pick closest (either black or white)
      [0, 255].should contain(color.as(RGBA).r)
    end

    it "raises error for empty palette" do
      palette = Palette.new([] of Color)

      expect_raises(Exception, /no colors/) do
        palette.convert(RGBA.new(128, 128, 128, 255))
      end
    end
  end
end
