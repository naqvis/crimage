require "../spec_helper"

module CrImage::Color
  private def self.delta(x, y)
    x > y ? x - y : y - x
  end

  private def self.eq(c0 : Color, c1 : Color) : Bool
    r0, g0, b0, a0 = c0.rgba
    r1, g1, b1, a1 = c1.rgba
    r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
  end

  describe "YCbCr Tests" do
    it "Test subset of of RGB space can be converted to YCbCr and back to within 2/256 tolerance" do
      r = 0
      while r < 256
        g = 0
        while g < 256
          b = 0
          while b < 256
            r0, g0, b0 = r.to_u8, g.to_u8, b.to_u8
            y, cb, cr = rgb_to_ycbcr(r0, g0, b0)
            r1, g1, b1 = ycbcr_to_rgb(y, cb, cr)
            if delta(r0, r1) > 2 || delta(g0, g1) > 2 || delta(b0, b1) > 2
              fail "r0, g0, b0 = #{r0}, #{g0}, #{b0}\ny,  cb, cr = #{y}, #{cb}, #{cr}\nr1, g1, b1 = #{r1}, #{g1}, #{b1}"
            end
            b += 3
          end
          g += 5
        end
        r += 7
      end
    end

    it "Test that calling the RGBA method (16 bit color) then truncating to 8 bits is equivalent to calling ycbcr_to_rgb" do
      y = 0
      while y < 256
        cb = 0
        while cb < 256
          cr = 0
          while cr < 256
            x = YCbCr.new(y.to_u8, cb.to_u8, cr.to_u8)
            r0, g0, b0, _ = x.rgba
            r1, g1, b1 = (r0 >> 8).to_u8, (g0 >> 8).to_u8, (b0 >> 8).to_u8
            r2, g2, b2 = ycbcr_to_rgb(x.y, x.cb, x.cr)
            unless r1 == r2 && g1 == g2 && b1 == b2
              fail "y,  cb, cr = #{y}, #{cb}, #{cr}\nr1, g1, b1 = #{r1}, #{g1}, #{b1}\nr2, g2, b2 = #{r2}, #{g2}, #{b2}"
            end
            cr += 3
          end
          cb += 5
        end
        y += 7
      end
    end

    it "Test that YCbCr colors are a superset of Gray colors" do
      0.upto(255) do |i|
        c0 = YCbCr.new(i, 0x80, 0x80)
        c1 = Gray.new(i.to_u8)
        unless eq(c0, c1)
          fail "#{c0} != #{c1}"
        end
      end
    end

    it "Test that NYCbCrA colors are a superset of Alpha colors" do
      0.upto(255) do |i|
        c0 = NYCbCrA.new(0xff, 0x80, 0x80, i)
        c1 = Alpha.new(i)
        unless eq(c0, c1)
          fail "#{c0} != #{c1}"
        end
      end
    end

    it "Test that NYCbCrA colors are a superset of YCbCr colors" do
      0.upto(255) do |i|
        c0 = NYCbCrA.new(i, 0x40, 0xc0, 0xff)
        c1 = YCbCr.new(i, 0x40, 0xc0)
        unless eq(c0, c1)
          fail "#{c0} != #{c1}"
        end
      end
    end

    it "Test that a subset of RGB space can be converted to CMYK and back to within 1/256 tolerance" do
      r = 0
      while r < 256
        g = 0
        while g < 256
          b = 0
          while b < 256
            r0, g0, b0 = r.to_u8, g.to_u8, b.to_u8
            c, m, y, k = rgb_to_cmyk(r0, g0, b0)
            r1, g1, b1 = cmyk_to_rgb(c, m, y, k)
            if delta(r0, r1) > 1 || delta(g0, g1) > 1 || delta(b0, b1) > 1
              fail "r0, g0, b0 = #{r0}, #{g0}, #{b0}\nc,  m, y, k = #{c}, #{m}, #{y}, #{k}\nr1, g1, b1 = #{r1}, #{g1}, #{b1}"
            end
            b += 3
          end
          g += 5
        end
        r += 7
      end
    end

    it "Test that calling the RGBA method (16 bit color) then truncating to 8 bits is equivalent to calling the cmyk_to_rgb" do
      c = 0
      while c < 256
        m = 0
        while m < 256
          y = 0
          while y < 256
            k = 0
            while k < 256
              x = CMYK.new(c, m, y, k)
              r0, g0, b0, _ = x.rgba
              r1, g1, b1 = (r0 >> 8).to_u8!, (g0 >> 8).to_u8!, (b0 >> 8).to_u8!
              r2, g2, b2 = cmyk_to_rgb(x.c, x.m, x.y, x.k)
              unless r1 == r2 && g1 == g2 && b1 == b2
                fail "c,  m, y, k = #{c}, #{m}, #{y}, #{k}\nr1, g1, b1 = #{r1}, #{g1}, #{b1}\nr2, g2, b2 = #{r2}, #{g2}, #{b2}"
              end
              k += 11
            end
            y += 3
          end
          m += 5
        end
        c += 7
      end
    end

    it "Test that CMYK colors are a superset of Gray colors" do
      0.upto(255) do |i|
        c0 = CMYK.new(0x00, 0x00, 0x00, 255 - i)
        c1 = Gray.new(i)
        unless eq(c0, c1)
          fail "#{c0} != #{c1}"
        end
      end
    end

    it "Test Palette" do
      palette = Palette.new([
        RGBA.new(0xff, 0xff, 0xff, 0xff).as(Color),
        RGBA.new(0x80, 0x00, 0x00, 0xff).as(Color),
        RGBA.new(0x7f, 0x00, 0x00, 0x7f).as(Color),
        RGBA.new(0x00, 0x00, 0x00, 0x7f).as(Color),
        RGBA.new(0x00, 0x00, 0x00, 0x00).as(Color),
        RGBA.new(0x40, 0x40, 0x40, 0x40).as(Color),
      ])

      # check that, for a Palette with no repeated colors, the closest color to each element is itself.
      palette.each_with_index do |c, i|
        j = palette.index(c)
        fail "index(#{c}): got #{j} (color = #{palette[j]}), want #{i}" unless i == j
      end

      # check that finding the closest color considers alpha, not just red, green and blue.
      got = palette.convert(RGBA.new(0x80, 0x00, 0x00, 0x80))
      want = RGBA.new(0x7f, 0x00, 0x00, 0x7f)
      got.should eq(want)
    end
  end
end
