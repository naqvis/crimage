require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # MarkerType defines pre-built marker shapes for scatter plots.
  enum MarkerType
    Circle
    Square
    Diamond
    Triangle
    TriangleDown
    Cross # X shape
    Plus  # + shape
    Star
  end

  # MarkerStyle defines the appearance of a marker.
  class MarkerStyle
    property type : MarkerType
    property size : Int32
    property fill_color : Color::Color?
    property stroke_color : Color::Color?
    property stroke_thickness : Int32

    def initialize(@type = MarkerType::Circle, @size = 8,
                   @fill_color = nil, @stroke_color = nil, @stroke_thickness = 1)
    end

    # Preset: filled marker
    def self.filled(type : MarkerType, color : Color::Color, size : Int32 = 8) : MarkerStyle
      new(type, size, fill_color: color)
    end

    # Preset: outlined marker
    def self.outlined(type : MarkerType, color : Color::Color, size : Int32 = 8, thickness : Int32 = 2) : MarkerStyle
      new(type, size, stroke_color: color, stroke_thickness: thickness)
    end

    # Preset: filled with outline
    def self.filled_outlined(type : MarkerType, fill : Color::Color, stroke : Color::Color,
                             size : Int32 = 8, thickness : Int32 = 1) : MarkerStyle
      new(type, size, fill_color: fill, stroke_color: stroke, stroke_thickness: thickness)
    end
  end

  # Draws a marker at the specified position.
  #
  # Example:
  # ```
  # # Scatter plot markers
  # style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED)
  # data_points.each do |point|
  #   CrImage::Draw.marker(img, point, style)
  # end
  # ```
  def self.marker(img : Image, center : Point, style : MarkerStyle)
    case style.type
    when .circle?
      draw_circle_marker(img, center, style)
    when .square?
      draw_square_marker(img, center, style)
    when .diamond?
      draw_diamond_marker(img, center, style)
    when .triangle?
      draw_triangle_marker(img, center, style, up: true)
    when .triangle_down?
      draw_triangle_marker(img, center, style, up: false)
    when .cross?
      draw_cross_marker(img, center, style)
    when .plus?
      draw_plus_marker(img, center, style)
    when .star?
      draw_star_marker(img, center, style)
    end
  end

  # Draw multiple markers at once (for scatter plots)
  def self.markers(img : Image, points : Array(Point), style : MarkerStyle)
    points.each { |p| marker(img, p, style) }
  end

  private def self.draw_circle_marker(img : Image, center : Point, style : MarkerStyle)
    radius = style.size // 2

    if fill = style.fill_color
      circle_style = CircleStyle.new(fill, fill: true)
      circle(img, center, radius, circle_style)
    end

    if stroke = style.stroke_color
      circle_style = CircleStyle.new(stroke, fill: false, thickness: style.stroke_thickness)
      circle(img, center, radius, circle_style)
    end
  end

  private def self.draw_square_marker(img : Image, center : Point, style : MarkerStyle)
    half = style.size // 2
    points = [
      Point.new(center.x - half, center.y - half),
      Point.new(center.x + half, center.y - half),
      Point.new(center.x + half, center.y + half),
      Point.new(center.x - half, center.y + half),
    ]

    if fill = style.fill_color
      poly_style = PolygonStyle.new(fill_color: fill)
      polygon(img, points, poly_style)
    end

    if stroke = style.stroke_color
      poly_style = PolygonStyle.new(outline_color: stroke)
      polygon(img, points, poly_style)
    end
  end

  private def self.draw_diamond_marker(img : Image, center : Point, style : MarkerStyle)
    half = style.size // 2
    points = [
      Point.new(center.x, center.y - half),
      Point.new(center.x + half, center.y),
      Point.new(center.x, center.y + half),
      Point.new(center.x - half, center.y),
    ]

    if fill = style.fill_color
      poly_style = PolygonStyle.new(fill_color: fill)
      polygon(img, points, poly_style)
    end

    if stroke = style.stroke_color
      poly_style = PolygonStyle.new(outline_color: stroke)
      polygon(img, points, poly_style)
    end
  end

  private def self.draw_triangle_marker(img : Image, center : Point, style : MarkerStyle, up : Bool)
    half = style.size // 2
    height = (style.size * 0.866).round.to_i # equilateral triangle height

    points = if up
               [
                 Point.new(center.x, center.y - half),
                 Point.new(center.x + half, center.y + height // 2),
                 Point.new(center.x - half, center.y + height // 2),
               ]
             else
               [
                 Point.new(center.x, center.y + half),
                 Point.new(center.x + half, center.y - height // 2),
                 Point.new(center.x - half, center.y - height // 2),
               ]
             end

    if fill = style.fill_color
      poly_style = PolygonStyle.new(fill_color: fill)
      polygon(img, points, poly_style)
    end

    if stroke = style.stroke_color
      poly_style = PolygonStyle.new(outline_color: stroke)
      polygon(img, points, poly_style)
    end
  end

  private def self.draw_cross_marker(img : Image, center : Point, style : MarkerStyle)
    half = style.size // 2
    color = style.stroke_color || style.fill_color || Color::BLACK
    line_style = LineStyle.new(color, style.stroke_thickness)

    # X shape
    line(img, Point.new(center.x - half, center.y - half),
      Point.new(center.x + half, center.y + half), line_style)
    line(img, Point.new(center.x + half, center.y - half),
      Point.new(center.x - half, center.y + half), line_style)
  end

  private def self.draw_plus_marker(img : Image, center : Point, style : MarkerStyle)
    half = style.size // 2
    color = style.stroke_color || style.fill_color || Color::BLACK
    line_style = LineStyle.new(color, style.stroke_thickness)

    # + shape
    line(img, Point.new(center.x - half, center.y),
      Point.new(center.x + half, center.y), line_style)
    line(img, Point.new(center.x, center.y - half),
      Point.new(center.x, center.y + half), line_style)
  end

  private def self.draw_star_marker(img : Image, center : Point, style : MarkerStyle)
    outer_r = style.size // 2
    inner_r = outer_r // 2
    points = [] of Point

    # 5-pointed star
    5.times do |i|
      # Outer point
      angle = -::Math::PI / 2 + i * 2 * ::Math::PI / 5
      points << Point.new(
        (center.x + outer_r * ::Math.cos(angle)).round.to_i,
        (center.y + outer_r * ::Math.sin(angle)).round.to_i
      )

      # Inner point
      angle += ::Math::PI / 5
      points << Point.new(
        (center.x + inner_r * ::Math.cos(angle)).round.to_i,
        (center.y + inner_r * ::Math.sin(angle)).round.to_i
      )
    end

    if fill = style.fill_color
      poly_style = PolygonStyle.new(fill_color: fill)
      polygon(img, points, poly_style)
    end

    if stroke = style.stroke_color
      poly_style = PolygonStyle.new(outline_color: stroke)
      polygon(img, points, poly_style)
    end
  end
end
