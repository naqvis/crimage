module CrImage::Util
  # Border and frame styles for image decoration.
  #
  # Options:
  # - `Solid` : Simple solid color border
  # - `Shadow` : Border with drop shadow effect
  # - `Rounded` : Border with rounded corners
  # - `RoundedShadow` : Rounded border with drop shadow
  enum BorderStyle
    Solid
    Shadow
    Rounded
    RoundedShadow
  end

  # Border provides methods for adding decorative borders and frames to images.
  module Border
    # Adds a simple solid border around an image.
    #
    # Creates a new image with the specified border width and color surrounding
    # the original image. The border is applied uniformly on all sides.
    #
    # Parameters:
    # - `src` : The source image to add border to
    # - `width` : Border width in pixels (must be positive)
    # - `color` : Border color (default: white)
    #
    # Returns: A new RGBA image with border added
    #
    # Raises: `ArgumentError` if width is not positive
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_border(20, CrImage::Color::WHITE)
    # ```
    def self.add_border(src : Image, width : Int32,
                        color : Color::Color = Color::WHITE) : RGBA
      raise ArgumentError.new("border width must be positive") if width <= 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Create new image with border
      new_width = src_width + (width * 2)
      new_height = src_height + (width * 2)
      result = CrImage.rgba(new_width, new_height, color)

      # Copy source image to center
      src_height.times do |y|
        src_width.times do |x|
          pixel = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
          result.set(x + width, y + width, pixel)
        end
      end

      result
    end

    # Adds a border with drop shadow effect for depth and dimension.
    #
    # Creates a professional-looking framed image with a solid border and
    # a blurred drop shadow behind it. The shadow is rendered using Gaussian
    # blur for smooth, realistic appearance.
    #
    # Parameters:
    # - `src` : The source image
    # - `border_width` : Width of the border in pixels (must be positive)
    # - `border_color` : Color of the border (default: white)
    # - `shadow_offset` : Distance of shadow from border in pixels (default: 8)
    # - `shadow_blur` : Blur radius for shadow softness (default: 10)
    # - `shadow_color` : Color of the shadow (default: semi-transparent black)
    #
    # Returns: A new RGBA image with border and shadow
    #
    # Raises: `ArgumentError` if any dimension parameter is invalid
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_border_with_shadow(
    #   border_width: 20,
    #   border_color: CrImage::Color::WHITE,
    #   shadow_offset: 8,
    #   shadow_blur: 10
    # )
    # ```
    def self.add_border_with_shadow(src : Image,
                                    border_width : Int32,
                                    border_color : Color::Color = Color::WHITE,
                                    shadow_offset : Int32 = 8,
                                    shadow_blur : Int32 = 10,
                                    shadow_color : Color::Color = Color.rgba(0, 0, 0, 128)) : RGBA
      raise ArgumentError.new("border width must be positive") if border_width <= 0
      raise ArgumentError.new("shadow offset must be non-negative") if shadow_offset < 0
      raise ArgumentError.new("shadow blur must be non-negative") if shadow_blur < 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Calculate dimensions
      content_width = src_width + (border_width * 2)
      content_height = src_height + (border_width * 2)
      total_width = content_width + shadow_offset + shadow_blur
      total_height = content_height + shadow_offset + shadow_blur

      # Create canvas
      result = CrImage.rgba(total_width, total_height, Color::TRANSPARENT)

      # Draw shadow FIRST (behind the content)
      shadow_x = shadow_offset
      shadow_y = shadow_offset
      draw_shadow(result, shadow_x, shadow_y, content_width, content_height,
        shadow_blur, shadow_color)

      # Draw border and image ON TOP at (0, 0)
      content_height.times do |y|
        content_width.times do |x|
          # Check if we're in the border area or image area
          if x < border_width || x >= content_width - border_width ||
             y < border_width || y >= content_height - border_width
            # Border area - always draw (covers shadow)
            result.set(x, y, border_color)
          else
            # Image area - always draw (covers shadow)
            src_x = x - border_width
            src_y = y - border_width
            pixel = src.at(src_x + src_bounds.min.x, src_y + src_bounds.min.y)
            result.set(x, y, pixel)
          end
        end
      end

      result
    end

    # Adds rounded corners to an image for a modern, polished look.
    #
    # Applies circular corner rounding using distance-based masking. Areas
    # outside the rounded corners become transparent. The radius determines
    # how much curvature is applied to each corner.
    #
    # Parameters:
    # - `src` : The source image
    # - `radius` : Corner radius in pixels (must be positive)
    #
    # Returns: A new RGBA image with rounded corners and transparent background
    #
    # Raises: `ArgumentError` if radius is not positive
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # rounded = img.round_corners(20)
    # ```
    def self.round_corners(src : Image, radius : Int32) : RGBA
      raise ArgumentError.new("radius must be positive") if radius <= 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Create result image
      result = CrImage.rgba(src_width, src_height, Color::TRANSPARENT)

      # Copy image with rounded corner mask
      src_height.times do |y|
        src_width.times do |x|
          # Check if pixel is in rounded corner area
          if should_draw_pixel(x, y, src_width, src_height, radius)
            pixel = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
            result.set(x, y, pixel)
          end
        end
      end

      result
    end

    # Adds a rounded border with optional drop shadow for premium styling.
    #
    # Combines rounded corners with a solid border, optionally adding a drop
    # shadow for depth. This creates a modern, card-like appearance commonly
    # used in UI design and photo galleries.
    #
    # Parameters:
    # - `src` : The source image
    # - `border_width` : Width of the border in pixels (must be positive)
    # - `corner_radius` : Radius of rounded corners in pixels (must be positive)
    # - `border_color` : Color of the border (default: white)
    # - `shadow` : Whether to add drop shadow (default: false)
    # - `shadow_offset` : Shadow offset when enabled (default: 8)
    # - `shadow_blur` : Shadow blur radius when enabled (default: 10)
    #
    # Returns: A new RGBA image with rounded border and optional shadow
    #
    # Raises: `ArgumentError` if dimensions are invalid
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_rounded_border(
    #   border_width: 20,
    #   corner_radius: 30,
    #   border_color: CrImage::Color::WHITE
    # )
    # ```
    def self.add_rounded_border(src : Image,
                                border_width : Int32,
                                corner_radius : Int32,
                                border_color : Color::Color = Color::WHITE,
                                shadow : Bool = false,
                                shadow_offset : Int32 = 8,
                                shadow_blur : Int32 = 10) : RGBA
      raise ArgumentError.new("border width must be positive") if border_width <= 0
      raise ArgumentError.new("corner radius must be positive") if corner_radius <= 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Calculate dimensions
      content_width = src_width + (border_width * 2)
      content_height = src_height + (border_width * 2)

      if shadow
        total_width = content_width + shadow_offset + shadow_blur
        total_height = content_height + shadow_offset + shadow_blur
        result = CrImage.rgba(total_width, total_height, Color::TRANSPARENT)

        # Draw shadow
        draw_shadow(result, shadow_offset, shadow_offset, content_width, content_height,
          shadow_blur, Color.rgba(0, 0, 0, 128))

        offset_x = 0
        offset_y = 0
      else
        result = CrImage.rgba(content_width, content_height, Color::TRANSPARENT)
        offset_x = 0
        offset_y = 0
      end

      # Draw rounded border and image
      content_height.times do |y|
        content_width.times do |x|
          canvas_x = x + offset_x
          canvas_y = y + offset_y

          # Check if pixel should be drawn (rounded corners)
          if should_draw_pixel(x, y, content_width, content_height, corner_radius)
            # Check if we're in border or image area
            if x < border_width || x >= content_width - border_width ||
               y < border_width || y >= content_height - border_width
              # Border area
              result.set(canvas_x, canvas_y, border_color)
            else
              # Image area
              src_x = x - border_width
              src_y = y - border_width
              pixel = src.at(src_x + src_bounds.min.x, src_y + src_bounds.min.y)
              result.set(canvas_x, canvas_y, pixel)
            end
          end
        end
      end

      result
    end

    # Determines if a pixel should be drawn based on rounded corner mask.
    #
    # Uses circular distance calculation to determine if a pixel falls within
    # the rounded corner regions. Pixels outside the corner circles are excluded.
    private def self.should_draw_pixel(x : Int32, y : Int32, width : Int32, height : Int32, radius : Int32) : Bool
      # Check each corner
      # Top-left
      if x < radius && y < radius
        dx = radius - x
        dy = radius - y
        return dx * dx + dy * dy <= radius * radius
      end

      # Top-right
      if x >= width - radius && y < radius
        dx = x - (width - radius - 1)
        dy = radius - y
        return dx * dx + dy * dy <= radius * radius
      end

      # Bottom-left
      if x < radius && y >= height - radius
        dx = radius - x
        dy = y - (height - radius - 1)
        return dx * dx + dy * dy <= radius * radius
      end

      # Bottom-right
      if x >= width - radius && y >= height - radius
        dx = x - (width - radius - 1)
        dy = y - (height - radius - 1)
        return dx * dx + dy * dy <= radius * radius
      end

      # Not in corner area, always draw
      true
    end

    # Draws a drop shadow with Gaussian blur for realistic appearance.
    #
    # Creates a shadow by drawing a solid rectangle, applying Gaussian blur,
    # and compositing it behind the content. Only draws on transparent pixels
    # to avoid overwriting the main content.
    private def self.draw_shadow(dst : RGBA, x : Int32, y : Int32,
                                 width : Int32, height : Int32,
                                 blur : Int32, color : Color::Color)
      r, g, b, a = color.rgba
      shadow_r = (r >> 8).to_u8
      shadow_g = (g >> 8).to_u8
      shadow_b = (b >> 8).to_u8
      base_alpha = (a >> 8)

      if blur > 0
        # Create shadow shape with padding for blur
        padding = blur * 2
        shadow_width = width + padding * 2
        shadow_height = height + padding * 2

        # Create transparent canvas
        shadow_img = CrImage.rgba(shadow_width, shadow_height, Color::TRANSPARENT)

        # Draw solid rectangle in center
        height.times do |sy|
          width.times do |sx|
            shadow_img.set(sx + padding, sy + padding,
              Color.rgba(shadow_r, shadow_g, shadow_b, base_alpha.to_u8))
          end
        end

        # Apply Gaussian blur
        blurred = shadow_img.blur_gaussian(radius: blur, sigma: blur.to_f64 / 2.0)

        # Copy blurred shadow to destination (accounting for padding offset)
        blurred_bounds = blurred.bounds
        blurred_bounds.height.times do |sy|
          blurred_bounds.width.times do |sx|
            px = x + sx - padding
            py = y + sy - padding
            next if px < 0 || py < 0 || px >= dst.bounds.max.x || py >= dst.bounds.max.y

            shadow_pixel = blurred.at(sx, sy)
            _, _, _, sa = shadow_pixel.rgba

            if sa > 0
              # Only draw on transparent pixels (don't overwrite content)
              existing = dst.at(px, py)
              _, _, _, ea = existing.rgba

              if ea == 0
                dst.set(px, py, shadow_pixel)
              end
            end
          end
        end
      else
        # No blur, just draw solid shadow
        height.times do |sy|
          width.times do |sx|
            px = x + sx
            py = y + sy
            next if px < 0 || py < 0 || px >= dst.bounds.max.x || py >= dst.bounds.max.y

            existing = dst.at(px, py)
            _, _, _, ea = existing.rgba

            if ea == 0
              dst.set(px, py, Color.rgba(shadow_r, shadow_g, shadow_b, base_alpha.to_u8))
            end
          end
        end
      end
    end
  end
end

module CrImage
  module Image
    # Adds a solid border around the image.
    #
    # Convenience method that delegates to `Util::Border.add_border`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_border(20, CrImage::Color::WHITE)
    # ```
    def add_border(width : Int32, color : Color::Color = Color::WHITE) : RGBA
      Util::Border.add_border(self, width, color)
    end

    # Adds a border with drop shadow effect.
    #
    # Convenience method that delegates to `Util::Border.add_border_with_shadow`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_border_with_shadow(20)
    # ```
    def add_border_with_shadow(border_width : Int32,
                               border_color : Color::Color = Color::WHITE,
                               shadow_offset : Int32 = 8,
                               shadow_blur : Int32 = 10,
                               shadow_color : Color::Color = Color.rgba(0, 0, 0, 128)) : RGBA
      Util::Border.add_border_with_shadow(self, border_width, border_color,
        shadow_offset, shadow_blur, shadow_color)
    end

    # Adds rounded corners to the image.
    #
    # Convenience method that delegates to `Util::Border.round_corners`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # rounded = img.round_corners(20)
    # ```
    def round_corners(radius : Int32) : RGBA
      Util::Border.round_corners(self, radius)
    end

    # Adds a rounded border with optional shadow.
    #
    # Convenience method that delegates to `Util::Border.add_rounded_border`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # framed = img.add_rounded_border(20, 30)
    # ```
    def add_rounded_border(border_width : Int32,
                           corner_radius : Int32,
                           border_color : Color::Color = Color::WHITE,
                           shadow : Bool = false,
                           shadow_offset : Int32 = 8,
                           shadow_blur : Int32 = 10) : RGBA
      Util::Border.add_rounded_border(self, border_width, corner_radius,
        border_color, shadow, shadow_offset, shadow_blur)
    end
  end
end
