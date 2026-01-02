require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # PathCommand represents a single command in a path.
  abstract struct PathCommand
  end

  struct MoveToCommand < PathCommand
    getter x : Float64
    getter y : Float64

    def initialize(@x, @y)
    end
  end

  struct LineToCommand < PathCommand
    getter x : Float64
    getter y : Float64

    def initialize(@x, @y)
    end
  end

  struct QuadraticToCommand < PathCommand
    getter cx : Float64
    getter cy : Float64
    getter x : Float64
    getter y : Float64

    def initialize(@cx, @cy, @x, @y)
    end
  end

  struct CubicToCommand < PathCommand
    getter c1x : Float64
    getter c1y : Float64
    getter c2x : Float64
    getter c2y : Float64
    getter x : Float64
    getter y : Float64

    def initialize(@c1x, @c1y, @c2x, @c2y, @x, @y)
    end
  end

  struct CloseCommand < PathCommand
  end

  # Path is an SVG-like path builder for complex shapes.
  #
  # Supports move_to, line_to, quadratic bezier, cubic bezier, and close commands.
  # Paths can be filled or stroked.
  #
  # Example:
  # ```
  # path = CrImage::Draw::Path.new
  #   .move_to(100, 100)
  #   .line_to(200, 100)
  #   .bezier_to(250, 100, 250, 150, 200, 150)
  #   .line_to(100, 150)
  #   .close
  #
  # CrImage::Draw.fill_path(img, path, CrImage::Color::RED)
  # ```
  class Path
    getter commands : Array(PathCommand)
    @segments_per_curve : Int32

    def initialize(@segments_per_curve = 32)
      @commands = [] of PathCommand
    end

    # Move to a new position without drawing.
    def move_to(x : Number, y : Number) : self
      @commands << MoveToCommand.new(x.to_f64, y.to_f64)
      self
    end

    # Draw a line to the specified position.
    def line_to(x : Number, y : Number) : self
      @commands << LineToCommand.new(x.to_f64, y.to_f64)
      self
    end

    # Draw a quadratic bezier curve to (x, y) with control point (cx, cy).
    def quadratic_to(cx : Number, cy : Number, x : Number, y : Number) : self
      @commands << QuadraticToCommand.new(cx.to_f64, cy.to_f64, x.to_f64, y.to_f64)
      self
    end

    # Draw a cubic bezier curve to (x, y) with control points (c1x, c1y) and (c2x, c2y).
    def bezier_to(c1x : Number, c1y : Number, c2x : Number, c2y : Number, x : Number, y : Number) : self
      @commands << CubicToCommand.new(c1x.to_f64, c1y.to_f64, c2x.to_f64, c2y.to_f64, x.to_f64, y.to_f64)
      self
    end

    # Alias for bezier_to
    def cubic_to(c1x : Number, c1y : Number, c2x : Number, c2y : Number, x : Number, y : Number) : self
      bezier_to(c1x, c1y, c2x, c2y, x, y)
    end

    # Close the current subpath by drawing a line back to the start.
    def close : self
      @commands << CloseCommand.new
      self
    end

    # Returns true if the path is empty.
    def empty? : Bool
      @commands.empty?
    end

    # Flattens the path to an array of points (converts curves to line segments).
    def flatten : Array(Point)
      points = [] of Point
      current_x = 0.0
      current_y = 0.0
      subpath_start_x = 0.0
      subpath_start_y = 0.0

      @commands.each do |cmd|
        case cmd
        when MoveToCommand
          current_x = cmd.x
          current_y = cmd.y
          subpath_start_x = current_x
          subpath_start_y = current_y
          points << Point.new(current_x.round.to_i, current_y.round.to_i)
        when LineToCommand
          current_x = cmd.x
          current_y = cmd.y
          points << Point.new(current_x.round.to_i, current_y.round.to_i)
        when QuadraticToCommand
          flatten_quadratic(points, current_x, current_y, cmd.cx, cmd.cy, cmd.x, cmd.y)
          current_x = cmd.x
          current_y = cmd.y
        when CubicToCommand
          flatten_cubic(points, current_x, current_y, cmd.c1x, cmd.c1y, cmd.c2x, cmd.c2y, cmd.x, cmd.y)
          current_x = cmd.x
          current_y = cmd.y
        when CloseCommand
          if current_x != subpath_start_x || current_y != subpath_start_y
            points << Point.new(subpath_start_x.round.to_i, subpath_start_y.round.to_i)
          end
          current_x = subpath_start_x
          current_y = subpath_start_y
        end
      end

      points
    end

    # Flattens path to float points for higher precision AA rendering.
    def flatten_float : Array({Float64, Float64})
      points = [] of {Float64, Float64}
      current_x = 0.0
      current_y = 0.0
      subpath_start_x = 0.0
      subpath_start_y = 0.0

      @commands.each do |cmd|
        case cmd
        when MoveToCommand
          current_x = cmd.x
          current_y = cmd.y
          subpath_start_x = current_x
          subpath_start_y = current_y
          points << {current_x, current_y}
        when LineToCommand
          current_x = cmd.x
          current_y = cmd.y
          points << {current_x, current_y}
        when QuadraticToCommand
          flatten_quadratic_float(points, current_x, current_y, cmd.cx, cmd.cy, cmd.x, cmd.y)
          current_x = cmd.x
          current_y = cmd.y
        when CubicToCommand
          flatten_cubic_float(points, current_x, current_y, cmd.c1x, cmd.c1y, cmd.c2x, cmd.c2y, cmd.x, cmd.y)
          current_x = cmd.x
          current_y = cmd.y
        when CloseCommand
          if current_x != subpath_start_x || current_y != subpath_start_y
            points << {subpath_start_x, subpath_start_y}
          end
          current_x = subpath_start_x
          current_y = subpath_start_y
        end
      end

      points
    end

    private def flatten_quadratic(points : Array(Point), x0 : Float64, y0 : Float64,
                                  cx : Float64, cy : Float64, x1 : Float64, y1 : Float64)
      (1..@segments_per_curve).each do |i|
        t = i.to_f64 / @segments_per_curve
        inv_t = 1.0 - t
        x = inv_t * inv_t * x0 + 2 * inv_t * t * cx + t * t * x1
        y = inv_t * inv_t * y0 + 2 * inv_t * t * cy + t * t * y1
        points << Point.new(x.round.to_i, y.round.to_i)
      end
    end

    private def flatten_cubic(points : Array(Point), x0 : Float64, y0 : Float64,
                              c1x : Float64, c1y : Float64, c2x : Float64, c2y : Float64,
                              x1 : Float64, y1 : Float64)
      (1..@segments_per_curve).each do |i|
        t = i.to_f64 / @segments_per_curve
        inv_t = 1.0 - t
        inv_t_sq = inv_t * inv_t
        inv_t_cu = inv_t_sq * inv_t
        t_sq = t * t
        t_cu = t_sq * t

        x = inv_t_cu * x0 + 3 * inv_t_sq * t * c1x + 3 * inv_t * t_sq * c2x + t_cu * x1
        y = inv_t_cu * y0 + 3 * inv_t_sq * t * c1y + 3 * inv_t * t_sq * c2y + t_cu * y1
        points << Point.new(x.round.to_i, y.round.to_i)
      end
    end

    private def flatten_quadratic_float(points : Array({Float64, Float64}), x0 : Float64, y0 : Float64,
                                        cx : Float64, cy : Float64, x1 : Float64, y1 : Float64)
      (1..@segments_per_curve).each do |i|
        t = i.to_f64 / @segments_per_curve
        inv_t = 1.0 - t
        x = inv_t * inv_t * x0 + 2 * inv_t * t * cx + t * t * x1
        y = inv_t * inv_t * y0 + 2 * inv_t * t * cy + t * t * y1
        points << {x, y}
      end
    end

    private def flatten_cubic_float(points : Array({Float64, Float64}), x0 : Float64, y0 : Float64,
                                    c1x : Float64, c1y : Float64, c2x : Float64, c2y : Float64,
                                    x1 : Float64, y1 : Float64)
      (1..@segments_per_curve).each do |i|
        t = i.to_f64 / @segments_per_curve
        inv_t = 1.0 - t
        inv_t_sq = inv_t * inv_t
        inv_t_cu = inv_t_sq * inv_t
        t_sq = t * t
        t_cu = t_sq * t

        x = inv_t_cu * x0 + 3 * inv_t_sq * t * c1x + 3 * inv_t * t_sq * c2x + t_cu * x1
        y = inv_t_cu * y0 + 3 * inv_t_sq * t * c1y + 3 * inv_t * t_sq * c2y + t_cu * y1
        points << {x, y}
      end
    end
  end

  # PathStyle defines the appearance for path stroking.
  class PathStyle
    property color : Color::Color
    property thickness : Int32
    property anti_alias : Bool

    def initialize(@color, @thickness = 1, @anti_alias = false)
    end
  end

  # Fills a path with a solid color.
  #
  # Uses scanline fill algorithm on the flattened path.
  # For anti-aliased fills, use fill_path_aa.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `path` : The path to fill
  # - `color` : Fill color
  #
  # Example:
  # ```
  # path = CrImage::Draw::Path.new
  #   .move_to(100, 50)
  #   .bezier_to(150, 50, 200, 100, 200, 150)
  #   .line_to(100, 150)
  #   .close
  # CrImage::Draw.fill_path(img, path, CrImage::Color::BLUE)
  # ```
  def self.fill_path(img : Image, path : Path, color : Color::Color)
    points = path.flatten
    return if points.size < 3
    scanline_fill_polygon(img, points, color)
  end

  # Fills a path with anti-aliased edges.
  #
  # Uses signed area coverage for smooth edges.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `path` : The path to fill
  # - `color` : Fill color
  def self.fill_path_aa(img : Image, path : Path, color : Color::Color)
    points = path.flatten_float
    return if points.size < 3
    fill_polygon_aa_float(img, points, color)
  end

  # Strokes a path outline.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `path` : The path to stroke
  # - `style` : Stroke appearance settings
  def self.stroke_path(img : Image, path : Path, style : PathStyle)
    points = path.flatten
    return if points.size < 2

    line_style = LineStyle.new(style.color, style.thickness, style.anti_alias)

    (0...points.size - 1).each do |i|
      line(img, points[i], points[i + 1], line_style)
    end
  end

  # CubicBezier represents a cubic bezier curve for band filling.
  struct CubicBezier
    getter p0 : {Float64, Float64}
    getter p1 : {Float64, Float64}
    getter p2 : {Float64, Float64}
    getter p3 : {Float64, Float64}

    def initialize(p0 : Point, p1 : Point, p2 : Point, p3 : Point)
      @p0 = {p0.x.to_f64, p0.y.to_f64}
      @p1 = {p1.x.to_f64, p1.y.to_f64}
      @p2 = {p2.x.to_f64, p2.y.to_f64}
      @p3 = {p3.x.to_f64, p3.y.to_f64}
    end

    def initialize(@p0 : {Float64, Float64}, @p1 : {Float64, Float64},
                   @p2 : {Float64, Float64}, @p3 : {Float64, Float64})
    end

    # Evaluate the bezier at parameter t (0..1)
    def at(t : Float64) : {Float64, Float64}
      inv_t = 1.0 - t
      inv_t_sq = inv_t * inv_t
      inv_t_cu = inv_t_sq * inv_t
      t_sq = t * t
      t_cu = t_sq * t

      x = inv_t_cu * @p0[0] + 3 * inv_t_sq * t * @p1[0] + 3 * inv_t * t_sq * @p2[0] + t_cu * @p3[0]
      y = inv_t_cu * @p0[1] + 3 * inv_t_sq * t * @p1[1] + 3 * inv_t * t_sq * @p2[1] + t_cu * @p3[1]
      {x, y}
    end

    # Flatten to array of points
    def flatten(segments : Int32 = 32) : Array({Float64, Float64})
      points = [{@p0[0], @p0[1]}]
      (1..segments).each do |i|
        t = i.to_f64 / segments
        points << at(t)
      end
      points
    end
  end

  # Fills the area between two bezier curves (for Sankey diagrams).
  #
  # Creates a filled band shape bounded by two cubic bezier curves.
  # The top curve goes from left to right, bottom curve goes from right to left
  # to form a closed shape.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `top_curve` : Top edge bezier (p0, ctrl1, ctrl2, p1)
  # - `bottom_curve` : Bottom edge bezier (p0, ctrl1, ctrl2, p1)
  # - `color` : Fill color
  # - `segments` : Curve resolution (default: 32)
  # - `anti_alias` : Enable anti-aliased edges (default: false)
  #
  # Example:
  # ```
  # # Sankey flow band
  # top = {
  #   CrImage.point(100, 100), # start
  #   CrImage.point(200, 100), # ctrl1
  #   CrImage.point(300, 150), # ctrl2
  #   CrImage.point(400, 150), # end
  # }
  # bottom = {
  #   CrImage.point(100, 130), # start
  #   CrImage.point(200, 130), # ctrl1
  #   CrImage.point(300, 180), # ctrl2
  #   CrImage.point(400, 180), # end
  # }
  # CrImage::Draw.fill_bezier_band(img, top, bottom, CrImage::Color::BLUE)
  # ```
  def self.fill_bezier_band(img : Image,
                            top_curve : {Point, Point, Point, Point},
                            bottom_curve : {Point, Point, Point, Point},
                            color : Color::Color,
                            segments : Int32 = 32,
                            anti_alias : Bool = false)
    top = CubicBezier.new(top_curve[0], top_curve[1], top_curve[2], top_curve[3])
    bottom = CubicBezier.new(bottom_curve[0], bottom_curve[1], bottom_curve[2], bottom_curve[3])

    fill_bezier_band_impl(img, top, bottom, color, segments, anti_alias)
  end

  # Fills the area between two bezier curves (tuple version).
  def self.fill_bezier_band(img : Image,
                            top_curve : { {Float64, Float64}, {Float64, Float64}, {Float64, Float64}, {Float64, Float64} },
                            bottom_curve : { {Float64, Float64}, {Float64, Float64}, {Float64, Float64}, {Float64, Float64} },
                            color : Color::Color,
                            segments : Int32 = 32,
                            anti_alias : Bool = false)
    top = CubicBezier.new(top_curve[0], top_curve[1], top_curve[2], top_curve[3])
    bottom = CubicBezier.new(bottom_curve[0], bottom_curve[1], bottom_curve[2], bottom_curve[3])

    fill_bezier_band_impl(img, top, bottom, color, segments, anti_alias)
  end

  private def self.fill_bezier_band_impl(img : Image, top : CubicBezier, bottom : CubicBezier,
                                         color : Color::Color, segments : Int32, anti_alias : Bool)
    # Flatten both curves
    top_points = top.flatten(segments)
    bottom_points = bottom.flatten(segments)

    # Build polygon: top curve forward, bottom curve backward
    polygon_points = [] of {Float64, Float64}

    # Add top curve points (left to right)
    top_points.each { |p| polygon_points << p }

    # Add bottom curve points (right to left)
    bottom_points.reverse_each { |p| polygon_points << p }

    if anti_alias
      fill_polygon_aa_float(img, polygon_points, color)
    else
      # Convert to integer points for standard fill
      int_points = polygon_points.map { |p| Point.new(p[0].round.to_i, p[1].round.to_i) }
      scanline_fill_polygon(img, int_points, color)
    end
  end

  # Anti-aliased polygon fill using float coordinates.
  #
  # Uses coverage-based anti-aliasing for smooth edges.
  # Uses non-zero winding rule for proper handling of complex polygons.
  private def self.fill_polygon_aa_float(img : Image, points : Array({Float64, Float64}), color : Color::Color)
    return if points.size < 3

    bounds = img.bounds

    # Find bounding box
    min_x = points.map(&.[0]).min.floor.to_i
    max_x = points.map(&.[0]).max.ceil.to_i
    min_y = points.map(&.[1]).min.floor.to_i
    max_y = points.map(&.[1]).max.ceil.to_i

    # Clip to image bounds
    min_x = [min_x, bounds.min.x].max
    max_x = [max_x, bounds.max.x - 1].min
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    # For each scanline
    (min_y..max_y).each do |y|
      y_f = y.to_f64 + 0.5 # Sample at pixel center

      # Find all edge intersections with winding direction
      # Store {x_intersection, direction} where direction is +1 (upward) or -1 (downward)
      intersections = [] of {Float64, Int32}

      points.size.times do |i|
        p1 = points[i]
        p2 = points[(i + 1) % points.size]

        y1, y2 = p1[1], p2[1]
        next if y1 == y2 # Skip horizontal edges

        # Check if scanline intersects this edge (using half-open interval)
        if (y1 <= y_f && y2 > y_f)
          # Edge going upward (in screen coords, y increases downward, so this is "down")
          t = (y_f - y1) / (y2 - y1)
          x = p1[0] + t * (p2[0] - p1[0])
          intersections << {x, 1}
        elsif (y2 <= y_f && y1 > y_f)
          # Edge going downward
          t = (y_f - y1) / (y2 - y1)
          x = p1[0] + t * (p2[0] - p1[0])
          intersections << {x, -1}
        end
      end

      # Sort by x coordinate
      intersections.sort_by! { |ix| ix[0] }

      # Use non-zero winding rule to determine fill regions
      # Track winding number as we scan left to right
      winding = 0
      i = 0

      while i < intersections.size
        x_val, dir = intersections[i]
        prev_winding = winding
        winding += dir

        # Transition from outside (winding == 0) to inside (winding != 0)
        if prev_winding == 0 && winding != 0
          x1 = x_val

          # Find where we exit (winding returns to 0)
          j = i + 1
          while j < intersections.size
            x_val2, dir2 = intersections[j]
            winding += dir2
            if winding == 0
              x2 = x_val2

              # Fill pixels between x1 and x2
              x_start = x1.floor.to_i
              x_end = x2.ceil.to_i

              x_start = [x_start, min_x].max
              x_end = [x_end, max_x].min

              (x_start..x_end).each do |x|
                x_f = x.to_f64

                # Calculate coverage for this pixel
                coverage = calculate_pixel_coverage(x_f, y_f - 0.5, x1, x2, points)

                if coverage >= 0.99
                  plot_aa(img, x, y, color, 1.0)
                elsif coverage > 0.01
                  plot_aa(img, x, y, color, coverage)
                end
              end

              i = j
              break
            end
            j += 1
          end

          # If we never found exit, break to avoid infinite loop
          if winding != 0
            break
          end
        end

        i += 1
      end
    end
  end

  # Calculate pixel coverage for anti-aliasing
  private def self.calculate_pixel_coverage(px : Float64, py : Float64,
                                            x1 : Float64, x2 : Float64,
                                            points : Array({Float64, Float64})) : Float64
    # Simple coverage: how much of the pixel is inside the fill region
    # For edge pixels, calculate partial coverage

    # Check if pixel center is fully inside
    if px >= x1 + 0.5 && px <= x2 - 0.5
      return 1.0
    end

    # Edge pixel - calculate coverage based on distance to edge
    if px < x1 + 0.5
      # Left edge
      coverage = (px + 0.5) - x1
      return [[coverage, 0.0].max, 1.0].min
    elsif px > x2 - 0.5
      # Right edge
      coverage = x2 - (px - 0.5)
      return [[coverage, 0.0].max, 1.0].min
    end

    1.0
  end

  # Fills a polygon with anti-aliased edges.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of polygon vertices
  # - `color` : Fill color
  #
  # Example:
  # ```
  # points = [
  #   CrImage.point(100, 50),
  #   CrImage.point(200, 150),
  #   CrImage.point(50, 150),
  # ]
  # CrImage::Draw.fill_polygon_aa(img, points, CrImage::Color::RED)
  # ```
  def self.fill_polygon_aa(img : Image, points : Array(Point), color : Color::Color)
    return if points.size < 3
    float_points = points.map { |p| {p.x.to_f64, p.y.to_f64} }
    fill_polygon_aa_float(img, float_points, color)
  end

  # Fills a polygon with a linear gradient.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of polygon vertices
  # - `gradient` : Linear gradient definition
  #
  # Example:
  # ```
  # points = [CrImage.point(100, 50), CrImage.point(200, 150), CrImage.point(50, 150)]
  # gradient = CrImage::Draw::LinearGradient.new(
  #   CrImage.point(50, 50), CrImage.point(200, 150),
  #   [CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  #    CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE)]
  # )
  # CrImage::Draw.fill_polygon_gradient(img, points, gradient)
  # ```
  def self.fill_polygon_gradient(img : Image, points : Array(Point), gradient : LinearGradient)
    return if points.size < 3

    bounds = img.bounds

    # Find bounding box
    min_x = points.map(&.x).min
    max_x = points.map(&.x).max
    min_y = points.map(&.y).min
    max_y = points.map(&.y).max

    # Clip to image bounds
    min_x = [min_x, bounds.min.x].max
    max_x = [max_x, bounds.max.x - 1].min
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    # Calculate gradient vector
    dx = (gradient.end_point.x - gradient.start_point.x).to_f64
    dy = (gradient.end_point.y - gradient.start_point.y).to_f64
    length_sq = dx * dx + dy * dy

    # For each scanline
    (min_y..max_y).each do |y|
      # Find intersections with polygon edges
      intersections = [] of Int32

      points.size.times do |i|
        p1 = points[i]
        p2 = points[(i + 1) % points.size]

        next if p1.y == p2.y # Skip horizontal edges

        if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)
          x = p1.x + (y - p1.y) * (p2.x - p1.x) // (p2.y - p1.y)
          intersections << x
        end
      end

      intersections.sort!

      # Fill between pairs
      i = 0
      while i < intersections.size - 1
        x1 = [intersections[i], min_x].max
        x2 = [intersections[i + 1], max_x].min

        (x1..x2).each do |x|
          # Calculate gradient position
          if length_sq > 0
            px = x - gradient.start_point.x
            py = y - gradient.start_point.y
            t = (px * dx + py * dy) / length_sq
            color = gradient.color_at(t)
          else
            color = gradient.stops.first.color
          end
          # Alpha blend with existing pixel
          dst = img.at(x, y)
          blended = blend_colors(color, dst, BlendMode::Normal)
          img.set(x, y, blended)
        end

        i += 2
      end
    end
  end

  # Fills a polygon with a radial gradient.
  def self.fill_polygon_gradient(img : Image, points : Array(Point), gradient : RadialGradient)
    return if points.size < 3

    bounds = img.bounds

    min_x = points.map(&.x).min
    max_x = points.map(&.x).max
    min_y = points.map(&.y).min
    max_y = points.map(&.y).max

    min_x = [min_x, bounds.min.x].max
    max_x = [max_x, bounds.max.x - 1].min
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    radius_f = gradient.radius.to_f64

    (min_y..max_y).each do |y|
      intersections = [] of Int32

      points.size.times do |i|
        p1 = points[i]
        p2 = points[(i + 1) % points.size]

        next if p1.y == p2.y

        if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)
          x = p1.x + (y - p1.y) * (p2.x - p1.x) // (p2.y - p1.y)
          intersections << x
        end
      end

      intersections.sort!

      i = 0
      while i < intersections.size - 1
        x1 = [intersections[i], min_x].max
        x2 = [intersections[i + 1], max_x].min

        (x1..x2).each do |x|
          dx = (x - gradient.center.x).to_f64
          dy = (y - gradient.center.y).to_f64
          distance = ::Math.sqrt(dx * dx + dy * dy)
          t = radius_f > 0 ? distance / radius_f : 0.0
          color = gradient.color_at(t)
          # Alpha blend with existing pixel
          dst = img.at(x, y)
          blended = blend_colors(color, dst, BlendMode::Normal)
          img.set(x, y, blended)
        end

        i += 2
      end
    end
  end

  # Fills a path with a gradient.
  def self.fill_path_gradient(img : Image, path : Path, gradient : LinearGradient | RadialGradient)
    points = path.flatten
    return if points.size < 3
    fill_polygon_gradient(img, points, gradient)
  end

  # Fills a polygon with a color using the specified blend mode.
  #
  # Example:
  # ```
  # # Overlapping semi-transparent shapes with multiply blend
  # CrImage::Draw.fill_polygon_blended(img, points, color, CrImage::Draw::BlendMode::Multiply)
  # ```
  def self.fill_polygon_blended(img : Image, points : Array(Point), color : Color::Color, mode : BlendMode)
    return if points.size < 3

    bounds = img.bounds

    min_x = points.map(&.x).min
    max_x = points.map(&.x).max
    min_y = points.map(&.y).min
    max_y = points.map(&.y).max

    min_x = [min_x, bounds.min.x].max
    max_x = [max_x, bounds.max.x - 1].min
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    (min_y..max_y).each do |y|
      intersections = [] of Int32

      points.size.times do |i|
        p1 = points[i]
        p2 = points[(i + 1) % points.size]

        next if p1.y == p2.y

        if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)
          x = p1.x + (y - p1.y) * (p2.x - p1.x) // (p2.y - p1.y)
          intersections << x
        end
      end

      intersections.sort!

      i = 0
      while i < intersections.size - 1
        x1 = [intersections[i], min_x].max
        x2 = [intersections[i + 1], max_x].min

        (x1..x2).each do |x|
          dst = img.at(x, y)
          blended = blend_colors(color, dst, mode)
          img.set(x, y, blended)
        end

        i += 2
      end
    end
  end

  # Fills a path with a color using the specified blend mode.
  def self.fill_path_blended(img : Image, path : Path, color : Color::Color, mode : BlendMode)
    points = path.flatten
    return if points.size < 3
    fill_polygon_blended(img, points, color, mode)
  end
end
