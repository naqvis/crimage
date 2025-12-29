# CrImage is a comprehensive 2D image processing library for Crystal.
#
# Provides support for reading, writing, and manipulating images across multiple formats
# (BMP, PNG, JPEG, GIF, TIFF, WebP, ICO) with no external dependencies.
#
# Example:
# ```
# # Create and manipulate images
# img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
# img.draw_circle(200, 150, 50, color: CrImage::Color::RED, fill: true)
# CrImage::PNG.write("output.png", img)
#
# # Read and transform images
# img = CrImage.read("input.png")
# resized = img.resize(800, 600, method: :bilinear)
# CrImage::JPEG.write("output.jpg", resized, 85)
# ```
module CrImage
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

  # Drawing style aliases for convenience
  alias LineStyle = Draw::LineStyle
  alias CircleStyle = Draw::CircleStyle
  alias PolygonStyle = Draw::PolygonStyle
  alias Path = Draw::Path
  alias PathStyle = Draw::PathStyle

  # Creates a new RGBA image.
  #
  # Factory method for creating RGBA images with less verbosity.
  # RGBA uses premultiplied alpha for efficient compositing.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `RGBA` image with transparent black pixels
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # # Instead of: CrImage::RGBA.new(CrImage.rect(0, 0, 400, 300))
  # ```
  def self.rgba(width : Int32, height : Int32) : RGBA
    RGBA.new(rect(0, 0, width, height))
  end

  # Creates a new NRGBA (non-premultiplied alpha) image.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `NRGBA` image
  def self.nrgba(width : Int32, height : Int32) : NRGBA
    NRGBA.new(rect(0, 0, width, height))
  end

  # Creates a new 8-bit grayscale image.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `Gray` image
  def self.gray(width : Int32, height : Int32) : Gray
    Gray.new(rect(0, 0, width, height))
  end

  # Creates a new 16-bit grayscale image.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `Gray16` image
  def self.gray16(width : Int32, height : Int32) : Gray16
    Gray16.new(rect(0, 0, width, height))
  end

  # Creates a new 64-bit RGBA image (16 bits per channel).
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `RGBA64` image
  def self.rgba64(width : Int32, height : Int32) : RGBA64
    RGBA64.new(rect(0, 0, width, height))
  end

  # Creates a new 64-bit NRGBA image (16 bits per channel, non-premultiplied).
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  #
  # Returns: A new `NRGBA64` image
  def self.nrgba64(width : Int32, height : Int32) : NRGBA64
    NRGBA64.new(rect(0, 0, width, height))
  end

  # Creates a new paletted (indexed color) image.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  # - `palette` : Color palette for the image
  #
  # Returns: A new `Paletted` image
  def self.paletted(width : Int32, height : Int32, palette : Color::Palette) : Paletted
    Paletted.new(rect(0, 0, width, height), palette)
  end

  # Creates a new RGBA image filled with the specified color.
  #
  # Convenience method for creating an image with a solid background color.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  # - `fill_color` : Color to fill the entire image with
  #
  # Returns: A new `RGBA` image filled with the specified color
  #
  # Example:
  # ```
  # # White background
  # img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
  # # Or with custom color
  # img = CrImage.rgba(400, 300, CrImage::Color.rgb(200, 220, 240))
  # ```
  def self.rgba(width : Int32, height : Int32, fill_color : Color::Color) : RGBA
    img = rgba(width, height)
    img.fill(fill_color)
    img
  end

  # Creates a new NRGBA image filled with the specified color.
  #
  # Parameters:
  # - `width` : Image width in pixels
  # - `height` : Image height in pixels
  # - `fill_color` : Color to fill the image with
  #
  # Returns: A new `NRGBA` image filled with the color
  def self.nrgba(width : Int32, height : Int32, fill_color : Color::Color) : NRGBA
    img = nrgba(width, height)
    img.fill(fill_color)
    img
  end

  # Creates a Point from a tuple.
  #
  # Parameters:
  # - `tuple` : A tuple of (x, y) coordinates
  #
  # Returns: A new `Point`
  def self.point(tuple : {Int32, Int32}) : Point
    Point.new(tuple[0], tuple[1])
  end

  # Creates a Point from x and y coordinates.
  #
  # Parameters:
  # - `x` : X coordinate
  # - `y` : Y coordinate
  #
  # Returns: A new `Point`
  def self.point(x : Int32, y : Int32) : Point
    Point.new(x, y)
  end

  # Creates a Rectangle from coordinates.
  #
  # Parameters:
  # - `x1` : Left X coordinate
  # - `y1` : Top Y coordinate
  # - `x2` : Right X coordinate
  # - `y2` : Bottom Y coordinate
  #
  # Returns: A new `Rectangle`
  def self.rect(x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32) : Rectangle
    Rectangle.new(Point.new(x1, y1), Point.new(x2, y2))
  end

  # Reads an image from a file, auto-detecting format.
  #
  # Supports PNG, JPEG, GIF, BMP, TIFF, WebP, and ICO formats.
  #
  # Parameters:
  # - `path` : Path to the image file
  #
  # Returns: The loaded image
  #
  # Raises: `Error` if format is unsupported or file cannot be read
  #
  # Example:
  # ```
  # img = CrImage.read("photo.jpg")
  # ```
  def self.read(path : String) : Image
    ext = File.extname(path).downcase
    case ext
    when ".png"
      PNG.read(path)
    when ".jpg", ".jpeg"
      JPEG.read(path)
    when ".gif"
      GIF.read(path)
    when ".bmp"
      BMP.read(path)
    when ".tiff", ".tif"
      TIFF.read(path)
    when ".webp"
      WEBP.read(path)
    when ".ico"
      ICO.read(path)
    else
      # Try PNG as default
      PNG.read(path)
    end
  end

  # Writes an image to a file, auto-detecting format from extension.
  #
  # Parameters:
  # - `path` : Output file path
  # - `img` : Image to write
  # - `quality` : Quality for lossy formats (default: 90)
  #
  # Example:
  # ```
  # CrImage.write("output.png", img)
  # CrImage.write("output.jpg", img, quality: 85)
  # ```
  def self.write(path : String, img : Image, quality : Int32 = 90)
    ext = File.extname(path).downcase
    case ext
    when ".png"
      PNG.write(path, img)
    when ".jpg", ".jpeg"
      JPEG.write(path, img, quality)
    when ".gif"
      GIF.write(path, img)
    when ".bmp"
      BMP.write(path, img)
    when ".tiff", ".tif"
      TIFF.write(path, img)
    when ".webp"
      WEBP.write(path, img)
    else
      PNG.write(path, img)
    end
  end

  # Writes an image to a IO, auto-detecting format from extension.
  #
  # Parameters:
  # - `io` : Output IO
  # - `img` : Image to write
  #
  # Example:
  # ```
  # CrImage.write("output.png", img)
  # CrImage.write("output.jpg", img)
  # ```
  def self.write(io : IO, img : Image, ext : String = ".png")
    ext = ext.downcase
    case ext
    when ".png"
      PNG.write(io, img)
    when ".jpg", ".jpeg"
      JPEG.write(io, img)
    when ".gif"
      GIF.write(io, img)
    when ".bmp"
      BMP.write(io, img)
    when ".tiff", ".tif"
      TIFF.write(io, img)
    when ".webp"
      WEBP.write(io, img)
    else
      PNG.write(io, img)
    end
  end

  # Creates a checkerboard pattern image.
  #
  # Useful for transparency backgrounds or testing.
  #
  # Parameters:
  # - `width` : Image width
  # - `height` : Image height
  # - `cell_size` : Size of each checker cell (default: 8)
  # - `color1` : First color (default: light gray)
  # - `color2` : Second color (default: white)
  #
  # Returns: RGBA image with checkerboard pattern
  def self.checkerboard(width : Int32, height : Int32,
                        cell_size : Int32 = 8,
                        color1 : Color::Color = Color::RGBA.new(204_u8, 204_u8, 204_u8, 255_u8),
                        color2 : Color::Color = Color::WHITE) : RGBA
    img = rgba(width, height)
    height.times do |y|
      width.times do |x|
        checker = ((x // cell_size) + (y // cell_size)) % 2 == 0
        img.set(x, y, checker ? color1 : color2)
      end
    end
    img
  end

  # Creates a gradient image.
  #
  # Parameters:
  # - `width` : Image width
  # - `height` : Image height
  # - `start_color` : Color at the start
  # - `end_color` : Color at the end
  # - `direction` : Gradient direction (:horizontal, :vertical, :diagonal)
  #
  # Returns: RGBA image with gradient
  def self.gradient(width : Int32, height : Int32,
                    start_color : Color::Color,
                    end_color : Color::Color,
                    direction : Symbol = :horizontal) : RGBA
    img = rgba(width, height)
    sr, sg, sb, sa = start_color.rgba
    er, eg, eb, ea = end_color.rgba

    # Convert to Float64 for safe interpolation
    sr_f = (sr >> 8).to_f64
    sg_f = (sg >> 8).to_f64
    sb_f = (sb >> 8).to_f64
    sa_f = (sa >> 8).to_f64
    er_f = (er >> 8).to_f64
    eg_f = (eg >> 8).to_f64
    eb_f = (eb >> 8).to_f64
    ea_f = (ea >> 8).to_f64

    max_x = [width - 1, 1].max.to_f64
    max_y = [height - 1, 1].max.to_f64
    max_diag = [width + height - 2, 1].max.to_f64

    height.times do |y|
      width.times do |x|
        t = case direction
            when :horizontal then x.to_f64 / max_x
            when :vertical   then y.to_f64 / max_y
            when :diagonal   then (x + y).to_f64 / max_diag
            else                  x.to_f64 / max_x
            end

        r = (sr_f + (er_f - sr_f) * t).clamp(0.0, 255.0).to_u8
        g = (sg_f + (eg_f - sg_f) * t).clamp(0.0, 255.0).to_u8
        b = (sb_f + (eb_f - sb_f) * t).clamp(0.0, 255.0).to_u8
        a = (sa_f + (ea_f - sa_f) * t).clamp(0.0, 255.0).to_u8

        img.set(x, y, Color::RGBA.new(r, g, b, a))
      end
    end
    img
  end

  # Generates a QR code image from text, optionally with a logo overlay.
  #
  # Parameters:
  # - `data` : Text to encode
  # - `size` : Target image size in pixels (default: 300)
  # - `error_correction` : Error correction level (default: :medium, or :high if logo provided)
  # - `margin` : Quiet zone in modules (default: 4)
  # - `logo` : Optional logo image to overlay in center
  # - `logo_scale` : Logo size as fraction of QR size (default: 0.2 = 20%)
  # - `logo_border` : White border around logo in pixels (default: 4)
  #
  # Returns: RGBA image containing the QR code
  #
  # Example:
  # ```
  # # Simple QR code
  # qr = CrImage.qr_code("https://example.com")
  #
  # # With options
  # qr = CrImage.qr_code("Hello", size: 400, error_correction: :high)
  #
  # # With logo overlay
  # logo = CrImage::PNG.read("logo.png")
  # qr = CrImage.qr_code("https://example.com", logo: logo)
  # ```
  def self.qr_code(data : String, size : Int32 = 300,
                   error_correction : Symbol? = nil,
                   margin : Int32 = 4,
                   logo : Image? = nil,
                   logo_scale : Float64 = 0.2,
                   logo_border : Int32 = 4) : RGBA
    # Default to :high EC when logo is provided, :medium otherwise
    ec_sym = error_correction || (logo ? :high : :medium)
    ec = case ec_sym
         when :low      then Util::QRCode::ErrorCorrection::Low
         when :medium   then Util::QRCode::ErrorCorrection::Medium
         when :quartile then Util::QRCode::ErrorCorrection::Quartile
         when :high     then Util::QRCode::ErrorCorrection::High
         else                Util::QRCode::ErrorCorrection::Medium
         end

    if logo
      Util::QRCode.generate_with_logo(data, logo, size, ec, margin,
        Color::BLACK, Color::WHITE, logo_scale, logo_border)
    else
      Util::QRCode.generate(data, size, ec, margin)
    end
  end
end

require "./crimage/**"
