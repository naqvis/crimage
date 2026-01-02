require "../image"
require "../color"
require "./primitives"
require "./gradient"
require "./path"
require "./patterns"
require "./rounded_rect"
require "./arrows"
require "./markers"
require "./text_path"
require "./annotations"
require "./gradient_stroke"
require "./chart_helpers"

# CrImage::Draw provides image composition and drawing operations.
#
# Features:
# - Porter-Duff compositing operators (OVER, SRC)
# - Alpha blending and masking
# - Drawing primitives (lines, circles, ellipses, polygons)
# - Gradient fills (linear and radial)
# - Anti-aliasing support
#
# This module contains image composition functionality for drawing one image
# onto another with various compositing modes, including support for alpha
# blending and masks.
module CrImage::Draw
  # maximum color value returned by Color::RGBA
  private MAX_COLOR_VALUE = Color::MAX_32BIT

  # Color component scaling constants (aliases for readability in this context)
  private COLOR_SCALE_8_TO_16 = Color::SCALE_8_TO_16
  private COLOR_MAX_16        = Color::MAX_32BIT
  private COLOR_MAX_8         = Color::MAX_8BIT

  # Draws text on an image at the specified position.
  #
  # This is a convenience method that creates a Font::Drawer internally.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `text` : The text string to draw
  # - `position` : Position for the text baseline
  # - `face` : Font face to use
  # - `size` : Font size (used to scale if face was created at different size)
  # - `color` : Text color
  #
  # Example:
  # ```
  # font = FreeType::TrueType.load("font.ttf")
  # face = FreeType::TrueType.new_face(font, 24.0)
  # CrImage::Draw.text(img, "Hello!", CrImage.point(10, 50), face, CrImage::Color::BLACK)
  # ```
  def self.text(img : Image, text_str : String, position : Point, face : CrImage::Font::Face, color : Color::Color)
    src = Uniform.new(color)
    dot = CrImage::Math::Fixed::Point26_6.new(
      CrImage::Math::Fixed::Int26_6[position.x * 64],
      CrImage::Math::Fixed::Int26_6[position.y * 64]
    )
    drawer = CrImage::Font::Drawer.new(img, src, face, dot)
    drawer.draw(text_str)
  end

  # Quantizer prodcues a palette for an Image
  module Quantizer
    # quantize appends colors to p and returns the updated
    # palette suitable for converting m to a paletted image.
    abstract def quantize(p : Color::Palette, m : CrImage::Image) : Color::Palette
  end

  module Drawer
    # aligns r.min in dst with sp in src and then replaces the
    # rectangle r in dst with the result of drawing src on dst
    abstract def draw(dst : Image, r : Rectangle, src : Image, sp : Point)
  end

  # Porter-Duff compositing operator
  struct Op
    include Drawer
    # Over specifices (src in mask) over dst
    OVER = new(0)
    # Src specified src in mask
    SRC = new(1)

    getter op : Int32

    private def initialize(@op = OVER.op)
    end

    # draw implememts the Drawer by calling the draw function with this Op
    def draw(dst : Image, r : Rectangle, src : Image, sp : Point)
      Draw.draw_mask(dst, r, src, sp, nil, Point.zero, self)
    end

    def eq(other : Op)
      @op == other.op
    end

    def to_s
      op == 0 ? "Over" : "Src"
    end
  end

  FloydSteinberg = FloydSteinbergS.new

  private struct FloydSteinbergS
    include Drawer

    def draw(dst : Image, r : Rectangle, src : Image, sp : Point)
      r, sp, _ = Draw.clip(dst, r, src, sp, nil, nil)
      return if r.empty
      Draw.draw_paletted(dst, r, src, sp, true)
    end
  end

  # Draws a source image onto a destination image using Porter-Duff composition.
  #
  # This is a convenience method that calls `draw_mask` with no mask.
  # The rectangle `r` in the destination is filled with pixels from the source
  # starting at point `sp`, using the specified composition operator.
  #
  # Parameters:
  # - `dst` : Destination image to draw onto
  # - `r` : Rectangle in destination to fill
  # - `src` : Source image to draw from
  # - `sp` : Starting point in source image
  # - `op` : Porter-Duff composition operator (e.g., OVER, SRC)
  #
  # Example:
  # ```
  # background = CrImage.rgba(400, 300, CrImage::Color.rgb(255, 255, 255))
  # logo = CrImage::PNG.read("logo.png")
  # CrImage::Draw.draw(background, logo.bounds, logo, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  # ```
  def self.draw(dst : Image, r : Rectangle, src : Image, sp : Point, op : Op)
    draw_mask(dst, r, src, sp, nil, Point.zero, op)
  end

  # Draws a source image onto a destination with an optional mask using Porter-Duff composition.
  #
  # Aligns `r.min` in dst with `sp` in src and `mp` in mask, then replaces the rectangle `r`
  # in dst with the result of a Porter-Duff composition. A nil mask is treated as fully opaque.
  # The mask's alpha channel controls the opacity of the source pixels.
  #
  # Parameters:
  # - `dst` : Destination image to draw onto
  # - `r` : Rectangle in destination to fill
  # - `src` : Source image to draw from
  # - `sp` : Starting point in source image
  # - `mask` : Optional mask image (nil for no mask)
  # - `mp` : Starting point in mask image
  # - `op` : Porter-Duff composition operator
  #
  # Example:
  # ```
  # background = CrImage.rgba(400, 300)
  # sprite = CrImage::PNG.read("sprite.png")
  # mask = CrImage::PNG.read("mask.png")
  # CrImage::Draw.draw_mask(background, sprite.bounds, sprite, CrImage.point(0, 0),
  #   mask, CrImage.point(0, 0), CrImage::Draw::Op::OVER)
  # ```
  def self.draw_mask(dst : Image, r : Rectangle, src : Image, sp : Point, mask : Image?, mp : Point, op : Op)
    r, sp, mp = clip(dst, r, src, sp, mask, mp)
    return if r.empty

    # Fast paths for special cases. If none of them apply, then we fall back to the general
    # but slow implementation
    case dst
    when RGBA
      if op == Op::OVER
        if mask.nil?
          case src
          when Uniform
            sr, sg, sb, sa = src.as(Uniform).rgba
            if sa == Color::MAX_32BIT
              return draw_fill_src(dst.as(RGBA), r, sr, sg, sb, sa)
            else
              return draw_fill_over(dst.as(RGBA), r, sr, sg, sb, sa)
            end
          when RGBA
            return draw_copy_over(dst.as(RGBA), r, src.as(RGBA), sp)
          when YCbCr
            # YCbCr is always fully opaque, and so if the mask is nil (i.e fully opaque)
            # then the op is effectively always Src. Similarly for CrImage::Gray and
            # CrImage::CMYK
            return CrImage.draw_ycbcr(dst.as(RGBA), r, src.as(YCbCr), sp)
          when Gray
            return draw_gray(dst.as(RGBA), r, src.as(Gray), sp)
          when CMYK
            return draw_cmyk(dst.as(RGBA), r, src.as(CMYK), sp)
          else
            #
          end
        elsif mask0 = mask
          if mask0.is_a?(Alpha)
            if src.is_a?(Uniform)
              return draw_glyph_over(dst.as(RGBA), r, src.as(Uniform), mask0, mp)
            end
          end
        end
      else
        if mask.nil?
          case src
          when Uniform
            sr, sg, sb, sa = src.as(Uniform).rgba
            return draw_fill_src(dst.as(RGBA), r, sr, sg, sb, sa)
          when RGBA
            return draw_copy_src(dst.as(RGBA), r, src.as(RGBA), sp)
          when NRGBA
            return draw_nrgba_src(dst.as(RGBA), r, src.as(NRGBA), sp)
          when YCbCr
            return CrImage.draw_ycbcr(dst.as(RGBA), r, src.as(YCbCr), sp)
          when Gray
            return draw_gray(dst.as(RGBA), r, src.as(Gray), sp)
          when CMYK
            return draw_cmyk(dst.as(RGBA), r, src.as(CMYK), sp)
          else
            #
          end
        end
      end
      return draw_rgba(dst.as(RGBA), r, src, sp, mask, mp, op)
    when Paletted
      if op == Op::SRC && mask.nil? && !process_backward(dst, r, src, sp)
        return draw_paletted(dst.as(Paletted), r, src, sp, false)
      end
    else
      #
    end

    x0, x1, dx = r.min.x, r.max.x, 1
    y0, y1, dy = r.min.y, r.max.y, 1
    if process_backward(dst, r, src, sp)
      x0, x1, dx = x1 - 1, x0 - 1, -1
      y0, y1, dy = y1 - 1, y0 - 1, -1
    end

    out_img = Color::RGBA64.new(0, 0, 0, 0)
    sy = sp.y + y0 - r.min.y
    my = mp.y + y0 - r.min.y

    y = y0
    while y != y1
      sx = sp.x + x0 - r.min.x
      mx = mp.x + x0 - r.min.x
      x = x0
      while x != x1
        ma = MAX_COLOR_VALUE.to_u32
        if mask0 = mask
          _, _, _, ma = mask0.at(mx, my).rgba
        end
        case
        when ma == 0
          dst.set(x, y, Color::TRANSPARENT) unless op == Op::OVER
        when ma == MAX_COLOR_VALUE && op == Op::SRC
          dst.set(x, y, src.at(sx, sy))
        else
          sr, sg, sb, sa = src.at(sx, sy).rgba
          if op == Op::OVER
            dr, dg, db, da = dst.at(x, y).rgba
            a = MAX_COLOR_VALUE - (sa * ma // MAX_COLOR_VALUE)
            out_img.r = ((dr*a + sr*ma) / MAX_COLOR_VALUE).to_u16
            out_img.g = ((dg*a + sg*ma) / MAX_COLOR_VALUE).to_u16
            out_img.b = ((db*a + sb*ma) / MAX_COLOR_VALUE).to_u16
            out_img.a = ((da*a + sa*ma) / MAX_COLOR_VALUE).to_u16
          else
            out_img.r = (sr * ma / MAX_COLOR_VALUE).to_u16
            out_img.g = (sg * ma / MAX_COLOR_VALUE).to_u16
            out_img.b = (sb * ma / MAX_COLOR_VALUE).to_u16
            out_img.a = (sa * ma / MAX_COLOR_VALUE).to_u16
          end

          dst.set(x, y, out_img)
        end
        x, sx, mx = x + dx, sx + dx, mx + dx
      end
      y, sy, my = y + dy, sy + dy, my + dy
    end
  end

  # clips r against each image's bounds, (after translating into the destination
  # image's coordinate space) and shifts the points sp and mp by the same amount as
  # change in r.min
  protected def self.clip(dst : Image, r : Rectangle, src : Image, sp : Point, mask : Image?, mp : Point?) : {Rectangle, Point, Point?}
    orig = r.min
    nr = r.intersect(dst.bounds)
    nr = nr.intersect(src.bounds + (orig - sp))
    if (m = mask) && (p = mp)
      nr = nr.intersect(m.bounds + (orig - p))
    end
    dx = nr.min.x - orig.x
    dy = nr.min.y - orig.y
    return {nr, sp, mp} if dx == 0 && dy == 0
    sp.x += dx
    sp.y += dy

    if !mp.nil?
      mp.x += dx
      mp.y += dy
    end
    {nr, sp, mp}
  end

  private def self.process_backward(dst, r, src, sp)
    dst == src && r.overlaps(r + (sp - r.min)) &&
      (sp.y < r.min.y || (sp.y == r.min.y && sp.x < r.min.x))
  end

  private def self.draw_fill_over(dst : RGBA, r : Rectangle, sr : UInt32, sg : UInt32, sb : UInt32, sa : UInt32)
    # The 0x101 is here for the same reason as in draw_rgba:
    # dr, dg, db and da are all 8-bit color at the moment, ranging in [0,255].
    # We work in 16-bit color, and so would normally do:
    # dr |= dr << 8
    # and similarly for dg, db and da, but instead we multiply a
    # (which is a 16-bit color, ranging in [0,65535]) by 0x101.
    # This yields the same result, but is fewer arithmetic operations.
    # Use wrapping arithmetic (&*, &-, &+) to prevent overflow.
    a = (MAX_COLOR_VALUE &- sa) &* 0x101
    i0 = dst.pixel_offset(r.min.x, r.min.y)
    i1 = i0 + r.width*4
    r.min.y.upto(r.max.y - 1) do |_|
      i0.step(to: i1 - 1, by: 4) do |i|
        dr = dst.pix[i + 0]
        dg = dst.pix[i + 1]
        db = dst.pix[i + 2]
        da = dst.pix[i + 3]

        dst.pix[i + 0] = ((dr.to_u32 &* a &+ sr &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        dst.pix[i + 1] = ((dg.to_u32 &* a &+ sg &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        dst.pix[i + 2] = ((db.to_u32 &* a &+ sb &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        dst.pix[i + 3] = ((da.to_u32 &* a &+ sa &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
      end
      i0 += dst.stride
      i1 += dst.stride
    end
  end

  private def self.draw_fill_src(dst, r, sr, sg, sb, sa)
    sr8 = (sr >> 8).to_u8
    sg8 = (sg >> 8).to_u8
    sb8 = (sb >> 8).to_u8
    sa8 = (sa >> 8).to_u8

    i0 = dst.pixel_offset(r.min.x, r.min.y)
    i1 = i0 + r.width * 4
    i0.step(to: i1 - 1, by: 4) do |i|
      dst.pix[i + 0] = sr8
      dst.pix[i + 1] = sg8
      dst.pix[i + 2] = sb8
      dst.pix[i + 3] = sa8
    end
    first_row = dst.pix[i0...i1]
    (r.min.y + 1).upto(r.max.y - 1) do |_|
      i0 += dst.stride
      i1 += dst.stride
      dst.pix[i0...i1].copy_from(first_row.to_unsafe, first_row.size)
    end
  end

  private def self.draw_copy_over(dst, r, src, sp)
    dx, dy = r.width, r.height
    d0 = dst.pixel_offset(r.min.x, r.min.y)
    s0 = src.pixel_offset(sp.x, sp.y)

    if r.min.y < sp.y || r.min.y == sp.y && r.min.x <= sp.x
      ddelta = dst.stride
      sdelta = src.stride
      i0, i1, idelta = 0, dx*4, 4
    else
      # If the source start point is higher than the destination start point, or equal height
      # but to the left, then we compose the rows in right-to-left, bottom-up order instead of
      # left-to-right, top-down.
      d0 += (dy - 1) * dst.stride
      s0 += (dy - 1) * src.stride
      ddelta = -dst.stride
      sdelta = -src.stride
      i0, i1, idelta = (dx - 1)*4, -4, -4
    end

    while dy > 0
      dpix = dst.pix[d0..]
      spix = src.pix[s0..]
      i = i0
      while i != i1
        s = spix[i...i + 4]
        # Scale 8-bit source values to 16-bit (multiply by 257 = 0x101)
        sr = s[0].to_u32
        sr |= sr << 8
        sg = s[1].to_u32
        sg |= sg << 8
        sb = s[2].to_u32
        sb |= sb << 8
        sa = s[3].to_u32
        sa |= sa << 8

        # The 0x101 is here for the same reason as in draw_rgba:
        # dr, dg, db and da are all 8-bit color at the moment, ranging in [0,255].
        # We work in 16-bit color, and so would normally do:
        # dr |= dr << 8
        # and similarly for dg, db and da, but instead we multiply a
        # (which is a 16-bit color, ranging in [0,65535]) by 0x101.
        # This yields the same result, but is fewer arithmetic operations.
        # Use wrapping arithmetic (&*, &-, &+) to prevent overflow.
        a = (MAX_COLOR_VALUE &- sa) &* 0x101

        d = dpix[i...i + 4]
        d[0] = ((d[0].to_u32 &* a &+ sr &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        d[1] = ((d[1].to_u32 &* a &+ sg &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        d[2] = ((d[2].to_u32 &* a &+ sb &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        d[3] = ((d[3].to_u32 &* a &+ sa &* MAX_COLOR_VALUE) // MAX_COLOR_VALUE >> 8).to_u8
        i += idelta
      end
      d0 += ddelta
      s0 += sdelta
      dy -= 1
    end
  end

  private def self.draw_copy_src(dst, r, src, sp)
    n, dy = 4*r.width, r.height
    d0 = dst.pixel_offset(r.min.x, r.min.y)
    s0 = src.pixel_offset(sp.x, sp.y)

    if r.min.y <= sp.y
      ddelta = dst.stride
      sdelta = src.stride
    else
      # If the source start point is higher than the destination start
      # point, then we compose the rows in bottom-up order instead of
      # top-down. Unlike the drawCopyOver function, we don't have to check
      # the x coordinates because the built-in copy function can handle
      # overlapping slices.

      d0 += (dy - 1) * dst.stride
      s0 += (dy - 1) * src.stride
      ddelta = -dst.stride
      sdelta = -src.stride
    end

    while dy > 0
      size = dst.pix[d0...d0 + n].size
      dst.pix[d0...d0 + n].copy_from(src.pix[s0...s0 + n].to_unsafe, size)
      d0 += ddelta
      s0 += sdelta

      dy -= 1
    end
  end

  private def self.draw_nrgba_over(dst, r, src, sp)
    i0 = (r.min.x - dst.rect.min.x) * 4
    i1 = (r.max.x - dst.rect.min.x) * 4
    si0 = (sp.x - src.rect.min.x) * 4
    ymax = r.max.y - dst.rect.min.y

    y = r.min.y - dst.rect.min.y
    sy = sp.y - src.rect.min.y

    while y != ymax
      dpix = dst.pix[y*dst.stride..]
      spix = src.pix[sy*src.stride..]

      i, si = i0, si0

      while i < i1
        # Convert from non-premultiplied color to pre-multiplied color
        s = spix[si...si + 4]
        sa = s[3].to_u32 * 0x101
        sr = s[0].to_u32 * sa // 0xff
        sg = s[1].to_u32 * sa // 0xff
        sb = s[2].to_u32 * sa // 0xff

        d = dpix[i...i + 4]
        dr = d[0].to_u32
        dg = d[1].to_u32
        db = d[2].to_u32
        da = d[3].to_u32

        # The 0x101 is here for the same reason as in draw_rgba
        a = (MAX_COLOR_VALUE - sa) * 0x101

        d[0] = ((dr * a // MAX_COLOR_VALUE + sr) >> 8).to_u8
        d[1] = ((dg * a // MAX_COLOR_VALUE + sg) >> 8).to_u8
        d[2] = ((db * a // MAX_COLOR_VALUE + sb) >> 8).to_u8
        d[3] = ((da * a // MAX_COLOR_VALUE + sa) >> 8).to_u8
        i, si = i + 4, si + 4
      end
      y, sy = y + 1, sy + 1
    end
  end

  private def self.draw_nrgba_src(dst, r, src, sp)
    i0 = (r.min.x - dst.rect.min.x) * 4
    i1 = (r.max.x - dst.rect.min.x) * 4
    si0 = (sp.x - src.rect.min.x) * 4
    ymax = r.max.y - dst.rect.min.y

    y = r.min.y - dst.rect.min.y
    sy = sp.y - src.rect.min.y

    while y != ymax
      dpix = dst.pix[y*dst.stride..]
      spix = src.pix[sy*src.stride..]

      i, si = i0, si0

      while i < i1
        # Convert from non-premultiplied color to pre-multiplied color
        s = spix[si...si + 4]
        sa = s[3].to_u32 * 0x101
        sr = s[0].to_u32 * sa // 0xff
        sg = s[1].to_u32 * sa // 0xff
        sb = s[2].to_u32 * sa // 0xff

        d = dpix[i...i + 4]

        d[0] = (sr >> 8).to_u8
        d[1] = (sg >> 8).to_u8
        d[2] = (sb >> 8).to_u8
        d[3] = (sa >> 8).to_u8
        i, si = i + 4, si + 4
      end
      y, sy = y + 1, sy + 1
    end
  end

  private def self.draw_gray(dst, r, src, sp)
    i0 = (r.min.x - dst.rect.min.x) * 4
    i1 = (r.max.x - dst.rect.min.x) * 4
    si0 = (sp.x - src.rect.min.x) * 1
    ymax = r.max.y - dst.rect.min.y

    y = r.min.y - dst.rect.min.y
    sy = sp.y - src.rect.min.y

    while y != ymax
      dpix = dst.pix[y*dst.stride..]
      spix = src.pix[sy*src.stride..]

      i, si = i0, si0

      while i < i1
        p = spix[si]
        d = dpix[i...i + 4]

        d[0] = p
        d[1] = p
        d[2] = p
        d[3] = 255_u8
        i, si = i + 4, si + 1
      end
      y, sy = y + 1, sy + 1
    end
  end

  private def self.draw_cmyk(dst, r, src, sp)
    i0 = (r.min.x - dst.rect.min.x) * 4
    i1 = (r.max.x - dst.rect.min.x) * 4
    si0 = (sp.x - src.rect.min.x) * 4
    ymax = r.max.y - dst.rect.min.y

    y = r.min.y - dst.rect.min.y
    sy = sp.y - src.rect.min.y

    while y != ymax
      dpix = dst.pix[y*dst.stride..]
      spix = src.pix[sy*src.stride..]

      i, si = i0, si0

      while i < i1
        s = spix[si...si + 4]
        d = dpix[i...i + 4]

        d[0], d[1], d[2] = Color.cmyk_to_rgb(s[0], s[1], s[2], s[3])
        d[3] = 255_u8
        i, si = i + 4, si + 4
      end
      y, sy = y + 1, sy + 1
    end
  end

  private def self.draw_glyph_over(dst, r, src, mask, mp)
    i0 = dst.pixel_offset(r.min.x, r.min.y)
    i1 = i0 + r.width*4
    mi0 = mask.pixel_offset(mp.x, mp.y)
    sr, sg, sb, sa = src.rgba

    y, my = r.min.y, mp.y
    while y != r.max.y
      i, mi = i0, mi0
      while i < i1
        ma = mask.pix[mi].to_u32
        if ma == 0
          i, mi = i + 4, mi + 1
          next
        end
        ma |= ma << 8

        # The 0x101 is here for the same reason as in draw_rgba
        # Use wrapping arithmetic (&*) to prevent overflow, matching draw_rgba
        a = (MAX_COLOR_VALUE &- (sa &* ma // MAX_COLOR_VALUE)) &* 0x101

        d = dst.pix[i...i + 4]
        d[0] = ((d[0].to_u32 &* a &+ sr &* ma) // MAX_COLOR_VALUE >> 8).to_u8
        d[1] = ((d[1].to_u32 &* a &+ sg &* ma) // MAX_COLOR_VALUE >> 8).to_u8
        d[2] = ((d[2].to_u32 &* a &+ sb &* ma) // MAX_COLOR_VALUE >> 8).to_u8
        d[3] = ((d[3].to_u32 &* a &+ sa &* ma) // MAX_COLOR_VALUE >> 8).to_u8

        i, mi = i + 4, mi + 1
      end
      i0 += dst.stride
      i1 += dst.stride
      mi0 += mask.stride

      y, my = y + 1, my + 1
    end
  end

  private def self.draw_rgba(dst, r, src, sp, mask, mp, op)
    x0, x1, dx = r.min.x, r.max.x, 1
    y0, y1, dy = r.min.y, r.max.y, 1

    if dst == src && r.overlaps(r + (sp - r.min))
      if sp.y < r.min.y || sp.y == r.min.y && sp.x < r.min.x
        x0, x1, dx = x1 - 1, x0 - 1, -1
        y0, y1, dy = y1 - 1, y0 - 1, -1
      end
    end

    sy = sp.y + y0 - r.min.y
    my = mp.y + y0 - r.min.y
    sx0 = sp.x + x0 - r.min.x
    mx0 = mp.x + x0 - r.min.x
    sx1 = sx0 + (x1 - x0)
    i0 = dst.pixel_offset(x0, y0)
    di = dx * 4

    y = y0
    while y != y1
      i, sx, mx = i0, sx0, mx0
      while sx != sx1
        ma = MAX_COLOR_VALUE.to_u32
        if mask0 = mask
          _, _, _, ma = mask0.at(mx, my).rgba
        end
        sr, sg, sb, sa = src.at(sx, sy).rgba
        d = dst.pix[i...i + 4]
        if op == Op::OVER
          dr = d[0].to_u32
          dg = d[1].to_u32
          db = d[2].to_u32
          da = d[3].to_u32

          # dr, dg, db and da are all 8-bit color at the moment, ranging in [0,255].
          # We work in 16-bit color, and so would normally do:
          # dr |= dr << 8
          # and similarly for dg, db and da, but instead we multiply a
          # (which is a 16-bit color, ranging in [0,65535]) by 0x101.
          # This yields the same result, but is fewer arithmetic operations.

          a = (MAX_COLOR_VALUE - (sa * ma // MAX_COLOR_VALUE)) * 0x101

          d[0] = ((dr &* a &+ sr &* ma) // MAX_COLOR_VALUE >> 8).to_u8
          d[1] = ((dg &* a &+ sg &* ma) // MAX_COLOR_VALUE >> 8).to_u8
          d[2] = ((db &* a &+ sb &* ma) // MAX_COLOR_VALUE >> 8).to_u8
          d[3] = ((da &* a &+ sa &* ma) // MAX_COLOR_VALUE >> 8).to_u8
        else
          d[0] = (sr * ma // MAX_COLOR_VALUE >> 8).to_u8
          d[1] = (sg * ma // MAX_COLOR_VALUE >> 8).to_u8
          d[2] = (sb * ma // MAX_COLOR_VALUE >> 8).to_u8
          d[3] = (sa * ma // MAX_COLOR_VALUE >> 8).to_u8
        end
        i, sx, mx = i + di, sx + dx, mx + dx
      end
      i0 += dy * dst.stride

      y, sy, my = y + dy, sy + dy, my + dy
    end
  end

  # clamps i to the interval [0, MAX_16BIT]
  private def self.clamp(i)
    return 0 if i < 0
    return COLOR_MAX_16.to_i32 if i > COLOR_MAX_16
    i
  end

  # sq_diff returns the squared-difference of x and y, shifted by 2 so that
  # adding four of those won't overflow a UInt32
  #
  # x and y are both assumed to be in the range [0, MAX_16BIT]
  private def self.sq_diff(x : Int32, y : Int32) : UInt32
    d = (x &- y).to_u32!
    ((d &* d) >> 2).to_u32!
  end

  protected def self.draw_paletted(dst, r, src, sp, floyd_steinberg)
    # handle the case where dst and src overlap.
    # does it even make sense to try and do Floyd-Steinberg whilst
    # walking the image backward (right-to-left bottom-to-top)?
    #
    # If dst is `Paletted`, we have a fast path for dst.set and dst.at.
    # The dst.set equivalent is a batch version of algorithm used by
    # Color::Palette's index method in Color module, plus optional Floyd-Steinberg error diffusion
    palette, pix, stride = Array.new(0) { Array.new(4, 0) }, Bytes.empty, 0
    if p = dst.as?(Paletted)
      palette = Array.new(p.palette.size) { Array.new(4, 0) }
      p.palette.each_with_index do |col, i|
        cr, g, b, a = col.rgba

        palette[i][0] = cr.to_i
        palette[i][1] = g.to_i
        palette[i][2] = b.to_i
        palette[i][3] = a.to_i
      end
      pix, stride = p.pix[p.pixel_offset(r.min.x, r.min.y)...], p.stride
    end

    # quant_error_curr and quant_error_next are the Floyd-Steiberg quantization
    # errors that have been propagated to the pixels in the current and next rows.
    # The +2 simplifies calculation near the edges.
    quant_error_curr = Array.new(0) { Array.new(4, 0) }
    quant_error_next = Array.new(0) { Array.new(4, 0) }

    if floyd_steinberg
      quant_error_curr = Array.new(r.width + 2) { Array.new(4, 0) } # Array(StaticArray(Int32, 4)).new(r.width + 2, StaticArray(Int32, 4).new(0))
      # quant_error_curr.map! { |_| StaticArray(Int32, 4).new(0) }
      quant_error_next = Array.new(r.width + 2) { Array.new(4, 0) } # Array(StaticArray(Int32, 4)).new(r.width + 2, StaticArray(Int32, 4).new(0))
      # quant_error_next.map! { |_| StaticArray(Int32, 4).new(0) }
    end

    # Fast paths for special cases to avoid excessive use of the Color::Color interface
    # which escapes to the heap but need to be discovered for each pixel on r.
    px_rgba = case src
              when RGBA
                ->(x : Int32, y : Int32) { src.as(RGBA).rgba_at(x, y).rgba }
              when NRGBA
                ->(x : Int32, y : Int32) { src.as(NRGBA).nrgba_at(x, y).rgba }
              when YCbCr
                ->(x : Int32, y : Int32) { src.as(YCbCr).ycbcr_at(x, y).rgba }
              else
                ->(x : Int32, y : Int32) { src.at(x, y).rgba }
              end

    # Loop over each source pixel.
    outc = Color::RGBA64.new(0, 0, 0, Color::MAX_16BIT)
    0.upto(r.height - 1) do |y|
      0.upto(r.width - 1) do |x|
        # er, eg, and eb are the pixel's R,G,B values plus the optional Floyd-Steinberg error
        sr, sg, sb, sa = px_rgba.call(sp.x + x, sp.y + y)
        er, eg, eb, ea = sr.to_i, sg.to_i, sb.to_i, sa.to_i

        if floyd_steinberg
          er = clamp(er + quant_error_curr[x + 1][0]//16)
          eg = clamp(eg + quant_error_curr[x + 1][1]//16)
          eb = clamp(eb + quant_error_curr[x + 1][2]//16)
          ea = clamp(ea + quant_error_curr[x + 1][3]//16)
        end

        if palette.size > 0
          # Find the closest palette color in Euclidean R,G,B,A space:
          # the one that minimizes sum-squared-difference
          best_index, best_sum = 0, UInt32::MAX
          palette.each_with_index do |pal_color, idx|
            sum = sq_diff(er, pal_color[0]) + sq_diff(eg, pal_color[1]) + sq_diff(eb, pal_color[2]) + sq_diff(ea, pal_color[3])
            if sum < best_sum
              best_index, best_sum = idx, sum
              break if sum == 0
            end
          end
          pix[y*stride + x] = best_index.clamp(0, 255).to_u8
          next unless floyd_steinberg

          er -= palette[best_index][0]
          eg -= palette[best_index][1]
          eb -= palette[best_index][2]
          ea -= palette[best_index][3]
        else
          outc.r = er.to_u16
          outc.g = eg.to_u16
          outc.b = eb.to_u16
          outc.a = ea.to_u16

          dst.set(r.min.x + x, r.min.y + y, outc)

          next unless floyd_steinberg

          sr, sg, sb, sa = dst.at(r.min.x + x, r.min.y + y).rgba
          er -= sr.to_i
          eg -= sg.to_i
          eb -= sb.to_i
          ea -= sa.to_i
        end

        # Propagate the Floyd-Steinberg quantization error.
        quant_error_next[x + 0][0] += er * 3
        quant_error_next[x + 0][1] += eg * 3
        quant_error_next[x + 0][2] += eb * 3
        quant_error_next[x + 0][3] += ea * 3
        quant_error_next[x + 1][0] += er * 5
        quant_error_next[x + 1][1] += eg * 5
        quant_error_next[x + 1][2] += eb * 5
        quant_error_next[x + 1][3] += ea * 5
        quant_error_next[x + 2][0] += er * 1
        quant_error_next[x + 2][1] += eg * 1
        quant_error_next[x + 2][2] += eb * 1
        quant_error_next[x + 2][3] += ea * 1
        quant_error_curr[x + 2][0] += er * 7
        quant_error_curr[x + 2][1] += eg * 7
        quant_error_curr[x + 2][2] += eb * 7
        quant_error_curr[x + 2][3] += ea * 7
      end

      # Recycle the quantization error buffers
      if floyd_steinberg
        quant_error_curr, quant_error_next = quant_error_next, quant_error_curr
        quant_error_next.each_with_index do |_, i|
          quant_error_next[i].fill(0, 0, 4) # = #StaticArray(Int32, 4).new(0)
        end
      end
    end
  end
end
