require "./color"

module CrImage::Color
  # YCbCr represents a fully opaque 24-bit Y'CbCr color, having 8 bits each for
  # one luma and two chroma components.
  #
  # JPEG, VP8, the MPEG family and other codecs use this color model. Such
  # codecs often use the terms YUV and Y'CbCr interchangeably, but strictly
  # speaking, the term YUV applies only to analog video signals, and Y' (luma)
  # is Y (luminance) after applying gamma correction.
  #
  # Conversion between RGB and Y'CbCr is lossy and there are multiple, slightly
  # different formulae for converting between the two. This package follows
  # the JFIF specification at https://www.w3.org/Graphics/JPEG/jfif3.pdf.
  struct YCbCr
    include Color

    property y : UInt8
    property cb : UInt8
    property cr : UInt8

    def initialize(@y, @cb, @cr)
    end

    def initialize(y, cb, cr)
      @y = y.to_u8
      @cb = cb.to_u8
      @cr = cr.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(@y, @cb, @cr)
      {r.to_u32, g.to_u32, b.to_u32, MAX_32BIT}
    end

    def_equals_and_hash @y, @cb, @cr
  end

  # NYCbCrA represents a non-alpha-premultiplied Y'CbCr-with-alpha color, having
  # 8 bits each for one luma, two chroma and one alpha component.
  struct NYCbCrA
    include Color

    property y : UInt8
    property cb : UInt8
    property cr : UInt8
    property a : UInt8

    def initialize(@y, @cb, @cr, @a)
    end

    def initialize(y, cb, cr, a)
      @y = y.to_u8
      @cb = cb.to_u8
      @cr = cr.to_u8
      @a = a.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(@y, @cb, @cr)
      a = @a.to_u32 * SCALE_8_TO_16

      r = r.to_u32 * a // MAX_32BIT
      g = g.to_u32 * a // MAX_32BIT
      b = b.to_u32 * a // MAX_32BIT
      {r.to_u32, g.to_u32, b.to_u32, a.to_u32}
    end

    def_equals_and_hash @y, @cb, @cr, @a
  end

  # CMYK represents a fully opaque CMYK color, having 8 bits for each of cyan,
  # magenta, yellow and black.
  #
  # It is not associated with any particular color profile.
  struct CMYK
    include Color

    property c : UInt8
    property m : UInt8
    property y : UInt8
    property k : UInt8

    def initialize(@c, @m, @y, @k)
    end

    def initialize(c, m, y, k)
      @c = c.to_u8
      @m = m.to_u8
      @y = y.to_u8
      @k = k.to_u8
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      w = MAX_32BIT - k.to_u32*SCALE_8_TO_16
      r = (MAX_32BIT - c.to_u32*SCALE_8_TO_16).to_u32 * w // MAX_32BIT
      g = (MAX_32BIT - m.to_u32*SCALE_8_TO_16).to_u32 * w // MAX_32BIT
      b = (0xffff - y.to_u32*0x101).to_u32 * w // 0xffff
      {r.to_u32, g.to_u32, b.to_u32, 0xffff_u32}
    end

    def_equals_and_hash @c, @m, @y, @k
  end

  private def self.ycbcr_model(c : Color) : Color
    return c if c.is_a?(YCbCr)
    r, g, b, _ = c.rgba
    y, u, v = rgb_to_ycbcr(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8)
    YCbCr.new(y, u, v).as(Color)
  end

  private def self.nycbcra_model(c : Color) : Color
    return c if c.is_a?(NYCbCrA)
    r, g, b, a = c.rgba
    # Convert from alpha-premultiplied to non-alpha-premultiplied.
    unless a == 0
      r = ((r * 0xffff) / a).to_i
      g = ((g * 0xffff) / a).to_i
      b = ((b * 0xffff) / a).to_i
    end
    y, u, v = rgb_to_ycbcr(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8)
    NYCbCrA.new(y, u, v, ((a >> 8) & 0xFF).to_u8).as(Color)
  end

  private def self.cmyk_model(c : Color) : Color
    return c if c.is_a?(CMYK)
    r, g, b, _ = c.rgba
    cc, mm, yy, kk = rgb_to_cmyk(((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8)
    CMYK.new(cc, mm, yy, kk).as(Color)
  end

  # converts an RGB triple to a Y'CbCr triple.
  def self.rgb_to_ycbcr(r : UInt8, g : UInt8, b : UInt8) : {UInt8, UInt8, UInt8}
    # The JFIF specification says:
    #	y' =  0.2990*r + 0.5870*g + 0.1140*b
    #	cb = -0.1687*r - 0.3313*g + 0.5000*b + 128
    #	cr =  0.5000*r - 0.4187*g - 0.0813*b + 128
    # https:#www.w3.org/Graphics/JPEG/jfif3.pdf says y but means y'.

    r1 = r.to_i32
    g1 = g.to_i32
    b1 = b.to_i32

    # yy is in range 0..0xff
    # Note that YCBCR_Y_R_COEFF + YCBCR_Y_G_COEFF + YCBCR_Y_B_COEFF equals 65536.
    yy = (YCBCR_Y_R_COEFF*r1 + YCBCR_Y_G_COEFF*g1 + YCBCR_Y_B_COEFF*b1 + (1 << 15)) >> 16

    # Note that YCBCR_CB_R_COEFF + YCBCR_CB_G_COEFF + YCBCR_CB_B_COEFF equals 0.
    cb = YCBCR_CB_R_COEFF*r1 + YCBCR_CB_G_COEFF*g1 + YCBCR_CB_B_COEFF*b1 + YCBCR_CHROMA_OFFSET
    if cb.to_u32! & 0xff000000 == 0
      cb >>= 16
    else
      cb = ~0 ^ (cb >> 31)
    end

    # Note that YCBCR_CR_R_COEFF + YCBCR_CR_G_COEFF + YCBCR_CR_B_COEFF equals 0.
    cr = YCBCR_CR_R_COEFF*r1 + YCBCR_CR_G_COEFF*g1 + YCBCR_CR_B_COEFF*b1 + YCBCR_CHROMA_OFFSET
    if cr.to_u32! & 0xff000000 == 0
      cr >>= 16
    else
      cr = ~0 ^ (cr >> 31)
    end

    {(yy & 0xFF).to_u8, (cb & 0xFF).to_u8, (cr & 0xFF).to_u8}
  end

  def self.ycbcr_to_rgb(y : UInt8, cb : UInt8, cr : UInt8) : {UInt8, UInt8, UInt8}
    # The JFIF specification says:
    #	R = Y' + 1.40200*(Cr-128)
    #	G = Y' - 0.34414*(Cb-128) - 0.71414*(Cr-128)
    #	B = Y' + 1.77200*(Cb-128)
    # https://www.w3.org/Graphics/JPEG/jfif3.pdf says Y but means Y'.
    #
    # Those formulae use non-integer multiplication factors. When computing,
    # integer math is generally faster than floating point math. We multiply
    # all of those factors by 1<<16 and round to the nearest integer:
    #	 91881 = roundToNearestInteger(1.40200 * 65536).
    #	 22554 = roundToNearestInteger(0.34414 * 65536).
    #	 46802 = roundToNearestInteger(0.71414 * 65536).
    #	116130 = roundToNearestInteger(1.77200 * 65536).
    #
    # Adding a rounding adjustment in the range [0, 1<<16-1] and then shifting
    # right by 16 gives us an integer math version of the original formulae.
    #	R = (65536*Y' +  91881 *(Cr-128)                  + adjustment) >> 16
    #	G = (65536*Y' -  22554 *(Cb-128) - 46802*(Cr-128) + adjustment) >> 16
    #	B = (65536*Y' + 116130 *(Cb-128)                  + adjustment) >> 16
    # A constant rounding adjustment of 1<<15, one half of 1<<16, would mean
    # round-to-nearest when dividing by 65536 (shifting right by 16).
    # Similarly, a constant rounding adjustment of 0 would mean round-down.
    #
    # Defining YY1 = 65536*Y' + adjustment simplifies the formulae and
    # requires fewer CPU operations:
    #	R = (YY1 +  91881 *(Cr-128)                 ) >> 16
    #	G = (YY1 -  22554 *(Cb-128) - 46802*(Cr-128)) >> 16
    #	B = (YY1 + 116130 *(Cb-128)                 ) >> 16
    #
    # The inputs (y, cb, cr) are 8 bit color, ranging in [0x00, 0xff]. In this
    # function, the output is also 8 bit color, but in the related YCbCr.RGBA
    # method, below, the output is 16 bit color, ranging in [0x0000, 0xffff].
    # Outputting 16 bit color simply requires changing the 16 to 8 in the "R =
    # etc >> 16" equation, and likewise for G and B.
    #
    # As mentioned above, a constant rounding adjustment of 1<<15 is a natural
    # choice, but there is an additional constraint: if c0 := YCbCr{Y: y, Cb:
    # 0x80, Cr: 0x80} and c1 := Gray{Y: y} then c0.RGBA() should equal
    # c1.RGBA(). Specifically, if y == 0 then "R = etc >> 8" should yield
    # 0x0000 and if y == 0xff then "R = etc >> 8" should yield 0xffff. If we
    # used a constant rounding adjustment of 1<<15, then it would yield 0x0080
    # and 0xff80 respectively.
    #
    # Note that when cb == 0x80 and cr == 0x80 then the formulae collapse to:
    #	R = YY1 >> n
    #	G = YY1 >> n
    #	B = YY1 >> n
    # where n is 16 for this function (8 bit color output) and 8 for the
    # YCbCr.RGBA method (16 bit color output).
    #
    # The solution is to make the rounding adjustment non-constant, and equal
    # to 257*Y', which ranges over [0, 1<<16-1] as Y' ranges over [0, 255].
    # YY1 is then defined as:
    #	YY1 = 65536*Y' + 257*Y'
    # or equivalently:
    #	YY1 = Y' * 0x10101

    r, g, b = CrImage::Color.ycbcr_to_rgb_16bit(y, cb, cr)
    {((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8}
  end

  # converts an RGB triple to a CMYK quadruple.
  def self.rgb_to_cmyk(r : UInt8, g : UInt8, b : UInt8) : {UInt8, UInt8, UInt8, UInt8}
    rr = r.to_u32
    gg = g.to_u32
    bb = b.to_u32
    w = rr
    w = gg if w < gg
    w = bb if w < bb
    return {0_u8, 0_u8, 0_u8, 0xff_u8} if w == 0
    c = (w - rr) * 0xff // w
    m = (w - gg) * 0xff // w
    y = (w - bb) * 0xff // w
    {c.to_u8, m.to_u8, y.to_u8, (0xff - w).to_u8}
  end

  # converts a CMYK quadruple to an RGB triple.
  def self.cmyk_to_rgb(c : UInt8, m : UInt8, y : UInt8, k : UInt8) : {UInt8, UInt8, UInt8}
    w = 0xffff - k.to_u32*0x101
    r = (0xffff - c.to_u32*0x101).to_u32 * w // 0xffff
    g = (0xffff - m.to_u32*0x101).to_u32 * w // 0xffff
    b = (0xffff - y.to_u32*0x101).to_u32 * w // 0xffff
    {((r >> 8) & 0xFF).to_u8, ((g >> 8) & 0xFF).to_u8, ((b >> 8) & 0xFF).to_u8}
  end

  # Helper method to convert YCbCr values to RGB components (16-bit)
  # Returns RGB values in 16-bit range (0-65535)
  # This is used internally for fast YCbCr to RGB conversion
  @[AlwaysInline]
  def self.ycbcr_to_rgb_16bit(y : UInt8, cb : UInt8, cr : UInt8) : {UInt32, UInt32, UInt32}
    yy1 = y.to_i32 * YCBCR_YY1_MULTIPLIER
    cb1 = cb.to_i32 - 128
    cr1 = cr.to_i32 - 128

    r = yy1 + RGB_FROM_CR_COEFF*cr1
    if r.to_u32! & 0xff000000 == 0
      r >>= 8
    else
      r = (~0 ^ (r >> 31)) & 0xffff
    end

    g = yy1 - RGB_FROM_CB_G_COEFF*cb1 - RGB_FROM_CR_G_COEFF*cr1
    if g.to_u32! & 0xff000000 == 0
      g >>= 8
    else
      g = (~0 ^ (g >> 31)) & 0xffff
    end

    b = yy1 + RGB_FROM_CB_COEFF*cb1
    if b.to_u32! & 0xff000000 == 0
      b >>= 8
    else
      b = (~0 ^ (b >> 31)) & 0xffff
    end

    {r.to_u32, g.to_u32, b.to_u32}
  end
end
