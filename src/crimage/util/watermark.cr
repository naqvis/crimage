require "../image"
require "../draw"
require "../font"

module CrImage::Util
  # Watermark position on the image.
  #
  # Predefined positions for watermark placement:
  # - `TopLeft` : Upper left corner
  # - `TopRight` : Upper right corner
  # - `BottomLeft` : Lower left corner
  # - `BottomRight` : Lower right corner (most common)
  # - `Center` : Center of image
  # - `Custom` : User-specified position (requires custom_point)
  enum WatermarkPosition
    TopLeft
    TopRight
    BottomLeft
    BottomRight
    Center
    Custom
  end

  # Options for watermark application.
  #
  # Configures watermark placement, opacity, and tiling behavior.
  #
  # Properties:
  # - `position` : Watermark position (default: BottomRight)
  # - `custom_point` : Custom position when position is Custom
  # - `opacity` : Watermark opacity 0.0-1.0 (default: 0.5)
  # - `tiled` : Whether to tile watermark across image (default: false)
  class WatermarkOptions
    property position : WatermarkPosition
    property custom_point : Point?
    property opacity : Float64
    property tiled : Bool

    def initialize(@position = WatermarkPosition::BottomRight,
                   @custom_point = nil,
                   @opacity = 0.5,
                   @tiled = false)
      raise ArgumentError.new("Opacity must be between 0.0 and 1.0, got #{@opacity}") if @opacity < 0.0 || @opacity > 1.0
    end
  end

  # Adds an image watermark to an image.
  #
  # Overlays a watermark image onto the source image with configurable
  # position, opacity, and tiling. Useful for copyright protection and branding.
  #
  # Parameters:
  # - `img` : The source image
  # - `watermark` : The watermark image to overlay
  # - `options` : Watermark configuration options
  #
  # Returns: A new RGBA image with watermark applied
  #
  # Raises: `ArgumentError` if opacity is outside 0.0-1.0 range
  #
  # Example:
  # ```
  # img = CrImage.read("photo.jpg")
  # logo = CrImage.read("logo.png")
  # opts = CrImage::Util::WatermarkOptions.new(opacity: 0.3)
  # watermarked = CrImage::Util.watermark_image(img, logo, opts)
  # ```
  def self.watermark_image(img : Image, watermark : Image, options : WatermarkOptions) : RGBA
    raise ArgumentError.new("Opacity must be between 0.0 and 1.0, got #{options.opacity}") if options.opacity < 0.0 || options.opacity > 1.0

    # Create output image as a copy of the input
    dst = RGBA.new(img.bounds)
    img.bounds.height.times do |y|
      img.bounds.width.times do |x|
        dst.set(x, y, img.at(x, y))
      end
    end

    if options.tiled
      # Apply tiled watermark
      apply_tiled_watermark(dst, watermark, options.opacity)
    else
      # Apply single watermark at specified position
      position = calculate_watermark_position(img.bounds, watermark.bounds, options)
      apply_watermark_at_position(dst, watermark, position, options.opacity)
    end

    dst
  end

  # Adds a text watermark to an image.
  #
  # Renders text onto the image with configurable position, opacity, and tiling.
  # Useful for copyright notices, timestamps, and branding.
  #
  # Parameters:
  # - `img` : The source image
  # - `text` : The text to render (must not be empty)
  # - `font_face` : Font face for text rendering
  # - `options` : Watermark configuration options
  #
  # Returns: A new RGBA image with text watermark applied
  #
  # Raises: `ArgumentError` if opacity is invalid or text is empty
  #
  # Example:
  # ```
  # img = CrImage.read("photo.jpg")
  # font = FreeType::TrueType.load("font.ttf")
  # face = FreeType::TrueType.new_face(font, 24.0)
  # opts = CrImage::Util::WatermarkOptions.new(opacity: 0.5)
  # watermarked = CrImage::Util.watermark_text(img, "© 2024", face, opts)
  # ```
  def self.watermark_text(img : Image, text : String, font_face : Font::Face,
                          options : WatermarkOptions) : RGBA
    raise ArgumentError.new("Opacity must be between 0.0 and 1.0, got #{options.opacity}") if options.opacity < 0.0 || options.opacity > 1.0
    raise ArgumentError.new("Text cannot be empty") if text.empty?

    # Create output image as a copy of the input
    dst = RGBA.new(img.bounds)
    img.bounds.height.times do |y|
      img.bounds.width.times do |x|
        dst.set(x, y, img.at(x, y))
      end
    end

    # Measure text
    bounds, advance = Font.bounds(font_face, text)
    metrics = font_face.metrics

    # Calculate text dimensions for positioning
    text_width = advance.ceil.to_i
    text_height = metrics.height.ceil.to_i
    text_rect = CrImage.rect(0, 0, text_width, text_height)

    # Create white color for text (fully opaque - opacity handled by alpha blending)
    text_color = Color::RGBA.new(255_u8, 255_u8, 255_u8, 255_u8)
    text_src = Uniform.new(text_color)

    if options.tiled
      # Draw tiled text watermark
      spacing = 40
      tile_width = text_width + spacing
      tile_height = text_height + spacing

      y_offset = metrics.ascent.ceil.to_i
      while y_offset < dst.bounds.height + text_height
        x_offset = 0
        while x_offset < dst.bounds.width
          dot = Math::Fixed::Point26_6.new(
            Math::Fixed::Int26_6[x_offset * 64],
            Math::Fixed::Int26_6[y_offset * 64]
          )
          drawer = Font::Drawer.new(dst, text_src, font_face, dot)
          drawer.draw(text)

          x_offset += tile_width
        end
        y_offset += tile_height
      end
    else
      # Calculate position for single text watermark
      position = calculate_watermark_position(img.bounds, text_rect, options)

      # Ensure position is within bounds
      position_x = [[position.x, 0].max, img.bounds.width - text_width].min
      position_y = [[position.y, 0].max, img.bounds.height - text_height].min

      # Draw text at calculated position (adjust for baseline)
      dot = Math::Fixed::Point26_6.new(
        Math::Fixed::Int26_6[position_x * 64],
        Math::Fixed::Int26_6[(position_y + metrics.ascent.ceil.to_i) * 64]
      )
      drawer = Font::Drawer.new(dst, text_src, font_face, dot)
      drawer.draw(text)
    end

    dst
  end

  # Calculates the watermark position based on options.
  #
  # Converts position enum to actual pixel coordinates.
  private def self.calculate_watermark_position(img_bounds : Rectangle,
                                                watermark_bounds : Rectangle,
                                                options : WatermarkOptions) : Point
    case options.position
    when .top_left?
      Point.new(0, 0)
    when .top_right?
      Point.new(img_bounds.width - watermark_bounds.width, 0)
    when .bottom_left?
      Point.new(0, img_bounds.height - watermark_bounds.height)
    when .bottom_right?
      Point.new(img_bounds.width - watermark_bounds.width,
        img_bounds.height - watermark_bounds.height)
    when .center?
      Point.new((img_bounds.width - watermark_bounds.width) // 2,
        (img_bounds.height - watermark_bounds.height) // 2)
    when .custom?
      if custom = options.custom_point
        custom
      else
        raise ArgumentError.new("Custom position requires custom_point to be set")
      end
    else
      raise InvalidArgumentError.new("position", options.position.to_s)
    end
  end

  # Applies watermark at a specific position with alpha blending.
  #
  # Composites the watermark onto the destination using opacity.
  private def self.apply_watermark_at_position(dst : RGBA, watermark : Image,
                                               position : Point, opacity : Float64)
    # Blend watermark onto destination
    watermark.bounds.height.times do |wy|
      watermark.bounds.width.times do |wx|
        dx = position.x + wx
        dy = position.y + wy

        # Skip if outside destination bounds
        next if dx < 0 || dx >= dst.bounds.width || dy < 0 || dy >= dst.bounds.height

        # Get watermark and destination colors
        wm_color = watermark.at(wx, wy)
        dst_color = dst.at(dx, dy)

        # Blend colors with opacity
        blended = blend_colors(dst_color, wm_color, opacity)
        dst.set(dx, dy, blended)
      end
    end
  end

  # Applies tiled watermark across the entire image.
  #
  # Repeats the watermark in a grid pattern covering the whole image.
  private def self.apply_tiled_watermark(dst : RGBA, watermark : Image, opacity : Float64)
    wm_width = watermark.bounds.width
    wm_height = watermark.bounds.height

    # Tile the watermark across the image
    y_offset = 0
    while y_offset < dst.bounds.height
      x_offset = 0
      while x_offset < dst.bounds.width
        # Apply watermark at this tile position
        watermark.bounds.height.times do |wy|
          watermark.bounds.width.times do |wx|
            dx = x_offset + wx
            dy = y_offset + wy

            # Skip if outside destination bounds
            next if dx >= dst.bounds.width || dy >= dst.bounds.height

            # Get watermark and destination colors
            wm_color = watermark.at(wx, wy)
            dst_color = dst.at(dx, dy)

            # Blend colors with opacity
            blended = blend_colors(dst_color, wm_color, opacity)
            dst.set(dx, dy, blended)
          end
        end

        x_offset += wm_width
      end
      y_offset += wm_height
    end
  end

  # Blends two colors using alpha blending with specified opacity.
  #
  # Applies standard alpha compositing formula with opacity adjustment.
  private def self.blend_colors(dst_color : Color::Color, src_color : Color::Color,
                                opacity : Float64) : Color::RGBA
    dr, dg, db, da = dst_color.rgba
    sr, sg, sb, sa = src_color.rgba

    # Convert to 8-bit and apply opacity to source alpha
    dr8 = (dr >> 8).to_u8
    dg8 = (dg >> 8).to_u8
    db8 = (db >> 8).to_u8
    da8 = (da >> 8).to_u8

    sr8 = (sr >> 8).to_u8
    sg8 = (sg >> 8).to_u8
    sb8 = (sb >> 8).to_u8
    sa8 = ((sa >> 8).to_f * opacity).round.to_u8

    # Alpha blending formula: result = src * alpha + dst * (1 - alpha)
    alpha = sa8.to_f / 255.0
    inv_alpha = 1.0 - alpha

    r = (sr8.to_f * alpha + dr8.to_f * inv_alpha).round.to_u8
    g = (sg8.to_f * alpha + dg8.to_f * inv_alpha).round.to_u8
    b = (sb8.to_f * alpha + db8.to_f * inv_alpha).round.to_u8
    a = [da8, sa8].max # Keep the maximum alpha

    Color::RGBA.new(r, g, b, a)
  end
end
