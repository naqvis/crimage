require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # Strokes a path with a gradient color.
  #
  # The gradient is applied along the path length, useful for:
  # - Progress indicators
  # - Line charts showing value intensity
  # - Decorative effects
  #
  # Example:
  # ```
  # path = CrImage::Draw::Path.new
  #   .move_to(50, 100)
  #   .bezier_to(150, 50, 250, 150, 350, 100)
  #
  # stops = [
  #   CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
  #   CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
  #   CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
  # ]
  #
  # CrImage::Draw.stroke_path_gradient(img, path, stops, thickness: 3)
  # ```
  def self.stroke_path_gradient(img : Image, path : Path, stops : Array(ColorStop),
                                thickness : Int32 = 1, anti_alias : Bool = false)
    points = path.flatten_float
    return if points.size < 2

    stroke_points_gradient(img, points, stops, thickness, anti_alias)
  end

  # Strokes a line with gradient color.
  def self.stroke_line_gradient(img : Image, p1 : Point, p2 : Point,
                                stops : Array(ColorStop), thickness : Int32 = 1)
    points = [{p1.x.to_f64, p1.y.to_f64}, {p2.x.to_f64, p2.y.to_f64}]
    stroke_points_gradient(img, points, stops, thickness, false)
  end

  # Strokes a bezier curve with gradient color.
  def self.stroke_bezier_gradient(img : Image, curve : CubicBezier,
                                  stops : Array(ColorStop), thickness : Int32 = 1,
                                  segments : Int32 = 32)
    points = curve.flatten(segments)
    stroke_points_gradient(img, points, stops, thickness, false)
  end

  # Internal: stroke a series of points with gradient
  private def self.stroke_points_gradient(img : Image, points : Array({Float64, Float64}),
                                          stops : Array(ColorStop), thickness : Int32,
                                          anti_alias : Bool)
    return if points.size < 2

    # Calculate total path length
    total_length = 0.0
    (0...points.size - 1).each do |i|
      dx = points[i + 1][0] - points[i][0]
      dy = points[i + 1][1] - points[i][1]
      total_length += ::Math.sqrt(dx * dx + dy * dy)
    end

    return if total_length < 1

    # Create a temporary gradient for color lookup
    gradient = LinearGradient.new(Point.new(0, 0), Point.new(1, 0), stops)

    # Draw segments with interpolated colors
    current_length = 0.0

    (0...points.size - 1).each do |i|
      p1 = points[i]
      p2 = points[i + 1]

      dx = p2[0] - p1[0]
      dy = p2[1] - p1[1]
      seg_length = ::Math.sqrt(dx * dx + dy * dy)

      # Calculate t at start and end of segment
      t1 = current_length / total_length
      t2 = (current_length + seg_length) / total_length

      # Get colors at segment endpoints
      color1 = gradient.color_at(t1)
      color2 = gradient.color_at(t2)

      # For short segments, use midpoint color
      if seg_length < 3
        mid_t = (t1 + t2) / 2
        color = gradient.color_at(mid_t)
        line_style = LineStyle.new(color, thickness, anti_alias)
        line(img, Point.new(p1[0].round.to_i, p1[1].round.to_i),
          Point.new(p2[0].round.to_i, p2[1].round.to_i), line_style)
      else
        # Subdivide segment for smoother gradient
        sub_segments = [seg_length.to_i // 3, 2].max
        (0...sub_segments).each do |j|
          sub_t1 = j.to_f64 / sub_segments
          sub_t2 = (j + 1).to_f64 / sub_segments

          sp1_x = p1[0] + dx * sub_t1
          sp1_y = p1[1] + dy * sub_t1
          sp2_x = p1[0] + dx * sub_t2
          sp2_y = p1[1] + dy * sub_t2

          # Interpolate color
          global_t = t1 + (t2 - t1) * (sub_t1 + sub_t2) / 2
          color = gradient.color_at(global_t)

          line_style = LineStyle.new(color, thickness, anti_alias)
          line(img, Point.new(sp1_x.round.to_i, sp1_y.round.to_i),
            Point.new(sp2_x.round.to_i, sp2_y.round.to_i), line_style)
        end
      end

      current_length += seg_length
    end
  end

  # Strokes an arc with gradient color.
  #
  # Example:
  # ```
  # # Progress arc (green to red)
  # stops = [
  #   CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
  #   CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
  # ]
  # CrImage::Draw.stroke_arc_gradient(img, center, radius, 0.0, Math::PI, stops, thickness: 5)
  # ```
  def self.stroke_arc_gradient(img : Image, center : Point, radius : Int32,
                               start_angle : Float64, end_angle : Float64,
                               stops : Array(ColorStop), thickness : Int32 = 1)
    # Generate arc points
    arc_length = radius.to_f64 * (end_angle - start_angle).abs
    segments = [arc_length.to_i, 16].max

    points = [] of {Float64, Float64}
    (0..segments).each do |i|
      t = i.to_f64 / segments
      angle = start_angle + (end_angle - start_angle) * t
      x = center.x + radius * ::Math.cos(angle)
      y = center.y + radius * ::Math.sin(angle)
      points << {x, y}
    end

    stroke_points_gradient(img, points, stops, thickness, false)
  end

  # Strokes a ring/donut arc with gradient (for gauge charts).
  def self.stroke_ring_gradient(img : Image, center : Point, inner_radius : Int32,
                                outer_radius : Int32, start_angle : Float64, end_angle : Float64,
                                stops : Array(ColorStop))
    # Use conic gradient fill for the ring
    gradient = ConicGradient.new(center, stops, start_angle: start_angle)
    fill_conic_ring(img, center, inner_radius, outer_radius, gradient,
      start_angle: start_angle, end_angle: end_angle)
  end
end
