module CrImage
  module Image
    # Fills the entire image with a solid color.
    #
    # Example:
    # ```
    # img = CrImage.rgba(400, 300)
    # img.fill(CrImage::Color::WHITE)
    # ```
    def fill(color : Color::Color) : self
      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          set(x, y, color)
        end
      end
      self
    end

    # Clears the image by filling it with transparent color.
    #
    # Example:
    # ```
    # img.clear
    # ```
    def clear : self
      fill(Color::TRANSPARENT)
    end

    # Iterates over each pixel with coordinates and color value.
    #
    # Example:
    # ```
    # img.each_pixel do |x, y, color|
    #   puts "Pixel at (#{x},#{y}): #{color}"
    # end
    # ```
    def each_pixel(&block : Int32, Int32, Color::Color ->)
      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          yield x, y, at(x, y)
        end
      end
    end

    # Iterates over each pixel coordinate.
    #
    # Example:
    # ```
    # img.each_coordinate do |x, y|
    #   img.set(x, y, CrImage::Color::RED)
    # end
    # ```
    def each_coordinate(&block : Int32, Int32 ->)
      bounds.min.y.upto(bounds.max.y - 1) do |y|
        bounds.min.x.upto(bounds.max.x - 1) do |x|
          yield x, y
        end
      end
    end

    # Resizes the image to the specified dimensions.
    #
    # Available methods:
    # - `:nearest` - Fast, pixelated (nearest neighbor)
    # - `:bilinear` - Good quality, smooth (default)
    # - `:bicubic` - High quality, very smooth
    # - `:lanczos` - Highest quality, sharpest
    #
    # Example:
    # ```
    # resized = img.resize(800, 600)
    # high_quality = img.resize(800, 600, method: :lanczos)
    # ```
    def resize(width : Int32, height : Int32, method : Symbol = :bilinear) : CrImage::Image
      case method
      when :nearest
        Transform.resize_nearest(self, width, height)
      when :bilinear
        Transform.resize_bilinear(self, width, height)
      when :bicubic
        Transform.resize_bicubic(self, width, height)
      when :lanczos
        Transform.resize_lanczos(self, width, height)
      else
        raise ArgumentError.new("Unknown resize method: #{method}. Use :nearest, :bilinear, :bicubic, or :lanczos")
      end
    end

    # Applies box blur filter to the image.
    #
    # Parameters:
    # - `radius` : Blur radius in pixels (default: 2)
    #
    # Example:
    # ```
    # blurred = img.blur(radius: 3)
    # ```
    def blur(radius : Int32 = 2) : CrImage::Image
      Transform.blur_box(self, radius)
    end

    # Applies Gaussian blur filter for natural-looking blur.
    #
    # Parameters:
    # - `radius` : Blur radius in pixels (default: 5)
    # - `sigma` : Standard deviation (auto-calculated if nil)
    #
    # Example:
    # ```
    # blurred = img.blur_gaussian(radius: 5)
    # custom = img.blur_gaussian(radius: 5, sigma: 2.0)
    # ```
    def blur_gaussian(radius : Int32 = 5, sigma : Float64? = nil) : CrImage::Image
      Transform.blur_gaussian(self, radius, sigma)
    end

    # Sharpens the image by enhancing edges.
    #
    # Parameters:
    # - `amount` : Sharpening strength (default: 1.0, range: 0.0-2.0)
    #
    # Example:
    # ```
    # sharpened = img.sharpen(amount: 1.5)
    # ```
    def sharpen(amount : Float64 = 1.0) : CrImage::Image
      Transform.sharpen(self, amount)
    end

    # Adjusts image brightness.
    #
    # Parameters:
    # - `adjustment` : Brightness change (-255 to 255, negative darkens, positive brightens)
    #
    # Example:
    # ```
    # brighter = img.brightness(50)
    # darker = img.brightness(-50)
    # ```
    def brightness(adjustment : Int32) : CrImage::Image
      Transform.brightness(self, adjustment)
    end

    # Adjusts image contrast.
    #
    # Parameters:
    # - `factor` : Contrast multiplier (< 1.0 decreases, > 1.0 increases, 1.0 = no change)
    #
    # Example:
    # ```
    # high_contrast = img.contrast(1.5)
    # low_contrast = img.contrast(0.5)
    # ```
    def contrast(factor : Float64) : CrImage::Image
      Transform.contrast(self, factor)
    end

    # Converts the image to grayscale.
    #
    # Example:
    # ```
    # gray = img.grayscale
    # ```
    def grayscale : CrImage::Image
      Transform.grayscale(self)
    end

    # Inverts all colors in the image (negative).
    #
    # Example:
    # ```
    # negative = img.invert
    # ```
    def invert : CrImage::Image
      Transform.invert(self)
    end

    # Applies box blur in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    # More memory-efficient than creating a new image.
    #
    # Parameters:
    # - `radius` : Blur radius in pixels (default: 2)
    #
    # Example:
    # ```
    # img.blur!(radius: 3).sharpen!(1.2)
    # ```
    def blur!(radius : Int32 = 2) : self
      Transform.blur!(self, radius)
      self
    end

    # Applies Gaussian blur in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    #
    # Example:
    # ```
    # img.blur_gaussian!(radius: 5, sigma: 2.0)
    # ```
    def blur_gaussian!(radius : Int32 = 5, sigma : Float64? = nil) : self
      Transform.blur_gaussian!(self, radius, sigma)
      self
    end

    # Sharpens the image in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    def sharpen!(amount : Float64 = 1.0) : self
      Transform.sharpen!(self, amount)
      self
    end

    # Adjusts brightness in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    def brightness!(adjustment : Int32) : self
      Transform.brightness!(self, adjustment)
      self
    end

    # Adjusts contrast in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    def contrast!(factor : Float64) : self
      Transform.contrast!(self, factor)
      self
    end

    # Inverts colors in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    def invert! : self
      Transform.invert!(self)
      self
    end

    # Converts to grayscale in-place (modifies the image directly).
    #
    # Only works on RGBA images. Returns self for method chaining.
    def grayscale! : self
      Transform.grayscale!(self)
      self
    end

    # Rotates the image 90 degrees clockwise.
    #
    # Example:
    # ```
    # rotated = img.rotate_90
    # ```
    def rotate_90 : CrImage::Image
      Transform.rotate_90(self)
    end

    # Rotates the image 180 degrees.
    #
    # Example:
    # ```
    # rotated = img.rotate_180
    # ```
    def rotate_180 : CrImage::Image
      Transform.rotate_180(self)
    end

    # Rotates the image 270 degrees clockwise (90 degrees counter-clockwise).
    #
    # Example:
    # ```
    # rotated = img.rotate_270
    # ```
    def rotate_270 : CrImage::Image
      Transform.rotate_270(self)
    end

    # Rotates the image by the specified degrees (90, 180, or 270 only).
    #
    # For arbitrary angle rotation, see `Transform.rotate(angle)`.
    #
    # Parameters:
    # - `degrees` : Rotation angle (must be 0, 90, 180, or 270)
    #
    # Example:
    # ```
    # rotated = img.rotate(90)
    # ```
    def rotate(degrees : Int32) : CrImage::Image
      case degrees % 360
      when 90, -270
        rotate_90
      when 180, -180
        rotate_180
      when 270, -90
        rotate_270
      when 0
        self
      else
        raise ArgumentError.new("Only 90, 180, 270 degree rotations supported. Got: #{degrees}")
      end
    end

    # Flips the image horizontally (mirror left-right).
    #
    # Example:
    # ```
    # flipped = img.flip_horizontal
    # ```
    def flip_horizontal : CrImage::Image
      Transform.flip_horizontal(self)
    end

    # Flips the image vertically (mirror top-bottom).
    #
    # Example:
    # ```
    # flipped = img.flip_vertical
    # ```
    def flip_vertical : CrImage::Image
      Transform.flip_vertical(self)
    end

    # Crops the image to the specified rectangle.
    #
    # Parameters:
    # - `rect` : Rectangle defining the crop area
    #
    # Example:
    # ```
    # cropped = img.crop(CrImage.rect(10, 10, 100, 100))
    # ```
    def crop(rect : Rectangle) : CrImage::Image
      Transform.crop(self, rect)
    end

    # Crops the image to the specified region.
    #
    # Parameters:
    # - `x` : Left edge of crop area
    # - `y` : Top edge of crop area
    # - `width` : Width of crop area
    # - `height` : Height of crop area
    #
    # Example:
    # ```
    # cropped = img.crop(10, 10, 200, 150)
    # ```
    def crop(x : Int32, y : Int32, width : Int32, height : Int32) : CrImage::Image
      Transform.crop(self, CrImage.rect(x, y, x + width, y + height))
    end

    # Draws a line on the image.
    #
    # Parameters:
    # - `x0, y0` : Starting point coordinates
    # - `x1, y1` : Ending point coordinates
    # - `color` : Line color (default: black)
    # - `thickness` : Line thickness in pixels (default: 1)
    # - `anti_alias` : Enable anti-aliasing for smooth edges (default: false)
    #
    # Example:
    # ```
    # img.draw_line(10, 10, 100, 100, color: CrImage::Color::RED, thickness: 2)
    # ```
    def draw_line(x0 : Int32, y0 : Int32, x1 : Int32, y1 : Int32,
                  color : Color::Color = Color::BLACK,
                  thickness : Int32 = 1,
                  anti_alias : Bool = false) : self
      style = Draw::LineStyle.new(color, thickness, anti_alias)
      Draw.line(self, Point.new(x0, y0), Point.new(x1, y1), style)
      self
    end

    # Draws a line using tuple coordinates.
    #
    # Example:
    # ```
    # img.draw_line({10, 10}, {100, 100}, color: CrImage::Color::BLUE)
    # ```
    def draw_line(from : {Int32, Int32}, to : {Int32, Int32},
                  color : Color::Color = Color::BLACK,
                  thickness : Int32 = 1,
                  anti_alias : Bool = false) : self
      draw_line(from[0], from[1], to[0], to[1], color, thickness, anti_alias)
    end

    # Draws a circle on the image.
    #
    # Parameters:
    # - `x, y` : Center point coordinates
    # - `radius` : Circle radius in pixels
    # - `color` : Circle color (default: black)
    # - `fill` : Fill the circle (default: false, outline only)
    # - `anti_alias` : Enable anti-aliasing (default: false)
    #
    # Example:
    # ```
    # img.draw_circle(200, 150, 50, color: CrImage::Color::RED, fill: true)
    # ```
    def draw_circle(x : Int32, y : Int32, radius : Int32,
                    color : Color::Color = Color::BLACK,
                    fill : Bool = false,
                    anti_alias : Bool = false) : self
      style = Draw::CircleStyle.new(color, fill, anti_alias)
      Draw.circle(self, Point.new(x, y), radius, style)
      self
    end

    # Draws an ellipse on the image.
    #
    # Parameters:
    # - `x, y` : Center point coordinates
    # - `rx` : Horizontal radius
    # - `ry` : Vertical radius
    # - `color` : Ellipse color (default: black)
    # - `fill` : Fill the ellipse (default: false, outline only)
    # - `anti_alias` : Enable anti-aliasing (default: false)
    #
    # Example:
    # ```
    # img.draw_ellipse(200, 150, 80, 40, color: CrImage::Color::BLUE, fill: true)
    # ```
    def draw_ellipse(x : Int32, y : Int32, rx : Int32, ry : Int32,
                     color : Color::Color = Color::BLACK,
                     fill : Bool = false,
                     anti_alias : Bool = false) : self
      style = Draw::CircleStyle.new(color, fill, anti_alias)
      Draw.ellipse(self, Point.new(x, y), rx, ry, style)
      self
    end

    # Draws a rectangle on the image.
    #
    # Parameters:
    # - `x, y` : Top-left corner coordinates
    # - `width, height` : Rectangle dimensions
    # - `stroke` : Outline color (nil for no outline)
    # - `fill` : Fill color (nil for no fill)
    # - `anti_alias` : Enable anti-aliasing for outline (default: false)
    #
    # Example:
    # ```
    # img.draw_rect(10, 10, 100, 50, stroke: CrImage::Color::BLACK, fill: CrImage::Color::WHITE)
    # ```
    def draw_rect(x : Int32, y : Int32, width : Int32, height : Int32,
                  stroke : Color::Color? = nil,
                  fill : Color::Color? = nil,
                  anti_alias : Bool = false) : self
      rect = CrImage.rect(x, y, x + width, y + height)

      # Fill first if specified
      if fill
        rect.min.y.upto(rect.max.y - 1) do |py|
          rect.min.x.upto(rect.max.x - 1) do |px|
            set(px, py, fill) if Point.new(px, py).in(bounds)
          end
        end
      end

      # Then stroke if specified
      if stroke
        style = Draw::LineStyle.new(stroke, 1, anti_alias)
        # Top
        Draw.line(self, Point.new(x, y), Point.new(x + width - 1, y), style)
        # Right
        Draw.line(self, Point.new(x + width - 1, y), Point.new(x + width - 1, y + height - 1), style)
        # Bottom
        Draw.line(self, Point.new(x + width - 1, y + height - 1), Point.new(x, y + height - 1), style)
        # Left
        Draw.line(self, Point.new(x, y + height - 1), Point.new(x, y), style)
      end

      self
    end

    # Draws a polygon on the image.
    #
    # Parameters:
    # - `points` : Array of points defining the polygon vertices
    # - `outline` : Outline color (nil for no outline)
    # - `fill` : Fill color (nil for no fill)
    # - `anti_alias` : Enable anti-aliasing (default: false)
    #
    # Example:
    # ```
    # points = [
    #   CrImage::Point.new(100, 50),
    #   CrImage::Point.new(150, 150),
    #   CrImage::Point.new(50, 150),
    # ]
    # img.draw_polygon(points, outline: CrImage::Color::BLACK, fill: CrImage::Color::RED)
    # ```
    def draw_polygon(points : Array(Point),
                     outline : Color::Color? = nil,
                     fill : Color::Color? = nil,
                     anti_alias : Bool = false) : self
      style = Draw::PolygonStyle.new(
        outline_color: outline,
        fill_color: fill,
        anti_alias: anti_alias
      )
      Draw.polygon(self, points, style)
      self
    end

    # Detects edges in the image using the specified operator.
    #
    # Parameters:
    # - `operator` : Edge detection algorithm (Sobel, Prewitt, Roberts, Scharr)
    # - `threshold` : Optional threshold for binary edge map (nil for grayscale)
    #
    # Example:
    # ```
    # edges = img.detect_edges(Transform::EdgeOperator::Sobel, threshold: 50)
    # ```
    def detect_edges(operator : Transform::EdgeOperator = Transform::EdgeOperator::Sobel,
                     threshold : Int32? = nil) : CrImage::Image
      Transform.detect_edges(self, operator, threshold)
    end

    # Detects edges using the Sobel operator.
    #
    # Example:
    # ```
    # edges = img.sobel
    # binary_edges = img.sobel(threshold: 50)
    # ```
    def sobel(threshold : Int32? = nil) : CrImage::Image
      Transform.sobel(self, threshold)
    end

    # Detects edges using the Prewitt operator.
    def prewitt(threshold : Int32? = nil) : CrImage::Image
      Transform.prewitt(self, threshold)
    end

    # Detects edges using the Roberts cross operator.
    def roberts(threshold : Int32? = nil) : CrImage::Image
      Transform.roberts(self, threshold)
    end

    # Applies sepia tone effect for a vintage photograph look.
    #
    # Example:
    # ```
    # vintage = img.sepia
    # ```
    def sepia : CrImage::Image
      Transform.sepia(self)
    end

    # Applies emboss effect for a 3D raised appearance.
    #
    # Parameters:
    # - `angle` : Light direction angle in degrees (default: 45.0)
    # - `depth` : Effect intensity (default: 1.0)
    #
    # Example:
    # ```
    # embossed = img.emboss(angle: 45.0, depth: 1.5)
    # ```
    def emboss(angle : Float64 = 45.0, depth : Float64 = 1.0) : CrImage::Image
      Transform.emboss(self, angle, depth)
    end

    # Applies vignette effect (darkened edges).
    #
    # Parameters:
    # - `strength` : Darkening intensity (0.0-1.0, default: 0.5)
    # - `radius` : Vignette radius (0.0-1.0, default: 0.7)
    #
    # Example:
    # ```
    # vignetted = img.vignette(strength: 0.7, radius: 0.6)
    # ```
    def vignette(strength : Float64 = 0.5, radius : Float64 = 0.7) : CrImage::Image
      Transform.vignette(self, strength, radius)
    end

    # Adjusts color temperature (warm/cool tint).
    #
    # Parameters:
    # - `adjustment` : Temperature shift (positive = warmer/orange, negative = cooler/blue)
    #
    # Example:
    # ```
    # warmer = img.temperature(30)
    # cooler = img.temperature(-30)
    # ```
    def temperature(adjustment : Int32) : CrImage::Image
      Transform.temperature(self, adjustment)
    end

    # Computes the histogram of the image.
    #
    # Returns: Histogram object with statistical methods
    #
    # Example:
    # ```
    # hist = img.histogram
    # puts "Mean: #{hist.mean}, Median: #{hist.median}"
    # ```
    def histogram : Util::Histogram
      Util::HistogramOps.compute(self)
    end

    # Applies histogram equalization to enhance contrast.
    #
    # Example:
    # ```
    # enhanced = img.equalize
    # ```
    def equalize : CrImage::Image
      Util::HistogramOps.equalize(self)
    end

    # Applies adaptive histogram equalization (CLAHE) for local contrast enhancement.
    #
    # Parameters:
    # - `tile_size` : Size of local regions (default: 8)
    # - `clip_limit` : Contrast limiting threshold (default: 2.0)
    #
    # Example:
    # ```
    # enhanced = img.equalize_adaptive(tile_size: 8, clip_limit: 2.0)
    # ```
    def equalize_adaptive(tile_size : Int32 = 8, clip_limit : Float64 = 2.0) : CrImage::Image
      Util::HistogramOps.equalize_adaptive(self, tile_size, clip_limit)
    end

    # Applies dithering to reduce colors using the specified palette.
    #
    # Parameters:
    # - `palette` : Target color palette
    # - `algorithm` : Dithering algorithm (FloydSteinberg, Atkinson, etc.)
    #
    # Example:
    # ```
    # palette = img.generate_palette(16)
    # dithered = img.dither(palette, Util::DitheringAlgorithm::FloydSteinberg)
    # ```
    def dither(palette : Color::Palette,
               algorithm : Util::DitheringAlgorithm = Util::DitheringAlgorithm::FloydSteinberg) : Paletted
      Util::Dithering.apply(self, palette, algorithm)
    end

    # Calculates Mean Squared Error between this and another image.
    #
    # Returns: MSE value (lower = more similar)
    def mse(other : Image) : Float64
      Util::Metrics.mse(self, other)
    end

    # Calculates Peak Signal-to-Noise Ratio between this and another image.
    #
    # Returns: PSNR in dB (higher = more similar)
    def psnr(other : Image) : Float64
      Util::Metrics.psnr(self, other)
    end

    # Calculates Structural Similarity Index between this and another image.
    #
    # Returns: SSIM value (0.0-1.0, higher = more similar)
    def ssim(other : Image, window_size : Int32 = 11) : Float64
      Util::Metrics.ssim(self, other, window_size)
    end

    # Computes perceptual hash for duplicate detection.
    #
    # Returns: 64-bit hash value
    def perceptual_hash : UInt64
      Util::Metrics.perceptual_hash(self)
    end

    # Applies morphological erosion (removes small bright spots).
    #
    # Parameters:
    # - `kernel_size` : Structuring element size (default: 3)
    # - `shape` : Element shape (Rectangle, Cross, Ellipse)
    def erode(kernel_size : Int32 = 3, shape : Util::StructuringElement = Util::StructuringElement::Rectangle) : CrImage::Image
      Util::Morphology.erode(self, kernel_size, shape)
    end

    # Applies morphological dilation (fills small dark holes).
    #
    # Parameters:
    # - `kernel_size` : Structuring element size (default: 3)
    # - `shape` : Element shape (Rectangle, Cross, Ellipse)
    def dilate(kernel_size : Int32 = 3, shape : Util::StructuringElement = Util::StructuringElement::Rectangle) : CrImage::Image
      Util::Morphology.dilate(self, kernel_size, shape)
    end

    # Applies morphological opening (erosion followed by dilation).
    #
    # Removes noise while preserving shape.
    def morphology_open(kernel_size : Int32 = 3, shape : Util::StructuringElement = Util::StructuringElement::Rectangle) : CrImage::Image
      Util::Morphology.open(self, kernel_size, shape)
    end

    # Applies morphological closing (dilation followed by erosion).
    #
    # Fills gaps while preserving shape.
    def morphology_close(kernel_size : Int32 = 3, shape : Util::StructuringElement = Util::StructuringElement::Rectangle) : CrImage::Image
      Util::Morphology.close(self, kernel_size, shape)
    end

    # Applies morphological gradient (dilation - erosion).
    #
    # Detects edges and boundaries.
    def morphology_gradient(kernel_size : Int32 = 3, shape : Util::StructuringElement = Util::StructuringElement::Rectangle) : CrImage::Image
      Util::Morphology.gradient(self, kernel_size, shape)
    end

    # Generates an optimal color palette from the image.
    #
    # Parameters:
    # - `max_colors` : Maximum palette size (default: 256)
    # - `algorithm` : Quantization algorithm (MedianCut, Octree, Popularity)
    #
    # Example:
    # ```
    # palette = img.generate_palette(16, Util::QuantizationAlgorithm::MedianCut)
    # ```
    def generate_palette(max_colors : Int32 = 256, algorithm : Util::QuantizationAlgorithm = Util::QuantizationAlgorithm::MedianCut) : Color::Palette
      Util::Quantization.generate_palette(self, max_colors, algorithm)
    end

    # Applies EXIF orientation transform to correct image rotation.
    #
    # Digital cameras store orientation information in EXIF metadata.
    # This method applies the necessary rotation/flip to display correctly.
    #
    # Parameters:
    # - `orientation` : EXIF orientation value (1-8) or Orientation enum
    #
    # Example:
    # ```
    # exif = CrImage::EXIF.read("photo.jpg")
    # if exif && exif.needs_transform?
    #   img = img.auto_orient(exif.orientation)
    # end
    # ```
    def auto_orient(orientation : EXIF::Orientation) : CrImage::Image
      Transform.auto_orient(self, orientation)
    end

    # Applies EXIF orientation transform using integer value (1-8).
    def auto_orient(orientation : Int32) : CrImage::Image
      Transform.auto_orient(self, orientation)
    end

    # Encodes the image to a blurhash string.
    #
    # Blurhash is a compact representation of a placeholder for an image.
    # Useful for showing blurred previews while full images load.
    #
    # Parameters:
    # - `x_components` : Horizontal detail (1-9, default: 4)
    # - `y_components` : Vertical detail (1-9, default: 3)
    #
    # Example:
    # ```
    # hash = img.to_blurhash
    # hash = img.to_blurhash(x_components: 5, y_components: 4)
    # ```
    def to_blurhash(x_components : Int32 = 4, y_components : Int32 = 3) : String
      Util::Blurhash.encode(self, x_components, y_components)
    end

    # Resizes image to fit within the given dimensions, preserving aspect ratio.
    #
    # The resulting image will be at most `width` x `height`, but may be smaller
    # in one dimension to maintain the original aspect ratio.
    #
    # Parameters:
    # - `width` : Maximum width
    # - `height` : Maximum height
    # - `quality` : Resampling quality (default: :bicubic)
    #
    # Example:
    # ```
    # # Fit a 1920x1080 image into 800x600 box
    # fitted = img.fit(800, 600) # => 800x450 (maintains 16:9)
    #
    # # Fit with different quality
    # fast = img.fit(800, 600, quality: :nearest)
    # best = img.fit(800, 600, quality: :lanczos)
    # ```
    def fit(width : Int32, height : Int32, quality : Symbol = :bicubic) : CrImage::Image
      Util.thumbnail(self, width, height, Util::ThumbnailMode::Fit, symbol_to_quality(quality))
    end

    # Resizes image to fill the given dimensions, cropping excess.
    #
    # The resulting image will be exactly `width` x `height`. The image is
    # scaled to cover the entire area, then center-cropped to fit.
    #
    # Parameters:
    # - `width` : Target width
    # - `height` : Target height
    # - `quality` : Resampling quality (default: :bicubic)
    #
    # Example:
    # ```
    # # Fill 800x800 square from a 1920x1080 image (crops sides)
    # filled = img.fill(800, 800)
    #
    # # Create social media thumbnail
    # instagram = img.fill(1080, 1080)
    # ```
    def fill(width : Int32, height : Int32, quality : Symbol = :bicubic) : CrImage::Image
      Util.thumbnail(self, width, height, Util::ThumbnailMode::Fill, symbol_to_quality(quality))
    end

    # Creates a square thumbnail of the specified size.
    #
    # Shorthand for `fill(size, size)` - creates a square thumbnail by
    # scaling and center-cropping the image.
    #
    # Parameters:
    # - `size` : Width and height of the square thumbnail
    # - `quality` : Resampling quality (default: :bicubic)
    #
    # Example:
    # ```
    # # Create 200x200 avatar thumbnail
    # avatar = img.thumb(200)
    #
    # # Create multiple sizes
    # small = img.thumb(64)
    # medium = img.thumb(128)
    # large = img.thumb(256)
    # ```
    def thumb(size : Int32, quality : Symbol = :bicubic) : CrImage::Image
      fill(size, size, quality)
    end

    # Converts symbol to ResampleQuality enum.
    private def symbol_to_quality(quality : Symbol) : Util::ResampleQuality
      case quality
      when :nearest  then Util::ResampleQuality::Nearest
      when :bilinear then Util::ResampleQuality::Bilinear
      when :bicubic  then Util::ResampleQuality::Bicubic
      when :lanczos  then Util::ResampleQuality::Lanczos
      else
        raise ArgumentError.new("Unknown quality: #{quality}. Use :nearest, :bilinear, :bicubic, or :lanczos")
      end
    end
  end

  # RGBA-specific extensions for color space conversions
  class RGBA
    # Convert entire image through HSV color space and back to RGBA
    # This applies HSV transformation to every pixel
    def to_hsv : RGBA
      result = RGBA.new(@rect)

      Util::PixelIterator.each_pixel(self) do |x, y, r, g, b, a|
        rgba_color = Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8)
        hsv_color = rgba_color.to_hsv
        result.set_rgba(x, y, hsv_color.to_rgba)
      end

      result
    end

    # Convert entire image through HSL color space and back to RGBA
    # This applies HSL transformation to every pixel
    def to_hsl : RGBA
      result = RGBA.new(@rect)

      Util::PixelIterator.each_pixel(self) do |x, y, r, g, b, a|
        rgba_color = Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8)
        hsl_color = rgba_color.to_hsl
        result.set_rgba(x, y, hsl_color.to_rgba)
      end

      result
    end

    # Convert entire image through LAB color space and back to RGBA
    # This applies LAB transformation to every pixel
    def to_lab : RGBA
      result = RGBA.new(@rect)

      Util::PixelIterator.each_pixel(self) do |x, y, r, g, b, a|
        rgba_color = Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8)
        lab_color = rgba_color.to_lab
        result.set_rgba(x, y, lab_color.to_rgba)
      end

      result
    end

    # Optimized fill for RGBA images using bulk operations
    def fill(color : Color::Color)
      c = Color.rgba_model.convert(color)
      return unless c.is_a?(Color::RGBA)

      # Convert color once
      bytes = Bytes[c.r, c.g, c.b, c.a]

      # Fill first row
      y = @rect.min.y
      offset = pixel_offset(@rect.min.x, y)
      width_bytes = @rect.width * 4

      # Fill first row pixel by pixel
      (0...@rect.width).each do |x|
        idx = offset + x * 4
        @pix[idx, 4].copy_from(bytes.to_unsafe, 4)
      end

      # Copy first row to remaining rows (much faster than pixel iteration)
      first_row = @pix[offset, width_bytes]
      (@rect.min.y + 1).upto(@rect.max.y - 1) do |y|
        offset += @stride
        @pix[offset, width_bytes].copy_from(first_row.to_unsafe, width_bytes)
      end
    end

    # Optimized clear for RGBA images
    def clear
      @pix.fill(0_u8)
    end
  end

  # NRGBA-specific extensions
  class NRGBA
    # Optimized fill for NRGBA images
    def fill(color : Color::Color)
      c = Color.nrgba_model.convert(color)
      return unless c.is_a?(Color::NRGBA)
      bytes = Bytes[c.r, c.g, c.b, c.a]

      bounds.min.y.upto(bounds.max.y - 1) do |y|
        offset = pixel_offset(bounds.min.x, y)
        (0...bounds.width).each do |x|
          idx = offset + x * 4
          pix[idx, 4].copy_from(bytes.to_unsafe, 4)
        end
      end
    end

    # Clear NRGBA image to transparent
    def clear
      pix.fill(0_u8)
    end
  end

  # Gray-specific extensions
  class Gray
    # Fill grayscale image with a gray value
    def fill(color : Color::Color)
      c = Color.gray_model.convert(color)
      return unless c.is_a?(Color::Gray)
      pix.fill(c.y)
    end

    # Clear grayscale image to black
    def clear
      pix.fill(0_u8)
    end
  end
end
