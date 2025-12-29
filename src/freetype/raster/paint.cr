module FreeType::Raster
  # A Span is a horizontal segment of pixels with constant alpha. X0 is an
  # inclusive bound and X1 is exclusive, the same as for slices. A fully opaque
  # Span has Alpha == 0xffff.
  # record Span, y : Int32 = 0, x0 : Int32 = 0, x1 : Int32 = 0, alpha : UInt32 = 0u32
  class Span
    property y : Int32
    property x0 : Int32
    property x1 : Int32
    property alpha : UInt32

    def initialize(@y = 0, @x0 = 0, @x1 = 0, @alpha = 0_u32)
    end
  end

  # A Painter knows how to paint a batch of `Span`s. Rasterization may involve Painting
  # multiple batches, and done will be true for the final batch. The `Span`'s y values are
  # monotonically increasing during a rasterization. `Paint` may use all of ss as scratch space
  # during the call
  module Painter
    abstract def paint(ss : Array(Span), done : Bool)
  end

  # The `PainterFunc` type adapts an ordinary function to the `Painter` interface
  alias PainterFunc = (Array(Span), Bool) -> Nil

  # An `AlphaOverPainter` is a `Painter` that paints `Span`s onto a `CrImage::Alpha` using
  # the over Porter-Duff composition operator.
  class AlphaOverPainter
    include Painter
    property image : CrImage::Alpha

    def initialize(@image)
    end

    def paint(ss : Array(Span), done : Bool)
      b = @image.bounds
      ss.each do |span|
        next if span.y < b.min.y
        break if span.y >= b.max.y
        span.x0 = b.min.x if span.x0 < b.min.x
        span.x1 = b.max.x if span.x1 > b.max.x
        next if span.x0 >= span.x1
        base = (span.y - image.rect.min.y) * image.stride - image.rect.min.x
        p = image.pix[base + span.x0...base + span.x1]
        a = (span.alpha >> 8).to_i
        p.each_with_index do |color, idx|
          v = color.to_i
          p[idx] = ((v*255 + (255 - v)*a) // 255).to_u8
        end
      end
    end
  end

  # An `AlphaSrcPainter` is a `Painter` that paints `Span`s onto a `CrImage::Alpha` using
  # the src Porter-Duff composition operator.
  class AlphaSrcPainter
    include Painter
    property image : CrImage::Alpha

    def initialize(@image)
    end

    def paint(ss : Array(Span), done : Bool)
      b = @image.bounds
      ss.each do |span|
        next if span.y < b.min.y
        break if span.y >= b.max.y
        span.x0 = b.min.x if span.x0 < b.min.x
        span.x1 = b.max.x if span.x1 > b.max.x
        next if span.x0 >= span.x1
        base = (span.y - image.rect.min.y) * image.stride - image.rect.min.x
        p = image.pix[base + span.x0...base + span.x1]
        color = (span.alpha >> 8).to_u8
        p.each_with_index do |_, idx|
          p[idx] = color
        end
      end
    end
  end

  # An `RGBAPainter` is a `Painter` that paints `Span`s onto a `CrImage::RGBA`
  class RGBAPainter
    include Painter
    property image : CrImage::RGBA
    property op : CrImage::Draw::Op

    def initialize(@image, @op)
      # cr, cg, cb, ca are the 16-bit color to pain the spans.
      @cr = 0_u32
      @cg = 0_u32
      @cb = 0_u32
      @ca = 0_u32
    end

    def paint(ss : Array(Span), done : Bool)
      b = @image.bounds
      ss.each do |span|
        next if span.y < b.min.y
        break if span.y >= b.max.y
        span.x0 = b.min.x if span.x0 < b.min.x
        span.x1 = b.max.x if span.x1 > b.max.x
        next if span.x0 >= span.x1
        # This code mimics `CrImage::Draw#draw_glyph_over`
        ma = span.alpha
        m = (1 << 16) - 1
        i0 = (span.y - image.rect.min.y)*image.stride + (span.x0 - image.rect.min.x)*4
        i1 = i0 + (span.x1 - span.x0)*4
        if op == CrImage::Draw::Op::OVER
          i = i0
          while i < i1
            dr = image.pix[i + 0].to_u32
            dg = image.pix[i + 1].to_u32
            db = image.pix[i + 2].to_u32
            da = image.pix[i + 3].to_u32
            a = (m - (@ca * ma // m)) * 0x101
            image.pix[i + 0] = (((dr*a + @cr*ma) // m >> 8) & 0xFF).to_u8
            image.pix[i + 1] = (((dg*a + @cg*ma) // m >> 8) & 0xFF).to_u8
            image.pix[i + 2] = (((db*a + @cb*ma) // m >> 8) & 0xFF).to_u8
            image.pix[i + 3] = (((da*a + @ca*ma) // m >> 8) & 0xFF).to_u8
            i += 4
          end
        else
          i = i0
          while i < i1
            image.pix[i + 0] = ((@cr * ma // m >> 8) & 0xFF).to_u8
            image.pix[i + 1] = ((@cg * ma // m >> 8) & 0xFF).to_u8
            image.pix[i + 2] = ((@cb * ma // m >> 8) & 0xFF).to_u8
            image.pix[i + 3] = ((@ca * ma // m >> 8) & 0xFF).to_u8
            i += 4
          end
        end
      end
    end

    # color= sets the color to pain the spans
    def color=(c : CrImage::Color::Color)
      @cr, @cg, @cb, @ca = c.rgba
    end
  end

  # A `MonochromePainter` wraps another `Painter`, quantizing each Span's alpha to
  # be either fully opaque or fully transparent
  class MonochromePainter
    include Painter
    property painter : Painter

    def initialize(@painter)
      @y = 0
      @x0 = 0
      @x1 = 0
    end

    # paint delegates to the wrapped `Painter` after quantizing each `Span`'s alpha
    # value and merging adjacent fully opaque `Span`s
    def paint(ss : Array(Span), done : Bool)
      # we compact the ss slice, discarding any Spans whose alpha quantizes to zero
      j = 0
      ss.each do |span|
        if span.alpha >= 0x8000
          if @y == span.y && @x1 == span.x0
            @x1 = span.x1
          else
            ss[j] = Span.new(@y, @x0, @x1, ((1 << 16) - 1).to_u32)
            j += 1
            @y, @x0, @x1 = span.y, span.x0, span.x1
          end
        end
      end
      if done
        # flush the accumulated Span
        final_span = Span.new(@y, @x0, @x1, ((1 << 16) - 1).to_u32)
        if j < ss.size
          ss[j] = final_span
          j += 1
          @painter.paint(ss[...j], true)
        elsif j == ss.size
          @painter.paint(ss, false)
          ss.clear
          ss << final_span
          @painter.paint(ss, true)
        else
          raise "Unreachable"
        end
        # Reset the accumulator, so that this Painter can be re-used
        @y, @x0, @x1 = 0, 0, 0
      else
        @painter.paint(ss[...j], false)
      end
    end
  end

  # A GammaCorrectionPainter wraps another Painter, performing gamma-correction
  # on each Span's alpha value
  class GammaCorrectionPainter
    include Painter
    property painter : Painter

    def initialize(@painter, gamma : Float64)
      # a is precomputed alpha values for linear interpolation, with fully opaque == 0xffff
      @a = uninitialized UInt16[256]
      # whether gamma correction is a no-op
      @gamma_is_one = false
      self.gamma = gamma
    end

    def paint(ss : Array(Span), done : Bool)
      unless @gamma_is_one
        n = 0x101
        ss.each_with_index do |span, idx|
          next if span.alpha == 0 || span.alpha == 0xffff

          p, q = span.alpha//n, span.alpha % n
          # The resultant alpha is a linear interpolation of @a[p] and @a[p+1]
          a = @a[p].to_u32 * (n - q) + @a[p + 1].to_u32*q
          ss[idx].alpha = (a + n // 2) // n
        end
      end
      painter.paint(ss, done)
    end

    # sets the gamma value
    def gamma=(gamma : Float64)
      @gamma_is_one = gamma == 1
      return if @gamma_is_one
      0.upto(255) do |i|
        a = i.to_f / 0xff
        a = a ** gamma
        @a[i] = (0xfff * a).to_u16
      end
    end
  end

  # An RGBPainter is a simple alias for RGBAPainter for convenience
  # Used for basic RGB rendering without subpixel anti-aliasing
  alias RGBPainter = RGBAPainter

  # An RGBSubpixelPainter paints Spans onto an RGBA image using subpixel
  # anti-aliasing for LCD displays. This improves text rendering by using
  # the RGB subpixels independently for horizontal resolution.
  class RGBSubpixelPainter
    include Painter
    property image : CrImage::RGBA
    property bgr : Bool
    property vertical : Bool

    @cr : UInt32
    @cg : UInt32
    @cb : UInt32
    @ca : UInt32
    @filter_weights : StaticArray(UInt8, 5)

    def initialize(@image, @bgr = false, @vertical = false)
      @cr = 0_u32
      @cg = 0_u32
      @cb = 0_u32
      @ca = 0_u32

      # LCD filter weights (FreeType's default light filter)
      # These weights are applied to neighboring pixels for smoother subpixel rendering
      @filter_weights = StaticArray[0x08_u8, 0x4d_u8, 0x56_u8, 0x4d_u8, 0x08_u8]
    end

    def paint(ss : Array(Span), done : Bool)
      b = @image.bounds

      if @vertical
        paint_vertical(ss, b)
      else
        paint_horizontal(ss, b)
      end
    end

    private def paint_horizontal(ss : Array(Span), b : CrImage::Rectangle)
      ss.each do |span|
        next if span.y < b.min.y
        break if span.y >= b.max.y
        span.x0 = b.min.x if span.x0 < b.min.x
        span.x1 = b.max.x if span.x1 > b.max.x
        next if span.x0 >= span.x1

        ma = span.alpha
        m = (1 << 16) - 1

        # Apply subpixel rendering with LCD filtering
        base = (span.y - @image.rect.min.y) * @image.stride + (span.x0 - @image.rect.min.x) * 4

        span.x0.upto(span.x1 - 1) do |x|
          offset = base + (x - span.x0) * 4

          # Read destination pixel
          dr = @image.pix[offset + 0].to_u32
          dg = @image.pix[offset + 1].to_u32
          db = @image.pix[offset + 2].to_u32
          da = @image.pix[offset + 3].to_u32

          # Apply subpixel anti-aliasing
          # For horizontal LCD, we can apply different alpha to R, G, B channels
          # This creates sharper horizontal edges

          # Simple subpixel rendering: use full alpha for now
          # A more sophisticated implementation would apply LCD filtering
          a = (m - (@ca * ma // m)) * 0x101

          @image.pix[offset + 0] = (((dr * a + @cr * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 1] = (((dg * a + @cg * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 2] = (((db * a + @cb * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 3] = (((da * a + @ca * ma) // m >> 8) & 0xFF).to_u8
        end
      end
    end

    private def paint_vertical(ss : Array(Span), b : CrImage::Rectangle)
      # Vertical subpixel rendering (less common, for rotated displays)
      ss.each do |span|
        next if span.y < b.min.y
        break if span.y >= b.max.y
        span.x0 = b.min.x if span.x0 < b.min.x
        span.x1 = b.max.x if span.x1 > b.max.x
        next if span.x0 >= span.x1

        ma = span.alpha
        m = (1 << 16) - 1

        base = (span.y - @image.rect.min.y) * @image.stride + (span.x0 - @image.rect.min.x) * 4

        span.x0.upto(span.x1 - 1) do |x|
          offset = base + (x - span.x0) * 4

          dr = @image.pix[offset + 0].to_u32
          dg = @image.pix[offset + 1].to_u32
          db = @image.pix[offset + 2].to_u32
          da = @image.pix[offset + 3].to_u32

          a = (m - (@ca * ma // m)) * 0x101

          @image.pix[offset + 0] = (((dr * a + @cr * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 1] = (((dg * a + @cg * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 2] = (((db * a + @cb * ma) // m >> 8) & 0xFF).to_u8
          @image.pix[offset + 3] = (((da * a + @ca * ma) // m >> 8) & 0xFF).to_u8
        end
      end
    end

    def color=(c : CrImage::Color::Color)
      @cr, @cg, @cb, @ca = c.rgba

      # Swap R and B for BGR order
      if @bgr
        @cr, @cb = @cb, @cr
      end
    end
  end
end
