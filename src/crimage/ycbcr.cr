require "./geom"
require "./color"
require "./image"

module CrImage
  # YCbCrSubsampleRatio defines the chroma subsampling ratio used in YCbCr images.
  #
  # Chroma subsampling reduces color information while preserving luminance,
  # exploiting the human eye's lower sensitivity to color detail.
  #
  # Ratios explained (horizontal:vertical):
  # - `YCbCrSubsampleRatio444` : 4:4:4 - No subsampling, full color resolution
  # - `YCbCrSubsampleRatio422` : 4:2:2 - Half horizontal color resolution (common in video)
  # - `YCbCrSubsampleRatio420` : 4:2:0 - Half horizontal and vertical (JPEG, MPEG)
  # - `YCbCrSubsampleRatio440` : 4:4:0 - Half vertical color resolution
  # - `YCbCrSubsampleRatio411` : 4:1:1 - Quarter horizontal color resolution
  # - `YCbCrSubsampleRatio410` : 4:1:0 - Quarter horizontal, half vertical
  enum YCbCrSubSampleRatio
    YCbCrSubsampleRatio444 = 0
    YCbCrSubsampleRatio422
    YCbCrSubsampleRatio420
    YCbCrSubsampleRatio440
    YCbCrSubsampleRatio411
    YCbCrSubsampleRatio410
  end

  # YCbCr is an in-memory image using the Y'CbCr color space.
  #
  # Y'CbCr separates luminance (Y') from chrominance (Cb, Cr), commonly used in
  # JPEG compression and video encoding. There is one Y sample per pixel, but
  # Cb and Cr samples can span multiple pixels depending on the subsampling ratio.
  #
  # Memory layout:
  # - `y_stride` : Y slice index delta between vertically adjacent pixels
  # - `c_stride` : Cb/Cr slice index delta between vertically adjacent chroma samples
  #
  # Typical stride relationships (y_stride and y.size are multiples of 8):
  # - For 4:4:4: c_stride == y_stride//1 && cb.size == cr.size == y.size//1
  # - For 4:2:2: c_stride == y_stride//2 && cb.size == cr.size == y.size//2
  # - For 4:2:0: c_stride == y_stride//2 && cb.size == cr.size == y.size//4
  # - For 4:4:0: c_stride == y_stride//1 && cb.size == cr.size == y.size//2
  # - For 4:1:1: c_stride == y_stride//4 && cb.size == cr.size == y.size//4
  # - For 4:1:0: c_stride == y_stride//4 && cb.size == cr.size == y.size//8
  #
  # Example:
  # ```
  # # Create YCbCr image with 4:2:0 subsampling (JPEG standard)
  # img = CrImage::YCbCr.new(
  #   CrImage.rect(0, 0, 640, 480),
  #   CrImage::YCbCrSubSampleRatio::YCbCrSubsampleRatio420
  # )
  #
  # # Set pixel in YCbCr space
  # img.set_ycbcr(100, 100, CrImage::Color::YCbCr.new(128, 128, 128))
  # ```
  class YCbCr
    include Image
    property y : Bytes
    property cb : Bytes
    property cr : Bytes
    property y_stride : Int32
    property c_stride : Int32
    property sub_sample_ratio : YCbCrSubSampleRatio
    property rect : Rectangle

    def initialize(@y = Bytes.empty, @cb = Bytes.empty, @cr = Bytes.empty,
                   @y_stride = 0, @c_stride = 0, @sub_sample_ratio = YCbCrSubSampleRatio::YCbCrSubsampleRatio444,
                   @rect = Rectangle.zero)
    end

    def initialize(@rect : Rectangle, @sub_sample_ratio : YCbCrSubSampleRatio)
      w, h, cw, ch = CrImage.ycbcr_size(rect, sub_sample_ratio)

      i0 = w*h + 0*cw*ch
      i1 = w*h + 1*cw*ch
      i2 = w*h + 2*cw*ch
      b = Bytes.new(i2)

      @y = b[...i0]
      @cb = b[i0...i1]
      @cr = b[i1...i2]
      @y_stride = w
      @c_stride = cw
    end

    def color_model : Color::Model
      Color.ycbcr_model
    end

    def bounds : Rectangle
      @rect
    end

    def at(x : Int32, y : Int32) : Color::Color
      ycbcr_at(x, y)
    end

    def set(x : Int32, y : Int32, c : Color::Color)
      return unless Point.new(x, y).in(@rect)

      # Convert to YCbCr if needed
      ycbcr = c.is_a?(Color::YCbCr) ? c : Color.ycbcr_model.convert(c).as(Color::YCbCr)
      set_ycbcr(x, y, ycbcr)
    end

    def set_ycbcr(x : Int32, y : Int32, c : Color::YCbCr)
      return unless Point.new(x, y).in(@rect)

      yi = y_offset(x, y)
      ci = c_offset(x, y)

      @y[yi] = c.y
      @cb[ci] = c.cb
      @cr[ci] = c.cr
    end

    def ycbcr_at(x : Int32, y : Int32) : Color::Color
      return Color::YCbCr.new(0, 0, 0) unless Point.new(x, y).in(@rect)
      yi = y_offset(x, y)
      ci = c_offset(x, y)
      Color::YCbCr.new(@y[yi], cb[ci], cr[ci])
    end

    # returns the index of the first element of Y that corresponds to the pixel at (x,y)
    def y_offset(x, y)
      (y - rect.min.y)*y_stride + (x - rect.min.x)
    end

    # returns the index of the first element of cb or cr that corresponds to the pixel at (x,y)
    def c_offset(x, y)
      case sub_sample_ratio
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio422
        (y - rect.min.y)*c_stride + ((x/2).to_i - (rect.min.x/2).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio420
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + ((x/2).to_i - (rect.min.x/2).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio440
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + (x - rect.min.x)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio411
        (y - rect.min.y)*c_stride + ((x/4).to_i - (rect.min.x/4).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio410
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + ((x/4).to_i - (rect.min.x/4).to_i)
      else
        # default to 4:4:4 subsampling
        (y - rect.min.y)*c_stride + (x - rect.min.x)
      end
    end

    # sub_image returns an image representing the portion of the image visible though r.
    # the returned value shares pixes with the original image.
    def sub_image(r : Rectangle) : Image
      r = r.intersect(@rect)
      # if r1 and r2 are Rectangles, r1.intersect(r2) is not guranteed to be inside
      # either r1 or r2 if the intersection is empty. Without explicitly checking for this
      # the pix[i..] expression can raise exception
      return YCbCr.new(sub_sample_ratio: @sub_sample_ratio) if r.empty

      yi = y_offset(r.min.x, r.min.y)
      ci = c_offset(r.min.x, r.min.y)
      YCbCr.new(
        y[yi..],
        cb[ci..],
        cr[ci..],
        y_stride,
        c_stride,
        sub_sample_ratio,
        r)
    end

    def opaque? : Bool
      true
    end
  end

  # NYCbCrA is an in-memory image using Y'CbCr color space with alpha channel.
  #
  # Similar to YCbCr but includes an alpha channel for transparency.
  # The alpha values are non-premultiplied, meaning color values are independent
  # of the alpha value.
  #
  # Example:
  # ```
  # img = CrImage::NYCbCrA.new(
  #   CrImage.rect(0, 0, 640, 480),
  #   CrImage::YCbCrSubSampleRatio::YCbCrSubsampleRatio420
  # )
  # ```
  class NYCbCrA
    include Image
    property y : Bytes
    property cb : Bytes
    property cr : Bytes
    property a : Bytes
    property y_stride : Int32
    property c_stride : Int32
    property a_stride : Int32
    property sub_sample_ratio : YCbCrSubSampleRatio
    property rect : Rectangle

    def initialize(@y = Bytes.empty, @cb = Bytes.empty, @cr = Bytes.empty, @a = Bytes.empty,
                   @y_stride = 0, @c_stride = 0, @a_stride = 0,
                   @sub_sample_ratio = YCbCrSubSampleRatio::YCbCrSubsampleRatio444,
                   @rect = Rectangle.zero)
    end

    def initialize(@rect : Rectangle, @sub_sample_ratio : YCbCrSubSampleRatio)
      w, h, cw, ch = CrImage.ycbcr_size(rect, sub_sample_ratio)

      i0 = 1*w*h + 0*cw*ch
      i1 = 1*w*h + 1*cw*ch
      i2 = 1*w*h + 2*cw*ch
      i3 = 2*w*h + 2*cw*ch
      b = Bytes.new(i3)

      @y = b[..i0]
      @cb = b[i0...i1]
      @cr = b[i1...i2]
      @a = b[i2..]
      @y_stride = w
      @c_stride = cw
      @a_stride = w
    end

    def color_model : Color::Model
      Color.nycbcra_model
    end

    def bounds : Rectangle
      @rect
    end

    def at(x : Int32, y : Int32) : Color::Color
      nycbcra_at(x, y)
    end

    def set(x : Int32, y : Int32, c : Color::Color)
      return unless Point.new(x, y).in(@rect)

      # Convert to NYCbCrA if needed
      nycbcra = c.is_a?(Color::NYCbCrA) ? c : Color.nycbcra_model.convert(c).as(Color::NYCbCrA)
      set_nycbcra(x, y, nycbcra)
    end

    def set_nycbcra(x : Int32, y : Int32, c : Color::NYCbCrA)
      return unless Point.new(x, y).in(@rect)

      yi = y_offset(x, y)
      ci = c_offset(x, y)
      ai = a_offset(x, y)

      @y[yi] = c.y
      @cb[ci] = c.cb
      @cr[ci] = c.cr
      @a[ai] = c.a
    end

    def nycbcra_at(x : Int32, y : Int32) : Color::Color
      return Color::NYCbCrA.new(0, 0, 0, 0) unless Point.new(x, y).in(@rect)
      yi = y_offset(x, y)
      ci = c_offset(x, y)
      ai = a_offset(x, y)
      Color::NYCbCrA.new(@y[yi], cb[ci], cr[ci], a[ai])
    end

    # returns the index of the first element of Y that corresponds to the pixel at (x,y)
    def y_offset(x, y)
      (y - rect.min.y)*y_stride + (x - rect.min.x)
    end

    # returns the index of the first element of cb or cr that corresponds to the pixel at (x,y)
    def c_offset(x, y)
      case sub_sample_ratio
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio422
        (y - rect.min.y)*c_stride + ((x/2).to_i - (rect.min.x/2).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio420
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + ((x/2).to_i - (rect.min.x/2).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio440
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + (x - rect.min.x)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio411
        (y - rect.min.y)*c_stride + ((x/4).to_i - (rect.min.x/4).to_i)
      when YCbCrSubSampleRatio::YCbCrSubsampleRatio410
        ((y/2).to_i - (rect.min.y/2).to_i)*c_stride + ((x/4).to_i - (rect.min.x/4).to_i)
      else
        # default to 4:4:4 subsampling
        (y - rect.min.y)*c_stride + (x - rect.min.x)
      end
    end

    # returns the index of the first element of a that corresponds to the pixel at (x,y)
    def a_offset(x, y)
      (y - rect.min.y)*a_stride + (x - rect.min.x)
    end

    # sub_image returns an image representing the portion of the image visible though r.
    # the returned value shares pixes with the original image.
    def sub_image(r : Rectangle) : Image
      r = r.intersect(@rect)
      # if r1 and r2 are Rectangles, r1.intersect(r2) is not guranteed to be inside
      # either r1 or r2 if the intersection is empty. Without explicitly checking for this
      # the pix[i..] expression can raise exception
      return NYCbCrA.new(sub_sample_ratio: @sub_sample_ratio) if r.empty

      yi = y_offset(r.min.x, r.min.y)
      ci = c_offset(r.min.x, r.min.y)
      ai = a_offset(r.min.x, r.min.y)

      NYCbCrA.new(
        y[yi..],
        cb[ci..],
        cr[ci..],
        a[ai..],
        sub_sample_ratio,
        y_stride,
        c_stride,
        a_stride,
        r)
    end

    def opaque? : Bool
      return true if rect.empty
      i0, i1 = 0, rect.width
      rect.min.y.upto(rect.max.y - 1) do |_|
        a[i0...i1].each do |alpha|
          return false unless alpha == 0xff
        end
        i0 += a_stride
        i1 += a_stride
      end
      true
    end
  end

  def self.ycbcr_size(r : Rectangle, sub_sample_ratio : YCbCrSubSampleRatio) : {Int32, Int32, Int32, Int32}
    w, h = r.width, r.height
    case sub_sample_ratio
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio422
      cw = ((r.max.x + 1)/2).to_i - (r.min.x/2).to_i
      ch = h
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio420
      cw = ((r.max.x + 1)/2).to_i - (r.min.x/2).to_i
      ch = ((r.max.y + 1)/2).to_i - (r.min.y/2).to_i
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio440
      cw = w
      ch = ((r.max.y + 1)/2).to_i - (r.min.y/2).to_i
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio411
      cw = ((r.max.x + 3)/4).to_i - (r.min.x/4).to_i
      ch = h
    when YCbCrSubSampleRatio::YCbCrSubsampleRatio410
      cw = ((r.max.x + 3)/4).to_i - (r.min.x/4).to_i
      ch = ((r.max.y + 1)/2).to_i - (r.min.y/2).to_i
    else
      # default to 4:4:4 subsampling
      cw = w
      ch = h
    end
    {w, h, cw, ch}
  end
end
