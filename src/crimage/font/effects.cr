require "../image"
require "./font"
require "../math/fixed"
require "../transform"

module CrImage::Font
  # Drop shadow effect for text.
  #
  # Creates a blurred shadow behind text to add depth and improve readability
  # against complex backgrounds.
  #
  # Properties:
  # - `offset_x` : Horizontal shadow displacement in pixels
  # - `offset_y` : Vertical shadow displacement in pixels
  # - `blur_radius` : Gaussian blur radius for soft edges
  # - `color` : Shadow color (typically semi-transparent black)
  class Shadow
    property offset_x : Int32
    property offset_y : Int32
    property blur_radius : Int32
    property color : Color::Color

    def initialize(@offset_x, @offset_y, @blur_radius, @color)
    end
  end

  # Outline/stroke effect for text.
  #
  # Draws a border around text glyphs to improve contrast and visibility.
  # Useful for text over images or complex backgrounds.
  #
  # Properties:
  # - `thickness` : Outline width in pixels
  # - `color` : Outline color
  class Outline
    property thickness : Int32
    property color : Color::Color

    def initialize(@thickness, @color)
    end
  end

  # Container for text rendering effects.
  #
  # Combines multiple visual effects that can be applied to text.
  # Effects render in order: shadow → outline → text → decorations.
  #
  # Note: Use `Drawer#draw_text` with named parameters for simpler API.
  #
  # Properties:
  # - `shadow` : Optional drop shadow effect
  # - `outline` : Optional outline/stroke effect
  # - `underline` : Enable underline decoration
  # - `strikethrough` : Enable strikethrough decoration
  # - `decoration_color` : Color for underline/strikethrough (defaults to text color)
  class TextStyle
    property shadow : Shadow?
    property outline : Outline?
    property underline : Bool
    property strikethrough : Bool
    property decoration_color : Color::Color?

    def initialize(@shadow = nil, @outline = nil, @underline = false, @strikethrough = false, @decoration_color = nil)
    end
  end

  class Drawer
    # Draw text with effects (shadow, outline, underline, strikethrough).
    # Effects are rendered in the correct order: shadow first, then outline, then text fill, then decorations.
    #
    # Parameters:
    # - text: The text to render
    # - style: TextStyle containing optional effects
    def draw_styled(text : String, style : TextStyle)
      # Save original dot position (create a copy since Point26_6 is a class)
      original_dot = Math::Fixed::Point26_6.new(@dot.x, @dot.y)

      # Step 1: Render shadow if present
      if shadow = style.shadow
        render_shadow(text, shadow, original_dot)
      end

      # Step 2: Render outline if present
      if outline = style.outline
        render_outline(text, outline, original_dot)
      end

      # Step 3: Render text fill (normal text)
      # Restore dot to original position before drawing final text
      # This ensures text is drawn at the correct position regardless of
      # what shadow/outline rendering did
      @dot = Math::Fixed::Point26_6.new(original_dot.x, original_dot.y)
      draw(text)

      # Step 4: Render decorations (underline and strikethrough)
      if style.underline || style.strikethrough
        render_decorations(text, style, original_dot)
      end
    end

    # Render text shadow with offset and blur
    private def render_shadow(text : String, shadow : Shadow, original_dot : Math::Fixed::Point26_6)
      # Calculate shadow position (offset from original)
      shadow_dot = Math::Fixed::Point26_6.new(
        original_dot.x + Math::Fixed::Int26_6[shadow.offset_x * 64],
        original_dot.y + Math::Fixed::Int26_6[shadow.offset_y * 64]
      )

      # Create a temporary image to render the shadow text
      # We need to determine the bounds of the text first
      bounds, advance = self.bounds(text)
      text_width = advance.ceil
      text_height = bounds.height.ceil

      # Add padding for blur radius
      padding = shadow.blur_radius * 2
      temp_width = text_width + padding * 2
      temp_height = text_height + padding * 2

      # Create temporary image for shadow
      temp_img = RGBA.new(CrImage.rect(0, 0, temp_width, temp_height))

      # Create a uniform color source for the shadow
      shadow_src = Uniform.new(shadow.color)

      # Create a temporary drawer for the shadow
      temp_drawer = Drawer.new(temp_img, shadow_src, @face)

      # Position the text in the temporary image (with padding)
      # The dot should be positioned so the text baseline is at the right place
      metrics = @face.metrics
      ascent = metrics.ascent.ceil

      temp_drawer.dot = Math::Fixed::Point26_6.new(
        Math::Fixed::Int26_6[padding * 64],
        Math::Fixed::Int26_6[(padding + ascent) * 64]
      )

      # Draw the shadow text
      temp_drawer.draw(text)

      # Apply Gaussian blur if blur_radius > 0
      blurred_shadow = if shadow.blur_radius > 0
                         Transform.blur_gaussian(temp_img, shadow.blur_radius)
                       else
                         temp_img
                       end

      # Calculate position to draw the blurred shadow on the destination
      # The shadow should be positioned relative to the original dot position
      # Account for the padding and the fact that dot.y is at the baseline
      shadow_x = shadow_dot.x.floor - padding
      shadow_y = shadow_dot.y.floor - ascent - padding

      # Draw the blurred shadow onto the destination
      shadow_rect = CrImage.rect(shadow_x, shadow_y, shadow_x + temp_width, shadow_y + temp_height)
      Draw.draw(@dest, shadow_rect, blurred_shadow, CrImage::Point.zero, Draw::Op::OVER)
    end

    # Render text outline by drawing the text multiple times with offset
    private def render_outline(text : String, outline : Outline, original_dot : Math::Fixed::Point26_6)
      # Create a uniform color source for the outline
      outline_src = Uniform.new(outline.color)

      # Save original source and dot
      original_src = @src
      saved_dot = @dot

      # Set outline color as source
      @src = outline_src

      # Draw the text multiple times in a circle pattern to create outline effect
      # The number of samples depends on the thickness
      samples = outline.thickness * 8

      samples.times do |i|
        angle = 2.0 * ::Math::PI * i / samples
        offset_x = (::Math.cos(angle) * outline.thickness).round.to_i
        offset_y = (::Math.sin(angle) * outline.thickness).round.to_i

        @dot = Math::Fixed::Point26_6.new(
          original_dot.x + Math::Fixed::Int26_6[offset_x * 64],
          original_dot.y + Math::Fixed::Int26_6[offset_y * 64]
        )

        draw(text)
      end

      # Restore original source and dot
      @src = original_src
      @dot = saved_dot
    end

    # Render text decorations (underline and strikethrough)
    private def render_decorations(text : String, style : TextStyle, original_dot : Math::Fixed::Point26_6)
      # Get text advance to know the line length
      advance = measure(text)
      line_length = advance.ceil

      # Get decoration source (use text color if not specified)
      decoration_src = style.decoration_color ? Uniform.new(style.decoration_color.not_nil!) : @src

      # Try to get extended metrics from FreeType font if available
      use_extended = false
      underline_pos = 0
      underline_thick = 0
      strikeout_pos = 0
      strikeout_thick = 0

      # Check if this is a FreeType face with extended metrics
      if @face.is_a?(FreeType::TrueType::Face)
        ttf_face = @face.as(FreeType::TrueType::Face)
        ttf_font = ttf_face.font
        scale = ttf_face.scale

        if ttf_font.responds_to?(:extended_metrics)
          ext_metrics = ttf_font.extended_metrics(1.0) # Get unscaled metrics

          # Scale metrics to current font size
          underline_pos = ((scale * ext_metrics.underline_position) // 64).floor
          underline_thick = [((scale * ext_metrics.underline_thickness) // 64).ceil, 1].max
          strikeout_pos = ((scale * ext_metrics.strikeout_position) // 64).floor
          strikeout_thick = [((scale * ext_metrics.strikeout_size) // 64).ceil, 1].max
          use_extended = true
        end
      end

      # Fallback to basic metrics if extended metrics not available
      unless use_extended
        face_metrics = @face.metrics
        underline_pos = (face_metrics.descent.ceil // 10)
        underline_thick = [face_metrics.height.ceil // 20, 1].max
        strikeout_pos = -(face_metrics.ascent.ceil * 4 // 10)
        strikeout_thick = [face_metrics.height.ceil // 20, 1].max
      end

      if style.underline
        draw_horizontal_line(
          original_dot.x.floor,
          original_dot.y.floor + underline_pos,
          line_length,
          underline_thick,
          decoration_src
        )
      end

      if style.strikethrough
        draw_horizontal_line(
          original_dot.x.floor,
          original_dot.y.floor + strikeout_pos,
          line_length,
          strikeout_thick,
          decoration_src
        )
      end
    end

    # Draw a horizontal line for text decorations
    private def draw_horizontal_line(x : Int32, y : Int32, length : Int32, thickness : Int32, color)
      # Create rectangle for the line
      line_rect = CrImage.rect(x, y, x + length, y + thickness)

      # Draw the line
      if color.is_a?(CrImage::Image)
        Draw.draw(@dest, line_rect, color, CrImage::Point.zero, Draw::Op::OVER)
      else
        # If color is a Uniform, draw it as a filled rectangle
        uniform_src = color.is_a?(Uniform) ? color : Uniform.new(color)
        Draw.draw(@dest, line_rect, uniform_src, CrImage::Point.zero, Draw::Op::OVER)
      end
    end
  end
end
