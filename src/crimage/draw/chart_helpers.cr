require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # LegendItem represents a single entry in a chart legend.
  struct LegendItem
    property label : String
    property color : Color::Color
    property pattern : Pattern?

    def initialize(@label, @color, @pattern = nil)
    end
  end

  # LegendStyle defines the appearance of a chart legend.
  class LegendStyle
    property background : Color::Color?
    property border_color : Color::Color?
    property text_color : Color::Color
    property font_size : Int32
    property swatch_size : Int32
    property padding : Int32
    property spacing : Int32
    property orientation : Symbol # :horizontal or :vertical

    def initialize(
      @background = nil,
      @border_color = nil,
      @text_color = Color::BLACK,
      @font_size = 12,
      @swatch_size = 16,
      @padding = 8,
      @spacing = 4,
      @orientation = :vertical,
    )
    end
  end

  # Draws a chart legend box with color swatches and labels.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `position` : Top-left corner of the legend
  # - `items` : Array of legend items (label + color/pattern)
  # - `style` : Legend appearance settings
  # - `font` : Font face for labels (optional)
  #
  # Returns: Rectangle bounds of the drawn legend
  #
  # Example:
  # ```
  # items = [
  #   CrImage::Draw::LegendItem.new("Sales", CrImage::Color::BLUE),
  #   CrImage::Draw::LegendItem.new("Costs", CrImage::Color::RED),
  # ]
  # style = CrImage::Draw::LegendStyle.new(background: CrImage::Color::WHITE)
  # CrImage::Draw.legend_box(img, CrImage.point(10, 10), items, style, font)
  # ```
  def self.legend_box(img : Image, position : Point, items : Array(LegendItem),
                      style : LegendStyle, font : CrImage::Font::Face? = nil) : Rectangle
    return Rectangle.new(position, position) if items.empty?

    bounds = img.bounds
    swatch = style.swatch_size
    pad = style.padding
    space = style.spacing

    # Calculate legend dimensions
    if style.orientation == :horizontal
      # Horizontal layout: items side by side
      total_width = pad * 2
      items.each_with_index do |item, i|
        total_width += swatch + space # swatch + gap to text
        # Estimate text width (rough: 7 pixels per char at size 12)
        char_width = (style.font_size * 0.6).to_i
        total_width += item.label.size * char_width
        total_width += space * 2 if i < items.size - 1 # gap between items
      end
      total_height = pad * 2 + swatch
    else
      # Vertical layout: items stacked
      max_label_width = 0
      items.each do |item|
        char_width = (style.font_size * 0.6).to_i
        label_width = item.label.size * char_width
        max_label_width = [max_label_width, label_width].max
      end
      total_width = pad * 2 + swatch + space + max_label_width
      total_height = pad * 2 + items.size * swatch + (items.size - 1) * space
    end

    # Draw background
    legend_rect = Rectangle.new(
      position,
      Point.new(position.x + total_width, position.y + total_height)
    )

    if bg = style.background
      rect_style = RectStyle.new(fill_color: bg)
      rectangle(img, legend_rect, rect_style)
    end

    # Draw border
    if border = style.border_color
      rect_style = RectStyle.new(outline_color: border)
      rectangle(img, legend_rect, rect_style)
    end

    # Draw items
    if style.orientation == :horizontal
      x = position.x + pad
      y = position.y + pad

      items.each_with_index do |item, i|
        # Draw swatch
        swatch_rect = Rectangle.new(
          Point.new(x, y),
          Point.new(x + swatch, y + swatch)
        )

        if pattern = item.pattern
          fill_rect_pattern(img, swatch_rect, pattern)
        else
          rect_style = RectStyle.new(fill_color: item.color)
          rectangle(img, swatch_rect, rect_style)
        end

        # Draw swatch border
        rect_style = RectStyle.new(outline_color: style.text_color)
        rectangle(img, swatch_rect, rect_style)

        x += swatch + space

        # Draw label
        if f = font
          text(img, item.label, Point.new(x, y + swatch // 2 + style.font_size // 3),
            f, style.text_color)
        end

        char_width = (style.font_size * 0.6).to_i
        x += item.label.size * char_width + space * 2
      end
    else
      x = position.x + pad
      y = position.y + pad

      items.each do |item|
        # Draw swatch
        swatch_rect = Rectangle.new(
          Point.new(x, y),
          Point.new(x + swatch, y + swatch)
        )

        if pattern = item.pattern
          fill_rect_pattern(img, swatch_rect, pattern)
        else
          rect_style = RectStyle.new(fill_color: item.color)
          rectangle(img, swatch_rect, rect_style)
        end

        # Draw swatch border
        rect_style = RectStyle.new(outline_color: style.text_color)
        rectangle(img, swatch_rect, rect_style)

        # Draw label
        if f = font
          text(img, item.label, Point.new(x + swatch + space, y + swatch // 2 + style.font_size // 3),
            f, style.text_color)
        end

        y += swatch + space
      end
    end

    legend_rect
  end

  # ColorScaleStyle defines the appearance of a color scale/gradient bar.
  class ColorScaleStyle
    property width : Int32
    property height : Int32
    property orientation : Symbol # :horizontal or :vertical
    property show_labels : Bool
    property label_count : Int32
    property text_color : Color::Color
    property font_size : Int32
    property border_color : Color::Color?

    def initialize(
      @width = 200,
      @height = 20,
      @orientation = :horizontal,
      @show_labels = true,
      @label_count = 5,
      @text_color = Color::BLACK,
      @font_size = 10,
      @border_color = Color::BLACK,
    )
    end
  end

  # Draws a color scale bar (gradient legend) for heatmaps.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `position` : Top-left corner of the scale
  # - `min_value` : Minimum value label
  # - `max_value` : Maximum value label
  # - `gradient` : Gradient to display
  # - `style` : Scale appearance settings
  # - `font` : Font for labels (optional)
  #
  # Example:
  # ```
  # gradient = CrImage::Draw::LinearGradient.new(...)
  # style = CrImage::Draw::ColorScaleStyle.new(width: 150, height: 15)
  # CrImage::Draw.color_scale(img, CrImage.point(10, 10), 0.0, 100.0, gradient, style, font)
  # ```
  def self.color_scale(img : Image, position : Point, min_value : Float64, max_value : Float64,
                       gradient : LinearGradient, style : ColorScaleStyle, font : CrImage::Font::Face? = nil)
    bounds = img.bounds

    if style.orientation == :horizontal
      # Draw horizontal gradient bar
      (0...style.width).each do |x|
        t = x.to_f64 / (style.width - 1)
        color = gradient.color_at(t)

        (0...style.height).each do |y|
          px = position.x + x
          py = position.y + y
          next if px < bounds.min.x || px >= bounds.max.x
          next if py < bounds.min.y || py >= bounds.max.y
          img.set(px, py, color)
        end
      end

      # Draw border
      if border = style.border_color
        bar_rect = Rectangle.new(
          position,
          Point.new(position.x + style.width, position.y + style.height)
        )
        rect_style = RectStyle.new(outline_color: border)
        rectangle(img, bar_rect, rect_style)
      end

      # Draw labels
      if style.show_labels && font
        label_y = position.y + style.height + 2 + style.font_size

        style.label_count.times do |i|
          t = i.to_f64 / (style.label_count - 1)
          value = min_value + t * (max_value - min_value)
          label = format_number(value)

          label_x = position.x + (t * style.width).to_i
          # Center the label
          char_width = (style.font_size * 0.5).to_i
          label_x -= (label.size * char_width) // 2

          text(img, label, Point.new(label_x, label_y), font, style.text_color)
        end
      end
    else
      # Draw vertical gradient bar
      (0...style.height).each do |y|
        t = 1.0 - y.to_f64 / (style.height - 1) # Invert so high values at top
        color = gradient.color_at(t)

        (0...style.width).each do |x|
          px = position.x + x
          py = position.y + y
          next if px < bounds.min.x || px >= bounds.max.x
          next if py < bounds.min.y || py >= bounds.max.y
          img.set(px, py, color)
        end
      end

      # Draw border
      if border = style.border_color
        bar_rect = Rectangle.new(
          position,
          Point.new(position.x + style.width, position.y + style.height)
        )
        rect_style = RectStyle.new(outline_color: border)
        rectangle(img, bar_rect, rect_style)
      end

      # Draw labels
      if style.show_labels && font
        label_x = position.x + style.width + 4

        style.label_count.times do |i|
          t = i.to_f64 / (style.label_count - 1)
          value = max_value - t * (max_value - min_value) # High at top
          label = format_number(value)

          label_y = position.y + (t * style.height).to_i + style.font_size // 3

          text(img, label, Point.new(label_x, label_y), font, style.text_color)
        end
      end
    end
  end

  # Format a number for display (removes unnecessary decimals)
  private def self.format_number(value : Float64) : String
    if value == value.to_i
      value.to_i.to_s
    elsif value.abs < 0.01 || value.abs >= 1000
      "%.2g" % value
    else
      "%.1f" % value
    end
  end

  # AxisStyle defines the appearance of a chart axis.
  class AxisStyle
    property color : Color::Color
    property thickness : Int32
    property tick_length : Int32
    property tick_count : Int32
    property show_grid : Bool
    property grid_color : Color::Color
    property text_color : Color::Color
    property font_size : Int32

    def initialize(
      @color = Color::BLACK,
      @thickness = 1,
      @tick_length = 5,
      @tick_count = 5,
      @show_grid = false,
      @grid_color = Color::GRAY,
      @text_color = Color::BLACK,
      @font_size = 10,
    )
    end
  end

  # Draws an X axis with ticks and optional labels.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `start_point` : Left end of the axis
  # - `end_point` : Right end of the axis
  # - `min_value` : Minimum axis value
  # - `max_value` : Maximum axis value
  # - `style` : Axis appearance settings
  # - `font` : Font for labels (optional)
  # - `chart_height` : Height of chart area for grid lines (optional)
  def self.x_axis(img : Image, start_point : Point, end_point : Point,
                  min_value : Float64, max_value : Float64, style : AxisStyle,
                  font : CrImage::Font::Face? = nil, chart_height : Int32 = 0)
    # Draw main axis line
    line_style = LineStyle.new(style.color, style.thickness, false)
    line(img, start_point, end_point, line_style)

    axis_length = end_point.x - start_point.x

    # Draw ticks and labels
    style.tick_count.times do |i|
      t = i.to_f64 / (style.tick_count - 1)
      x = start_point.x + (t * axis_length).to_i

      # Draw tick
      tick_start = Point.new(x, start_point.y)
      tick_end = Point.new(x, start_point.y + style.tick_length)
      line(img, tick_start, tick_end, line_style)

      # Draw grid line
      if style.show_grid && chart_height > 0
        grid_style = LineStyle.new(style.grid_color, 1, false)
        grid_start = Point.new(x, start_point.y - chart_height)
        line(img, grid_start, tick_start, grid_style)
      end

      # Draw label
      if f = font
        value = min_value + t * (max_value - min_value)
        label = format_number(value)
        char_width = (style.font_size * 0.5).to_i
        label_x = x - (label.size * char_width) // 2
        label_y = start_point.y + style.tick_length + 2 + style.font_size
        text(img, label, Point.new(label_x, label_y), f, style.text_color)
      end
    end
  end

  # Draws a Y axis with ticks and optional labels.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `start_point` : Bottom end of the axis
  # - `end_point` : Top end of the axis
  # - `min_value` : Minimum axis value
  # - `max_value` : Maximum axis value
  # - `style` : Axis appearance settings
  # - `font` : Font for labels (optional)
  # - `chart_width` : Width of chart area for grid lines (optional)
  def self.y_axis(img : Image, start_point : Point, end_point : Point,
                  min_value : Float64, max_value : Float64, style : AxisStyle,
                  font : CrImage::Font::Face? = nil, chart_width : Int32 = 0)
    # Draw main axis line
    line_style = LineStyle.new(style.color, style.thickness, false)
    line(img, start_point, end_point, line_style)

    axis_length = start_point.y - end_point.y # Y increases downward

    # Draw ticks and labels
    style.tick_count.times do |i|
      t = i.to_f64 / (style.tick_count - 1)
      y = start_point.y - (t * axis_length).to_i

      # Draw tick
      tick_start = Point.new(start_point.x, y)
      tick_end = Point.new(start_point.x - style.tick_length, y)
      line(img, tick_start, tick_end, line_style)

      # Draw grid line
      if style.show_grid && chart_width > 0
        grid_style = LineStyle.new(style.grid_color, 1, false)
        grid_end = Point.new(start_point.x + chart_width, y)
        line(img, tick_start, grid_end, grid_style)
      end

      # Draw label
      if f = font
        value = min_value + t * (max_value - min_value)
        label = format_number(value)
        char_width = (style.font_size * 0.5).to_i
        label_x = start_point.x - style.tick_length - 4 - label.size * char_width
        label_y = y + style.font_size // 3
        text(img, label, Point.new(label_x, label_y), f, style.text_color)
      end
    end
  end

  # Draws a data label with optional background box.
  #
  # Useful for labeling data points on charts.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `text_str` : Label text
  # - `position` : Position for the label
  # - `font` : Font for the label
  # - `font_size` : Font size (for calculating box size)
  # - `text_color` : Text color
  # - `background` : Optional background color
  # - `padding` : Padding around text (if background)
  def self.data_label(img : Image, text_str : String, position : Point, font : CrImage::Font::Face,
                      font_size : Int32, text_color : Color::Color,
                      background : Color::Color? = nil, padding : Int32 = 2)
    char_width = (font_size * 0.6).to_i
    text_width = text_str.size * char_width
    text_height = font_size

    if bg = background
      bg_rect = Rectangle.new(
        Point.new(position.x - padding, position.y - text_height - padding),
        Point.new(position.x + text_width + padding, position.y + padding)
      )
      rect_style = RectStyle.new(fill_color: bg)
      rectangle(img, bg_rect, rect_style)
    end

    text(img, text_str, position, font, text_color)
  end
end
