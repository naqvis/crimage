module CrImage
  # Pipeline provides a fluent API for chaining image operations.
  #
  # Allows building complex image processing workflows in a readable,
  # chainable manner without intermediate variables.
  #
  # Example:
  # ```
  # result = CrImage::Pipeline.new(img)
  #   .resize(800, 600)
  #   .brightness(1.2)
  #   .contrast(1.1)
  #   .blur(2)
  #   .result
  # ```
  class Pipeline
    @image : RGBA

    def initialize(source : Image)
      @image = image_to_rgba(source)
    end

    private def image_to_rgba(src : Image) : RGBA
      bounds = src.bounds
      dst = RGBA.new(CrImage.rect(0, 0, bounds.width, bounds.height))

      bounds.height.times do |y|
        bounds.width.times do |x|
          pixel = src.at(x + bounds.min.x, y + bounds.min.y)
          r, g, b, a = pixel.rgba
          dst.set(x, y, Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8))
        end
      end

      dst
    end

    # Returns the final processed image.
    def result : RGBA
      @image
    end

    # Alias for result
    def to_image : RGBA
      @image
    end

    # Resize the image.
    def resize(width : Int32, height : Int32, method : Symbol = :bilinear) : self
      @image = @image.resize(width, height, method: method)
      self
    end

    # Scale the image by a factor.
    def scale(factor : Float64, method : Symbol = :bilinear) : self
      new_width = (@image.bounds.width * factor).to_i
      new_height = (@image.bounds.height * factor).to_i
      @image = @image.resize(new_width, new_height, method: method)
      self
    end

    # Crop the image.
    def crop(x : Int32, y : Int32, width : Int32, height : Int32) : self
      sub = @image.sub_image(CrImage.rect(x, y, x + width, y + height))
      @image = image_to_rgba(sub)
      self
    end

    # Rotate the image by 90 degree increments.
    def rotate(degrees : Int32) : self
      case degrees % 360
      when 90, -270
        @image = @image.rotate_90
      when 180, -180
        @image = @image.rotate_180
      when 270, -90
        @image = @image.rotate_270
      end
      self
    end

    # Flip horizontally.
    def flip_horizontal : self
      @image = @image.flip_horizontal
      self
    end

    # Flip vertically.
    def flip_vertical : self
      @image = @image.flip_vertical
      self
    end

    # Adjust brightness (adjustment is added to each channel, -255 to 255).
    def brightness(adjustment : Int32) : self
      @image = @image.brightness(adjustment).as(RGBA)
      self
    end

    # Adjust contrast (factor 0.0 to 2.0, where 1.0 is no change).
    def contrast(factor : Float64) : self
      @image = @image.contrast(factor).as(RGBA)
      self
    end

    # Convert to grayscale.
    def grayscale : self
      gray = @image.grayscale
      @image = image_to_rgba(gray)
      self
    end

    # Invert colors.
    def invert : self
      @image = @image.invert
      self
    end

    # Apply Gaussian blur.
    def blur(radius : Int32 = 3) : self
      @image = @image.blur_gaussian(radius: radius)
      self
    end

    # Apply box blur.
    def blur_box(radius : Int32 = 3) : self
      @image = @image.blur_box(radius: radius)
      self
    end

    # Apply sharpening.
    def sharpen(amount : Float64 = 1.0) : self
      @image = @image.sharpen(amount: amount)
      self
    end

    # Apply edge detection.
    def edge_detect(method : Symbol = :sobel) : self
      @image = @image.edge_detect(method: method)
      self
    end

    # Add border.
    def border(width : Int32, color : Color::Color = Color::WHITE) : self
      @image = @image.add_border(width, color)
      self
    end

    # Round corners.
    def round_corners(radius : Int32) : self
      @image = @image.round_corners(radius)
      self
    end

    # Apply sepia effect.
    def sepia : self
      @image = @image.sepia
      self
    end

    # Apply vignette effect.
    def vignette(strength : Float64 = 0.5) : self
      @image = @image.vignette(strength: strength)
      self
    end

    # Adjust saturation.
    def saturate(factor : Float64) : self
      @image = @image.saturate(factor)
      self
    end

    # Apply emboss effect.
    def emboss(angle : Float64 = 135.0, depth : Float64 = 1.0) : self
      @image = @image.emboss(angle: angle, depth: depth)
      self
    end

    # Adjust color temperature.
    def temperature(adjustment : Int32) : self
      @image = @image.temperature(adjustment)
      self
    end

    # Apply custom operation via block.
    def apply(&block : RGBA -> RGBA) : self
      @image = yield @image
      self
    end

    # Draw a filled rectangle.
    def draw_rect(x : Int32, y : Int32, width : Int32, height : Int32, color : Color::Color) : self
      style = Draw::RectStyle.new(fill_color: color)
      Draw.rectangle(@image, CrImage.rect(x, y, x + width, y + height), style)
      self
    end

    # Draw a circle.
    def draw_circle(cx : Int32, cy : Int32, radius : Int32, color : Color::Color, fill : Bool = true) : self
      style = Draw::CircleStyle.new(color, fill: fill)
      Draw.circle(@image, Point.new(cx, cy), radius, style)
      self
    end

    # Draw a line.
    def draw_line(x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32, color : Color::Color, thickness : Int32 = 1) : self
      style = Draw::LineStyle.new(color, thickness: thickness)
      Draw.line(@image, Point.new(x1, y1), Point.new(x2, y2), style)
      self
    end

    # Draw a dashed line.
    def draw_dashed_line(x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32, color : Color::Color, dash : Int32 = 5, gap : Int32 = 3) : self
      style = Draw::DashedLineStyle.new(color, dash_length: dash, gap_length: gap)
      Draw.dashed_line(@image, Point.new(x1, y1), Point.new(x2, y2), style)
      self
    end

    # Draw a rounded rectangle.
    def draw_rounded_rect(x : Int32, y : Int32, width : Int32, height : Int32, color : Color::Color, corner_radius : Int32) : self
      style = Draw::RectStyle.new(fill_color: color, corner_radius: corner_radius)
      Draw.rectangle(@image, CrImage.rect(x, y, x + width, y + height), style)
      self
    end

    # Draw a regular polygon.
    def draw_polygon(cx : Int32, cy : Int32, radius : Int32, sides : Int32, color : Color::Color, fill : Bool = true) : self
      style = if fill
                Draw::PolygonStyle.new(fill_color: color)
              else
                Draw::PolygonStyle.new(outline_color: color)
              end
      Draw.regular_polygon(@image, Point.new(cx, cy), radius, sides, style)
      self
    end

    # Draw a bezier curve.
    def draw_bezier(x1 : Int32, y1 : Int32, cx : Int32, cy : Int32, x2 : Int32, y2 : Int32, color : Color::Color, thickness : Int32 = 1) : self
      style = Draw::BezierStyle.new(color, thickness: thickness)
      Draw.quadratic_bezier(@image, Point.new(x1, y1), Point.new(cx, cy), Point.new(x2, y2), style)
      self
    end

    # Save to file.
    def save(path : String, quality : Int32 = 90) : self
      ext = File.extname(path).downcase
      case ext
      when ".png"
        PNG.write(path, @image)
      when ".jpg", ".jpeg"
        JPEG.write(path, @image, quality)
      when ".bmp"
        BMP.write(path, @image)
      when ".gif"
        GIF.write(path, @image)
      when ".webp"
        WEBP.write(path, @image, quality: quality)
      else
        PNG.write(path, @image)
      end
      self
    end
  end

  module Image
    # Creates a pipeline for fluent image processing.
    def pipeline : Pipeline
      Pipeline.new(self)
    end
  end
end
