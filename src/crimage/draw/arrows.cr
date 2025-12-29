require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # ArrowHead defines the style of an arrow head.
  enum ArrowHeadType
    None     # No arrow head
    Triangle # Filled triangle (default)
    Open     # Open V shape
    Stealth  # Narrow pointed triangle
    Circle   # Filled circle
    Diamond  # Filled diamond
    Square   # Filled square
  end

  # ArrowStyle defines the appearance of an arrow.
  class ArrowStyle
    property color : Color::Color
    property thickness : Int32
    property head_type : ArrowHeadType
    property head_size : Int32    # Size of arrow head
    property head_at_start : Bool # Arrow head at start point
    property head_at_end : Bool   # Arrow head at end point
    property anti_alias : Bool

    def initialize(@color, @thickness = 1, @head_type = ArrowHeadType::Triangle,
                   @head_size = 10, @head_at_start = false, @head_at_end = true,
                   @anti_alias = false)
    end

    # Preset: single arrow (head at end)
    def self.single(color : Color::Color, thickness : Int32 = 2, head_size : Int32 = 12) : ArrowStyle
      new(color, thickness, head_size: head_size)
    end

    # Preset: double arrow (heads at both ends)
    def self.double(color : Color::Color, thickness : Int32 = 2, head_size : Int32 = 12) : ArrowStyle
      new(color, thickness, head_size: head_size, head_at_start: true, head_at_end: true)
    end

    # Preset: open arrow head
    def self.open(color : Color::Color, thickness : Int32 = 2, head_size : Int32 = 12) : ArrowStyle
      new(color, thickness, ArrowHeadType::Open, head_size: head_size)
    end
  end

  # Draws a line with arrow heads.
  #
  # Example:
  # ```
  # # Simple arrow
  # style = CrImage::Draw::ArrowStyle.single(CrImage::Color::BLACK)
  # CrImage::Draw.arrow(img, CrImage.point(50, 100), CrImage.point(200, 100), style)
  #
  # # Double-headed arrow
  # style = CrImage::Draw::ArrowStyle.double(CrImage::Color::RED, thickness: 3)
  # CrImage::Draw.arrow(img, CrImage.point(50, 150), CrImage.point(200, 150), style)
  # ```
  def self.arrow(img : Image, p1 : Point, p2 : Point, style : ArrowStyle)
    # Calculate direction vector
    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64
    length = ::Math.sqrt(dx * dx + dy * dy)

    return if length < 1

    # Unit vector
    ux = dx / length
    uy = dy / length

    # Adjust line endpoints to not overlap with arrow heads
    line_start = p1
    line_end = p2

    head_length = (style.head_size * 0.866).to_i # cos(30°) for triangle

    if style.head_at_start && style.head_type != ArrowHeadType::None
      line_start = Point.new(
        (p1.x + ux * head_length).round.to_i,
        (p1.y + uy * head_length).round.to_i
      )
    end

    if style.head_at_end && style.head_type != ArrowHeadType::None
      line_end = Point.new(
        (p2.x - ux * head_length).round.to_i,
        (p2.y - uy * head_length).round.to_i
      )
    end

    # Draw the line
    line_style = LineStyle.new(style.color, style.thickness, style.anti_alias)
    line(img, line_start, line_end, line_style)

    # Draw arrow heads
    if style.head_at_start
      draw_arrow_head(img, p1.x.to_f64, p1.y.to_f64, -ux, -uy, style)
    end

    if style.head_at_end
      draw_arrow_head(img, p2.x.to_f64, p2.y.to_f64, ux, uy, style)
    end
  end

  private def self.draw_arrow_head(img : Image, tip_x : Float64, tip_y : Float64,
                                   dir_x : Float64, dir_y : Float64, style : ArrowStyle)
    size = style.head_size.to_f64

    # Perpendicular vector
    perp_x = -dir_y
    perp_y = dir_x

    case style.head_type
    when .triangle?, .stealth?
      # Triangle arrow head
      width_factor = style.head_type.stealth? ? 0.3 : 0.5
      back_x = tip_x - dir_x * size
      back_y = tip_y - dir_y * size

      points = [
        Point.new(tip_x.round.to_i, tip_y.round.to_i),
        Point.new((back_x + perp_x * size * width_factor).round.to_i,
          (back_y + perp_y * size * width_factor).round.to_i),
        Point.new((back_x - perp_x * size * width_factor).round.to_i,
          (back_y - perp_y * size * width_factor).round.to_i),
      ]

      poly_style = PolygonStyle.new(fill_color: style.color)
      polygon(img, points, poly_style)
    when .open?
      # Open V shape
      back_x = tip_x - dir_x * size
      back_y = tip_y - dir_y * size

      left_x = (back_x + perp_x * size * 0.5).round.to_i
      left_y = (back_y + perp_y * size * 0.5).round.to_i
      right_x = (back_x - perp_x * size * 0.5).round.to_i
      right_y = (back_y - perp_y * size * 0.5).round.to_i

      line_style = LineStyle.new(style.color, style.thickness, style.anti_alias)
      line(img, Point.new(left_x, left_y), Point.new(tip_x.round.to_i, tip_y.round.to_i), line_style)
      line(img, Point.new(right_x, right_y), Point.new(tip_x.round.to_i, tip_y.round.to_i), line_style)
    when .circle?
      radius = (size / 2).round.to_i
      center_x = (tip_x - dir_x * radius).round.to_i
      center_y = (tip_y - dir_y * radius).round.to_i
      circle_style = CircleStyle.new(style.color, fill: true)
      circle(img, Point.new(center_x, center_y), radius, circle_style)
    when .diamond?
      half = size / 2
      points = [
        Point.new(tip_x.round.to_i, tip_y.round.to_i),
        Point.new((tip_x - dir_x * half + perp_x * half).round.to_i,
          (tip_y - dir_y * half + perp_y * half).round.to_i),
        Point.new((tip_x - dir_x * size).round.to_i, (tip_y - dir_y * size).round.to_i),
        Point.new((tip_x - dir_x * half - perp_x * half).round.to_i,
          (tip_y - dir_y * half - perp_y * half).round.to_i),
      ]
      poly_style = PolygonStyle.new(fill_color: style.color)
      polygon(img, points, poly_style)
    when .square?
      half = size / 2
      center_x = tip_x - dir_x * half
      center_y = tip_y - dir_y * half
      points = [
        Point.new((center_x + perp_x * half + dir_x * half).round.to_i,
          (center_y + perp_y * half + dir_y * half).round.to_i),
        Point.new((center_x - perp_x * half + dir_x * half).round.to_i,
          (center_y - perp_y * half + dir_y * half).round.to_i),
        Point.new((center_x - perp_x * half - dir_x * half).round.to_i,
          (center_y - perp_y * half - dir_y * half).round.to_i),
        Point.new((center_x + perp_x * half - dir_x * half).round.to_i,
          (center_y + perp_y * half - dir_y * half).round.to_i),
      ]
      poly_style = PolygonStyle.new(fill_color: style.color)
      polygon(img, points, poly_style)
    end
  end
end
