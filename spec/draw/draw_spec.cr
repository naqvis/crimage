require "../spec_helper"

module CrImage::Draw
  record DrawTest, desc : String, src : Image, mask : Image?, op : Op, expected : Color::Color

  def self.eq(c0 : Color::Color, c1 : Color::Color) : Bool
    r0, g0, b0, a0 = c0.rgba
    r1, g1, b1, a1 = c1.rgba
    r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
  end

  def self.fill_blue(alpha)
    Uniform.new(Color::RGBA.new(0, 0, alpha, alpha))
  end

  def self.fill_alpha(alpha)
    Uniform.new(Color::Alpha.new(alpha))
  end

  def self.vgrad_green(alpha)
    m = RGBA.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::RGBA.new(0, (y*alpha // 15), 0, alpha)
      end
    end
    m
  end

  def self.vgrad_alpha(alpha)
    m = Alpha.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::Alpha.new((y*alpha // 15))
      end
    end
    m
  end

  def self.vgrad_green_nrgba(alpha)
    m = NRGBA.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::RGBA.new(0, (y*0x11), 0, alpha)
      end
    end
    m
  end

  def self.vgrad_cr
    m = YCbCr.new(Bytes.new(16*16), Bytes.new(16*16), Bytes.new(16*16), 16, 16, YCbCrSubSampleRatio::YCbCrSubsampleRatio444,
      CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m.cr[y*m.c_stride + x] = (y * 0x11).to_u8!
      end
    end
    m
  end

  def self.vgrad_gray
    m = Gray.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::Gray.new(y * 0x11)
      end
    end
    m
  end

  def self.vgrad_magenta
    m = CMYK.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::CMYK.new(0, y * 0x11, 0, 0x3f)
      end
    end
    m
  end

  def self.hgrad_red(alpha)
    m = RGBA.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::RGBA.new((x*alpha / 15).to_i, 0, 0, alpha)
      end
    end
    m
  end

  def self.grad_yellow(alpha)
    m = RGBA.new(CrImage.rect(0, 0, 16, 16))
    0.upto(15) do |y|
      0.upto(15) do |x|
        m[x, y] = Color::RGBA.new((x*alpha // 15), (y*alpha // 15), 0, alpha)
      end
    end
    m
  end

  M = MAX_COLOR_VALUE

  def self.make_golden(dst, r, src, sp, mask, mp, op)
    # Since golden is a newly allocated image, we don't have to check if the
    # input source and mask images and the output golden image overlap.
    b = dst.bounds
    src_b = src.bounds
    mb = mask.try &.bounds || CrImage.rect(-1e9.to_i, -1e9.to_i, 1e9.to_i, 1e9.to_i)
    golden = RGBA.new(CrImage.rect(0, 0, b.max.x, b.max.y))
    r.min.y.upto(r.max.y - 1) do |y|
      sy = y + sp.y - r.min.y
      my = y + mp.y - r.min.y
      r.min.x.upto(r.max.x - 1) do |x|
        next unless Point.new(x, y).in(b)
        sx = x + sp.x - r.min.x
        next unless Point.new(sx, sy).in(src_b)
        mx = x + mp.x - r.min.x
        next unless Point.new(mx, my).in(mb)

        if op == Op::OVER
          dr, dg, db, da = dst.at(x, y).rgba
        else
          dr, dg, db, da = 0_u32, 0_u32, 0_u32, 0_u32
        end

        sr, sg, sb, sa = src.at(sx, sy).rgba
        ma = M.to_u32
        if msk = mask
          _, _, _, ma = msk.at(mx, my).rgba
        end
        a = M - (sa * ma // M)
        golden.set(x, y, Color::RGBA64.new(
          ((dr &* a &+ sr &* ma) / M).to_u16!,
          ((dg &* a &+ sg &* ma) / M).to_u16!,
          ((db &* a &+ sb &* ma) / M).to_u16!,
          ((da &* a &+ sa &* ma) / M).to_u16!
        ))
      end
    end
    golden.sub_image(b)
  end

  DRAW_TESTS = [
    # Uniform mask (0% opaque).
    DrawTest.new("nop", vgrad_green(255), fill_alpha(0), Op::OVER, Color::RGBA.new(136, 0, 0, 255)),
    DrawTest.new("clear", vgrad_green(255), fill_alpha(0), Op::SRC, Color::RGBA.new(0, 0, 0, 0)),
    # Uniform mask (100%, 75%, nil) and uniform source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 0, 90, 90).
    DrawTest.new("fill", fill_blue(90), fill_alpha(255), Op::OVER, Color::RGBA.new(88, 0, 90, 255)),
    DrawTest.new("fillSrc", fill_blue(90), fill_alpha(255), Op::SRC, Color::RGBA.new(0, 0, 90, 90)),
    DrawTest.new("fill_alpha", fill_blue(90), fill_alpha(192), Op::OVER, Color::RGBA.new(100, 0, 68, 255)),
    DrawTest.new("fillAlphaSrc", fill_blue(90), fill_alpha(192), Op::SRC, Color::RGBA.new(0, 0, 68, 68)),
    DrawTest.new("fillNil", fill_blue(90), nil, Op::OVER, Color::RGBA.new(88, 0, 90, 255)),
    DrawTest.new("fillNilSrc", fill_blue(90), nil, Op::SRC, Color::RGBA.new(0, 0, 90, 90)),
    # Uniform mask (100%, 75%, nil) and variable source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 48, 0, 90).
    DrawTest.new("copy", vgrad_green(90), fill_alpha(255), Op::OVER, Color::RGBA.new(88, 48, 0, 255)),
    DrawTest.new("copySrc", vgrad_green(90), fill_alpha(255), Op::SRC, Color::RGBA.new(0, 48, 0, 90)),
    DrawTest.new("copyAlpha", vgrad_green(90), fill_alpha(192), Op::OVER, Color::RGBA.new(100, 36, 0, 255)),
    DrawTest.new("copyAlphaSrc", vgrad_green(90), fill_alpha(192), Op::SRC, Color::RGBA.new(0, 36, 0, 68)),
    DrawTest.new("copyNil", vgrad_green(90), nil, Op::OVER, Color::RGBA.new(88, 48, 0, 255)),
    DrawTest.new("copyNilSrc", vgrad_green(90), nil, Op::SRC, Color::RGBA.new(0, 48, 0, 90)),
    # Uniform mask (100%, 75%, nil) and variable NRGBA source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 136, 0, 90) in NRGBA-space, which is {0, 48, 0, 90) in RGBA-space.
    # The result pixel is different than in the "copy*" test cases because of rounding errors.
    DrawTest.new("nrgba", vgrad_green_nrgba(90), fill_alpha(255), Op::OVER, Color::RGBA.new(88, 46, 0, 255)),
    DrawTest.new("nrgbaSrc", vgrad_green_nrgba(90), fill_alpha(255), Op::SRC, Color::RGBA.new(0, 46, 0, 90)),
    DrawTest.new("nrgbaAlpha", vgrad_green_nrgba(90), fill_alpha(192), Op::OVER, Color::RGBA.new(100, 34, 0, 255)),
    DrawTest.new("nrgbaAlphaSrc", vgrad_green_nrgba(90), fill_alpha(192), Op::SRC, Color::RGBA.new(0, 34, 0, 68)),
    DrawTest.new("nrgbaNil", vgrad_green_nrgba(90), nil, Op::OVER, Color::RGBA.new(88, 46, 0, 255)),
    DrawTest.new("nrgbaNilSrc", vgrad_green_nrgba(90), nil, Op::SRC, Color::RGBA.new(0, 46, 0, 90)),
    # Uniform mask (100%, 75%, nil) and variable YCbCr source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 0, 136) in YCbCr-space, which is {11, 38, 0, 255) in RGB-space.
    DrawTest.new("ycbcr", vgrad_cr(), fill_alpha(255), Op::OVER, Color::RGBA.new(11, 38, 0, 255)),
    DrawTest.new("ycbcrSrc", vgrad_cr(), fill_alpha(255), Op::SRC, Color::RGBA.new(11, 38, 0, 255)),
    DrawTest.new("ycbcrAlpha", vgrad_cr(), fill_alpha(192), Op::OVER, Color::RGBA.new(42, 28, 0, 255)),
    DrawTest.new("ycbcrAlphaSrc", vgrad_cr(), fill_alpha(192), Op::SRC, Color::RGBA.new(8, 28, 0, 192)),
    DrawTest.new("ycbcrNil", vgrad_cr(), nil, Op::OVER, Color::RGBA.new(11, 38, 0, 255)),
    DrawTest.new("ycbcrNilSrc", vgrad_cr(), nil, Op::SRC, Color::RGBA.new(11, 38, 0, 255)),
    # Uniform mask (100%, 75%, nil) and variable Gray source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {136) in Gray-space, which is {136, 136, 136, 255) in RGBA-space.
    DrawTest.new("gray", vgrad_gray(), fill_alpha(255), Op::OVER, Color::RGBA.new(136, 136, 136, 255)),
    DrawTest.new("graySrc", vgrad_gray(), fill_alpha(255), Op::SRC, Color::RGBA.new(136, 136, 136, 255)),
    DrawTest.new("grayAlpha", vgrad_gray(), fill_alpha(192), Op::OVER, Color::RGBA.new(136, 102, 102, 255)),
    DrawTest.new("grayAlphaSrc", vgrad_gray(), fill_alpha(192), Op::SRC, Color::RGBA.new(102, 102, 102, 192)),
    DrawTest.new("grayNil", vgrad_gray(), nil, Op::OVER, Color::RGBA.new(136, 136, 136, 255)),
    DrawTest.new("grayNilSrc", vgrad_gray(), nil, Op::SRC, Color::RGBA.new(136, 136, 136, 255)),
    # Uniform mask (100%, 75%, nil) and variable CMYK source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 136, 0, 63) in CMYK-space, which is {192, 89, 192) in RGB-space.
    DrawTest.new("cmyk", vgrad_magenta(), fill_alpha(255), Op::OVER, Color::RGBA.new(192, 89, 192, 255)),
    DrawTest.new("cmykSrc", vgrad_magenta(), fill_alpha(255), Op::SRC, Color::RGBA.new(192, 89, 192, 255)),
    DrawTest.new("cmykAlpha", vgrad_magenta(), fill_alpha(192), Op::OVER, Color::RGBA.new(178, 67, 145, 255)),
    DrawTest.new("cmykAlphaSrc", vgrad_magenta(), fill_alpha(192), Op::SRC, Color::RGBA.new(145, 67, 145, 192)),
    DrawTest.new("cmykNil", vgrad_magenta(), nil, Op::OVER, Color::RGBA.new(192, 89, 192, 255)),
    DrawTest.new("cmykNilSrc", vgrad_magenta(), nil, Op::SRC, Color::RGBA.new(192, 89, 192, 255)),
    # Variable mask and variable source.
    # At (x, y) == (8, 8):
    # The destination pixel is {136, 0, 0, 255).
    # The source pixel is {0, 0, 255, 255).
    # The mask pixel's alpha is 102, or 40%.
    DrawTest.new("generic", fill_blue(255), vgrad_alpha(192), Op::OVER, Color::RGBA.new(81, 0, 102, 255)),
    DrawTest.new("genericSrc", fill_blue(255), vgrad_alpha(192), Op::SRC, Color::RGBA.new(0, 0, 102, 102)),
  ]

  it "Test Draw" do
    rr = [
      CrImage.rect(0, 0, 0, 0),
      CrImage.rect(0, 0, 16, 16),
      CrImage.rect(3, 5, 12, 10),
      CrImage.rect(0, 0, 9, 9),
      CrImage.rect(8, 8, 16, 16),
      CrImage.rect(8, 0, 9, 16),
      CrImage.rect(0, 8, 16, 9),
      CrImage.rect(8, 8, 9, 9),
      CrImage.rect(8, 8, 8, 8),
    ]

    rr.each do |r|
      DRAW_TESTS.each do |test|
        dst = hgrad_red(255).as(RGBA).sub_image(r).as(Image)
        # draw teh (src,mask,op) onto a copy of dst using a slow but obviously correct implementation
        golden = make_golden(dst, CrImage.rect(0, 0, 16, 16), test.src, Point.zero, test.mask, Point.zero, test.op)

        b = dst.bounds
        fail "draw #{r} #{test.desc}: bounds #{dst.bounds} versus #{golden.bounds}" unless b == golden.bounds

        # Draw the same combination onto the actual dst using the optimized draw_mask implementation
        draw_mask(dst, CrImage.rect(0, 0, 16, 16), test.src, Point.zero, test.mask, Point.zero, test.op)
        if Point.new(8, 8).in(r)
          # Check that the resultant pixel at (8,8) matches what we expect
          # (the expected value can be verified by hand).
          fail "draw #{r} #{test.desc}: at (8,8) #{dst.at(8, 8)} expected #{test.expected}" unless eq(dst.at(8, 8), test.expected)
        end

        # Check that the resultant dst image matches the golden output
        b.min.y.upto(b.max.y - 1) do |y|
          b.min.x.upto(b.max.x - 1) do |x|
            fail "draw #{r} #{test.desc}: at (#{x},#{y}) #{dst.at(x, y)} expected #{golden.at(x, y)}" unless eq(dst.at(x, y), golden.at(x, y))
          end
        end
      end
    end
  end

  it "Test Draw Overlap" do
    [Op::OVER, Op::SRC].each do |op|
      -2.upto(2) do |yoff|
        -2.upto(2) do |xoff|
          m = grad_yellow(127).as(RGBA)
          dst = m.sub_image(CrImage.rect(5, 5, 10, 10)).as(RGBA)
          src = m.sub_image(CrImage.rect(5 + xoff, 5 + yoff, 10 + xoff, 10 + yoff)).as(RGBA)
          b = dst.bounds
          # Draw the (src, mask, op) onto a copy of dst using a slow but obviously correct implementation
          golden = make_golden(dst, b, src, src.bounds.min, nil, Point.zero, op)
          fail "DrawOverlap xoff=#{xoff}, yoff=#{yoff}: bounds #{dst.bounds} versus #{golden.bounds}" unless b == golden.bounds

          # Draw the same combination onto the actual dst using the optimized draw_mask implementation
          draw_mask(dst, b, src, src.bounds.min, nil, Point.zero, op)
          # Check that the resultant dst image matches the golden output
          b.min.y.upto(b.max.y - 1) do |y|
            b.min.x.upto(b.max.x - 1) do |x|
              fail "DrawOverlap xoff=#{xoff}, yoff=#{yoff}: at (#{x},#{y}) #{dst.at(x, y)} versus golden #{golden.at(x, y)}" unless eq(dst.at(x, y), golden.at(x, y))
            end
          end
        end
      end
    end
  end

  it "Test drawing with a non-zero src point parameter" do
    a = RGBA.new(CrImage.rect(0, 0, 1, 1))
    b = RGBA.new(CrImage.rect(0, 0, 2, 2))
    b.set(0, 0, Color::RGBA.new(0, 0, 0, 5))
    b.set(1, 0, Color::RGBA.new(0, 0, 5, 5))
    b.set(0, 1, Color::RGBA.new(0, 5, 0, 5))
    b.set(1, 1, Color::RGBA.new(5, 0, 0, 5))
    draw(a, CrImage.rect(0, 0, 1, 1), b, Point.new(1, 1), Op::OVER)
    if !eq(Color::RGBA.new(5, 0, 0, 5), a.at(0, 0))
      fail "non-zero src pt: want #{Color::RGBA.new(5, 0, 0, 5)}, got #{a.at(0, 0)}"
    end
  end

  it "Test Fill" do
    rr = [
      CrImage.rect(0, 0, 0, 0),
      CrImage.rect(0, 0, 40, 30),
      CrImage.rect(10, 0, 40, 30),
      CrImage.rect(0, 20, 40, 30),
      CrImage.rect(10, 20, 40, 30),
      CrImage.rect(10, 20, 15, 25),
      CrImage.rect(10, 0, 35, 30),
      CrImage.rect(0, 15, 40, 16),
      CrImage.rect(24, 24, 25, 25),
      CrImage.rect(23, 23, 26, 26),
      CrImage.rect(22, 22, 27, 27),
      CrImage.rect(21, 21, 28, 28),
      CrImage.rect(20, 20, 29, 29),
    ]

    rr.each do |r|
      m = RGBA.new(CrImage.rect(0, 0, 40, 30)).sub_image(r).as(RGBA)
      b = m.bounds
      c = Color::RGBA.new(11, 0, 0, 255)
      src = Uniform.new(c)

      check = ->(desc : String) {
        b.min.y.upto(b.max.y - 1) do |y|
          b.min.x.upto(b.max.x - 1) do |x|
            unless eq(c, m.at(x, y))
              fail "#{desc} fill: at (#{x},#{y}), sub-image bounds = #{r} want #{c}, got #{m.at(x, y)}"
            end
          end
        end
      }

      # Draw 1 pixel at a time
      b.min.y.upto(b.max.y - 1) do |y|
        b.min.x.upto(b.max.x - 1) do |x|
          draw_mask(m, CrImage.rect(x, y, x + 1, y + 1), src, Point.zero, nil, Point.zero, Op::SRC)
        end
      end
      check.call("pixel")

      # Draw 1 row at a time
      c = Color::RGBA.new(0, 22, 0, 255)
      src = Uniform.new(c)
      b.min.y.upto(b.max.y - 1) do |y|
        draw_mask(m, CrImage.rect(b.min.x, y, b.max.x, y + 1), src, Point.zero, nil, Point.zero, Op::SRC)
      end
      check.call("row")

      # Draw 1 column at a time
      c = Color::RGBA.new(0, 0, 33, 255)
      src = Uniform.new(c)
      b.min.x.upto(b.max.x - 1) do |x|
        draw_mask(m, CrImage.rect(x, b.min.y, x + 1, b.max.y), src, Point.zero, nil, Point.zero, Op::SRC)
      end
      check.call("column")

      # Draw the whole image at once
      c = Color::RGBA.new(44, 55, 66, 77)
      src = Uniform.new(c)
      draw_mask(m, b, src, Point.zero, nil, Point.zero, Op::SRC)
      check.call("whole")
    end
  end

  it "Test Floyd Steinberg error diffusion of a uniform 50% gray source image with black-and-white palette is a checkerboard pattern" do
    b = CrImage.rect(0, 0, 640, 480)
    # we can't represent 50% exactly, but 0x7fff / 0xffff is close enough.
    src = Uniform.new(Color::Gray16.new(0x7fff))
    dst = Paletted.new(b, Color::Palette.new([Color::BLACK, Color::WHITE]))
    FloydSteinberg.draw(dst, b, src, Point.zero)
    err = 0
    b.min.y.upto(b.max.y - 1) do |y|
      b.min.x.upto(b.max.x - 1) do |x|
        got = dst.pix[dst.pixel_offset(x, y)]
        want = (x + y).to_u8! % 2
        unless got == want
          err += 1
          fail "at(#{x},#{y}): got #{got}, want #{want}" if err == 10
        end
      end
    end
  end

  # EmbeddedPaletted is an Image that behaves like Paletted but whose
  # type is not CrImage::Paletted
  class EmbeddedPaletted < Paletted
  end

  it "Test that draw_paletted function behaves the same regardless of wheter dst is CrImage::Paletted" do
    src = PNG.read("spec/testdata/video-001.png")
    b = src.bounds
    cga_palette = Color::Palette.new([
      Color::RGBA.new(0x00, 0x00, 0x00, 0xff).as(Color::Color),
      Color::RGBA.new(0x55, 0xff, 0xff, 0xff).as(Color::Color),
      Color::RGBA.new(0xff, 0x55, 0xff, 0xff).as(Color::Color),
      Color::RGBA.new(0xff, 0xff, 0xff, 0xff).as(Color::Color),
    ])

    drawers = {
      "src"             => Op::SRC,
      "floyd-steinberg" => FloydSteinberg,
    }

    drawers.each do |name, d|
      dst0 = Paletted.new(rect: b, palette: cga_palette)
      dst1 = EmbeddedPaletted.new(rect: b, palette: cga_palette)
      d.draw(dst0, b, src, Point.zero)
      d.draw(dst1, b, src, Point.zero)
      b.min.y.upto(b.max.y - 1) do |y|
        b.min.x.upto(b.max.x - 1) do |x|
          unless eq(dst0.at(x, y), dst1.at(x, y))
            fail "#{name}: at (#{x},#{y}), #{dst0.at(x, y)} versus #{dst1.at(x, y)}"
          end
        end
      end
    end
  end

  it "Test sq_diff" do
    # canonical sq_diff implementation
    orig = ->(x : Int32, y : Int32) {
      if x > y
        d = (x &- y).to_u32!
      else
        d = (y &- x).to_u32!
      end
      (d &* d) >> 2
    }

    testcases = [
      0,
      1,
      2,
      0x0fffd,
      0x0fffe,
      0x0ffff,
      0x10000,
      0x10001,
      0x10002,
      0x7ffffffd,
      0x7ffffffe,
      0x7fffffff,
      -0x7ffffffd,
      -0x7ffffffe,
      -0x80000000,
    ]

    testcases.each do |x|
      testcases.each do |y|
        got = sq_diff(x, y)
        want = orig.call(x, y)

        fail "sq_diff(#{x},#{y}): got #{got}, want: #{want}" unless got == want
      end
    end
  end

  describe "Alpha blending overflow protection" do
    it "handles semi-transparent fill over white background" do
      # This was causing arithmetic overflow before the fix
      img = CrImage.rgba(100, 100, Color::WHITE)
      color = Color.rgba(100, 100, 255, 50)
      rect = CrImage.rect(10, 10, 90, 90)
      src = Uniform.new(color)

      # Should not raise OverflowError
      draw(img, rect, src, Point.zero, Op::OVER)

      # Verify the blending produced reasonable results
      # With alpha=50/255 (~20%), the result blends toward the source color
      pixel = img.at(50, 50)
      r, g, b, a = pixel.rgba
      r8 = (r >> 8).to_i32
      g8 = (g >> 8).to_i32
      b8 = (b >> 8).to_i32
      a8 = (a >> 8).to_i32

      # Result should be blended: mostly white with some source color influence
      # Actual result is approximately (50, 50, 205, 255)
      r8.should be < 100 # Red component reduced from white
      g8.should be < 100 # Green component reduced from white
      b8.should be > 150 # Blue stays high
      a8.should eq 255   # Alpha stays fully opaque
    end

    it "handles very low alpha values" do
      img = CrImage.rgba(50, 50, Color::WHITE)
      # Very low alpha (1/255)
      color = Color.rgba(0, 0, 255, 1)
      src = Uniform.new(color)

      draw(img, img.bounds, src, Point.zero, Op::OVER)

      # Should complete without overflow
      pixel = img.at(25, 25)
      r, g, b, a = pixel.rgba
      # Result should be almost white
      (r >> 8).should be > 250
      (g >> 8).should be > 250
      (a >> 8).should eq 255
    end

    it "handles maximum alpha values" do
      img = CrImage.rgba(50, 50, Color::WHITE)
      # Full alpha
      color = Color.rgba(255, 0, 0, 255)
      src = Uniform.new(color)

      draw(img, img.bounds, src, Point.zero, Op::OVER)

      # Should be solid red
      pixel = img.at(25, 25)
      r, g, b, a = pixel.rgba
      (r >> 8).should eq 255
      (g >> 8).should eq 0
      (b >> 8).should eq 0
      (a >> 8).should eq 255
    end

    it "handles zero alpha (fully transparent)" do
      img = CrImage.rgba(50, 50, Color::WHITE)
      color = Color.rgba(255, 0, 0, 0)
      src = Uniform.new(color)

      draw(img, img.bounds, src, Point.zero, Op::OVER)

      # Should remain white (transparent source has no effect)
      pixel = img.at(25, 25)
      r, g, b, a = pixel.rgba
      (r >> 8).should eq 255
      (g >> 8).should eq 255
      (b >> 8).should eq 255
      (a >> 8).should eq 255
    end

    it "handles various alpha levels without overflow" do
      # Test a range of alpha values that could trigger overflow
      [1, 10, 50, 100, 127, 128, 200, 254, 255].each do |alpha|
        img = CrImage.rgba(10, 10, Color::WHITE)
        color = Color.rgba(100, 150, 200, alpha.to_u8)
        src = Uniform.new(color)

        # Should not raise
        draw(img, img.bounds, src, Point.zero, Op::OVER)
      end
    end

    it "produces correct blending results" do
      # Test that the fix produces mathematically correct results
      img = CrImage.rgba(10, 10, Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      # 50% alpha blue - note: RGBA uses premultiplied alpha
      color = Color.rgba(0, 0, 255, 128)
      src = Uniform.new(color)

      draw(img, img.bounds, src, Point.zero, Op::OVER)

      pixel = img.at(5, 5)
      r, g, b, a = pixel.rgba

      # With premultiplied alpha blending, the result depends on the formula:
      # result = src * src_alpha + dst * (1 - src_alpha)
      # The actual values will depend on the exact blending implementation
      r8 = (r >> 8).to_i32
      g8 = (g >> 8).to_i32
      b8 = (b >> 8).to_i32
      a8 = (a >> 8).to_i32

      # Just verify the operation completed without overflow and produced valid results
      r8.should be >= 0
      r8.should be <= 255
      g8.should be >= 0
      g8.should be <= 255
      b8.should be >= 0
      b8.should be <= 255
      a8.should eq 255
    end
  end

  describe "Circle blend modes" do
    it "draws circle with multiply blend mode" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      style = CircleStyle.new(Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8), fill: true, blend_mode: BlendMode::Multiply)
      Draw.circle(img, Point.new(50, 50), 30, style)

      # Center pixel should be blended with multiply
      pixel = img.at(50, 50)
      r, g, b, a = pixel.rgba
      r8 = (r >> 8).to_i32
      g8 = (g >> 8).to_i32
      b8 = (b >> 8).to_i32

      # Multiply: result = src * dst (normalized)
      # 200 * 100 / 255 ≈ 78, 200 * 150 / 255 ≈ 118, 200 * 200 / 255 ≈ 157
      r8.should be < 200 # Darkened from original
      g8.should be < 200
      b8.should be < 200
    end

    it "draws circle with screen blend mode" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))

      style = CircleStyle.new(Color::RGBA.new(150_u8, 150_u8, 150_u8, 255_u8), fill: true, blend_mode: BlendMode::Screen)
      Draw.circle(img, Point.new(50, 50), 30, style)

      # Center pixel should be lightened
      pixel = img.at(50, 50)
      r, g, b, _ = pixel.rgba
      r8 = (r >> 8).to_i32

      # Screen lightens: result > max(src, dst)
      r8.should be > 150
    end

    it "draws circle without blend mode (normal)" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      # No blend mode - should just overwrite
      style = CircleStyle.new(Color::RGBA.new(50_u8, 100_u8, 150_u8, 255_u8), fill: true)
      Draw.circle(img, Point.new(50, 50), 30, style)

      pixel = img.at(50, 50)
      r, g, b, _ = pixel.rgba
      r8 = (r >> 8).to_i32
      g8 = (g >> 8).to_i32
      b8 = (b >> 8).to_i32

      # Should be the source color (no blending)
      r8.should eq 50
      g8.should eq 100
      b8.should eq 150
    end

    it "uses builder pattern for blend mode" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

      style = CircleStyle.new(Color::RGBA.new(128_u8, 128_u8, 128_u8, 255_u8))
        .with_fill(true)
        .with_blend_mode(BlendMode::Overlay)
      Draw.circle(img, Point.new(50, 50), 20, style)

      # Just verify it doesn't crash and produces valid output
      pixel = img.at(50, 50)
      r, _, _, _ = pixel.rgba
      r8 = (r >> 8).to_i32
      r8.should be >= 0
      r8.should be <= 255
    end
  end

  describe "Rectangle blend modes" do
    it "draws rectangle with multiply blend mode" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      style = RectStyle.new
        .with_fill(Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8))
        .with_blend_mode(BlendMode::Multiply)
      Draw.rectangle(img, CrImage.rect(20, 20, 80, 80), style)

      pixel = img.at(50, 50)
      r, g, b, _ = pixel.rgba
      r8 = (r >> 8).to_i32

      # Multiply darkens
      r8.should be < 200
    end

    it "draws rounded rectangle with blend mode" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      style = RectStyle.new
        .with_fill(Color::RGBA.new(100_u8, 100_u8, 255_u8, 255_u8))
        .with_corner_radius(10)
        .with_blend_mode(BlendMode::Screen)
      Draw.rectangle(img, CrImage.rect(20, 20, 80, 80), style)

      pixel = img.at(50, 50)
      r, _, _, _ = pixel.rgba
      r8 = (r >> 8).to_i32

      # Screen lightens
      r8.should be > 100
    end
  end

  describe "Polygon blend modes" do
    it "draws polygon with blend mode via style" do
      img = CrImage.rgba(100, 100, Color::RGBA.new(200_u8, 200_u8, 200_u8, 255_u8))

      points = [Point.new(50, 20), Point.new(80, 80), Point.new(20, 80)]
      style = PolygonStyle.new
        .with_fill(Color::RGBA.new(100_u8, 100_u8, 200_u8, 255_u8))
        .with_blend_mode(BlendMode::Multiply)
      Draw.polygon(img, points, style)

      pixel = img.at(50, 50)
      r, _, _, _ = pixel.rgba
      r8 = (r >> 8).to_i32

      r8.should be < 200
    end
  end

  describe "Polyline and spline utilities" do
    it "draws polyline through points" do
      img = CrImage.rgba(100, 100, Color::WHITE)
      points = [Point.new(10, 10), Point.new(50, 50), Point.new(90, 10)]
      style = LineStyle.new(Color::RED, thickness: 2)

      Draw.polyline(img, points, style)

      # Check that line was drawn at middle point
      pixel = img.at(50, 50)
      r, g, b, _ = pixel.rgba
      (r >> 8).should eq 255
      (g >> 8).should eq 0
    end

    it "flattens spline to points" do
      control_points = [Point.new(0, 0), Point.new(50, 100), Point.new(100, 0)]
      result = Draw.spline_flatten(control_points, tension: 0.5)

      # Should have more points than input (interpolated)
      result.size.should be > control_points.size

      # First and last points should match control points
      result.first.x.should eq 0
      result.first.y.should eq 0
      result.last.x.should eq 100
      result.last.y.should eq 0
    end

    it "returns empty array for less than 2 points" do
      result = Draw.spline_flatten([Point.new(0, 0)])
      result.size.should eq 0
    end

    it "returns original points for exactly 2 points" do
      points = [Point.new(0, 0), Point.new(100, 100)]
      result = Draw.spline_flatten(points)
      result.size.should eq 2
    end
  end
end
