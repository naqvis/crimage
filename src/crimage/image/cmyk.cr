module CrImage
  # CMYK is an in-memory image using the CMYK color model.
  #
  # Each pixel is stored as 4 bytes (Cyan, Magenta, Yellow, Black/Key).
  # Used primarily for print production and prepress workflows.
  #
  # Memory layout: Contiguous byte array with 4 bytes per pixel
  # Color model: CMYK (subtractive color for printing)
  #
  # Use CMYK for:
  # - Print production workflows
  # - Converting images for professional printing
  # - Prepress color separation
  #
  # Example:
  # ```
  # img = CrImage::CMYK.new(CrImage.rect(0, 0, 640, 480))
  # img.set_cmyk(100, 100, CrImage::Color::CMYK.new(0, 255, 255, 0)) # Red in CMYK
  # ```
  class CMYK
    include Image
    @pix : Bytes
    # Stride is the pixel buffer stride (in bytes) between vertically adjacent pixels.
    getter stride : Int32
    # Rectangle defining the image's bounds.
    getter rect : Rectangle

    # Returns a read-only view of the pixel buffer
    # Modifying the returned Bytes directly is unsafe and may break image invariants
    # Use at()/set() methods for safe pixel manipulation
    # :nodoc:
    def pix : Bytes
      @pix
    end

    def initialize(@pix = Bytes.empty, @stride = 0, @rect = Rectangle.zero)
    end

    def initialize(r : Rectangle)
      w, h = r.width, r.height
      @pix = Bytes.new(4*w*h)
      @stride = 4 * w
      @rect = r
    end

    def color_model : Color::Model
      Color.cmyk_model
    end

    def bounds : Rectangle
      @rect
    end

    def at(x : Int32, y : Int32) : Color::Color
      cmyk_at(x, y)
    end

    def cmyk_at(x : Int32, y : Int32) : Color::CMYK
      return Color::CMYK.new(0, 0, 0, 0) unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      s = @pix[i...i + 4]
      Color::CMYK.new(s[0], s[1], s[2], s[3])
    end

    def pixel_offset(x : Int32, y : Int32) : Int32
      (y - @rect.min.y) * stride + (x - rect.min.x)*4
    end

    def set(x : Int32, y : Int32, c : Color::Color)
      return unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      c1 = Color.cmyk_model.convert(c)
      return unless c1.is_a?(Color::CMYK)

      s = @pix[i...i + 4]
      s[0] = c1.c
      s[1] = c1.m
      s[2] = c1.y
      s[3] = c1.k
    end

    def set_cmyk(x : Int32, y : Int32, c : Color::CMYK)
      return unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      s = @pix[i...i + 4]
      s[0] = c.c
      s[1] = c.m
      s[2] = c.y
      s[3] = c.k
    end

    # sub_image returns an image representing the portion of the image visible though r.
    # the returned value shares pixes with the original image.
    def sub_image(r : Rectangle) : Image
      r = r.intersect(@rect)
      # if r1 and r2 are Rectangles, r1.intersect(r2) is not guranteed to be inside
      # either r1 or r2 if the intersection is empty. Without explicitly checking for this
      # the pix[i..] expression can raise exception
      return CMYK.new if r.empty
      i = pixel_offset(r.min.x, r.min.y)
      CMYK.new(@pix[i..], @stride, r)
    end

    # opaque? scans the entire image and reports whether it is fully opaque
    def opaque? : Bool
      true
    end

    def_equals_and_hash @pix, @stride, @rect
  end
end
