module CrImage
  # Paletted is an in-memory indexed color image.
  #
  # Each pixel is stored as a single byte index (0-255) into a color palette.
  # This format is memory-efficient for images with limited colors (e.g., GIF).
  #
  # Memory layout: Contiguous byte array with 1 byte per pixel (palette index)
  # Color model: Palette (up to 256 colors)
  #
  # Use Paletted for:
  # - GIF images (256 colors max)
  # - Images with limited color palettes
  # - Reducing file size through color quantization
  #
  # Example:
  # ```
  # palette = CrImage::Color::Palette.new([
  #   CrImage::Color::RED,
  #   CrImage::Color::GREEN,
  #   CrImage::Color::BLUE,
  # ])
  # img = CrImage::Paletted.new(CrImage.rect(0, 0, 640, 480), palette)
  # img.set_color_index(100, 100, 0_u8) # Set to first palette color
  # ```
  class Paletted
    include PalettedImage
    @pix : Bytes
    # Stride is the pixel buffer stride (in bytes) between vertically adjacent pixels.
    getter stride : Int32
    # Rectangle defining the image's bounds.
    getter rect : Rectangle
    # Color palette containing up to 256 colors.
    getter palette : Color::Palette

    # Returns a read-only view of the pixel buffer
    # Modifying the returned Bytes directly is unsafe and may break image invariants
    # Use at()/set() methods for safe pixel manipulation
    # :nodoc:
    def pix : Bytes
      @pix
    end

    def initialize
      @pix = Bytes.empty
      @stride = 0
      @rect = Rectangle.zero
      @palette = Color::Palette.new
    end

    def initialize(@rect = Rectangle.zero, @palette = Color::Palette.new)
      SafeMath.validate_rectangle(@rect)
      w, h = @rect.width, @rect.height
      buffer_size = SafeMath.safe_buffer_size(w, h, 1)
      @pix = Bytes.new(buffer_size.to_i32)
      @stride = SafeMath.safe_stride(w, 1)
    end

    def initialize(@pix, @stride, @rect, @palette)
    end

    def color_model : Color::Model
      @palette.as(Color::Model)
    end

    def bounds : Rectangle
      @rect
    end

    def at(x : Int32, y : Int32) : Color::Color
      return Color::BLACK if @palette.size == 0
      return @palette[0] unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      @palette[@pix[i]]
    end

    def pixel_offset(x : Int32, y : Int32) : Int32
      dy = y - @rect.min.y
      dx = x - @rect.min.x
      (dy.to_i64 * @stride.to_i64 + dx.to_i64).to_i32
    end

    def set(x : Int32, y : Int32, c : Color::Color)
      return unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      @pix[i] = (@palette.index(c)).to_u8
    end

    def color_index_at(x : Int32, y : Int32) : UInt8
      return 0_u8 unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      @pix[i]
    end

    def set_color_index(x : Int32, y : Int32, index : UInt8)
      return unless Point.new(x, y).in(@rect)
      i = pixel_offset(x, y)
      @pix[i] = index
    end

    # sub_image returns an image representing the portion of the image visible though r.
    # the returned value shares pixes with the original image.
    def sub_image(r : Rectangle) : Image
      r = r.intersect(@rect)
      # if r1 and r2 are Rectangles, r1.intersect(r2) is not guranteed to be inside
      # either r1 or r2 if the intersection is empty. Without explicitly checking for this
      # the pix[i..] expression can raise exception
      return Paletted.new(palette: @palette) if r.empty
      i = pixel_offset(r.min.x, r.min.y)
      Paletted.new(@pix[i..], @stride, r, @palette)
    end

    # opaque scans the entire image and reports whether it is fully opaque
    def opaque? : Bool
      present = Array(Bool).new(256, false)
      i0, i1 = 0, @rect.width
      y = @rect.min.y
      while y < @rect.max.y
        @pix[i0...i1].each do |color_idx|
          present[color_idx] = true
        end
        i0 += @stride
        i1 += @stride
        y += 1
      end

      @palette.each_with_index do |color, idx|
        next unless present[idx]
        _, _, _, a = color.rgba
        return false unless a == Color::MAX_32BIT
      end
      true
    end

    def_equals_and_hash @pix, @stride, @rect, @palette
  end
end
