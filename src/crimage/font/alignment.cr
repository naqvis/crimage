require "../image"
require "./font"
require "../math/fixed"

module CrImage::Font
  # HorizontalAlign specifies horizontal text alignment within a bounding box.
  #
  # Options:
  # - `Left` : Align text to the left edge
  # - `Center` : Center text horizontally
  # - `Right` : Align text to the right edge
  enum HorizontalAlign
    Left
    Center
    Right
  end

  # VerticalAlign specifies vertical text alignment within a bounding box.
  #
  # Options:
  # - `Top` : Align text to the top edge
  # - `Middle` : Center text vertically
  # - `Bottom` : Align text to the bottom edge
  enum VerticalAlign
    Top
    Middle
    Bottom
  end

  # TextBox defines a bounding rectangle and alignment properties for text rendering.
  #
  # Specifies where and how text should be positioned within a rectangular region.
  #
  # Example:
  # ```
  # box = CrImage::Font::TextBox.new(
  #   CrImage.rect(0, 0, 400, 300),
  #   h_align: CrImage::Font::HorizontalAlign::Center,
  #   v_align: CrImage::Font::VerticalAlign::Middle
  # )
  # ```
  class TextBox
    property rect : CrImage::Rectangle
    property h_align : HorizontalAlign
    property v_align : VerticalAlign

    def initialize(@rect, @h_align = HorizontalAlign::Left, @v_align = VerticalAlign::Top)
    end
  end

  class Drawer
    # Draw text aligned within a bounding box.
    # The text will be positioned according to the horizontal and vertical alignment
    # settings of the TextBox.
    #
    # Parameters:
    # - text: The text to render
    # - box: TextBox specifying the bounding rectangle and alignment
    def draw_aligned(text : String, box : TextBox)
      # Measure the text to get its dimensions
      bounds, advance = self.bounds(text)
      text_width = advance.ceil
      text_height = bounds.height.ceil

      # Calculate horizontal position based on alignment
      x_pos = case box.h_align
              when HorizontalAlign::Left
                box.rect.min.x
              when HorizontalAlign::Center
                box.rect.min.x + (box.rect.width - text_width) // 2
              when HorizontalAlign::Right
                box.rect.min.x + box.rect.width - text_width
              else
                box.rect.min.x
              end

      # Calculate vertical position based on alignment
      # Note: In font rendering, the baseline is the reference point
      # We need to account for ascent to position the text correctly
      metrics = face.metrics
      ascent = metrics.ascent.ceil

      y_pos = case box.v_align
              when VerticalAlign::Top
                box.rect.min.y + ascent
              when VerticalAlign::Middle
                box.rect.min.y + (box.rect.height - text_height) // 2 + ascent
              when VerticalAlign::Bottom
                box.rect.min.y + box.rect.height - text_height + ascent
              else
                box.rect.min.y + ascent
              end

      # Set the dot position and draw the text
      @dot = Math::Fixed::Point26_6.new(
        Math::Fixed::Int26_6[x_pos * 64],
        Math::Fixed::Int26_6[y_pos * 64]
      )

      draw(text)
    end
  end
end
