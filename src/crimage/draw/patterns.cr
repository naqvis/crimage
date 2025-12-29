require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # PatternStyle defines a fill pattern for shapes.
  #
  # Patterns are essential for accessibility - they allow distinguishing
  # chart elements without relying on color alone, and work well in grayscale print.
  enum PatternType
    Solid           # Solid fill (default)
    HorizontalLines # Horizontal stripes
    VerticalLines   # Vertical stripes
    DiagonalUp      # Diagonal lines (bottom-left to top-right)
    DiagonalDown    # Diagonal lines (top-left to bottom-right)
    Crosshatch      # Grid pattern
    DiagonalCross   # X pattern
    Dots            # Dot pattern
  end

  class Pattern
    property type : PatternType
    property color : Color::Color
    property background : Color::Color?
    property spacing : Int32   # Distance between pattern elements
    property thickness : Int32 # Line thickness or dot size

    def initialize(@type = PatternType::Solid, @color = Color::BLACK,
                   @background = nil, @spacing = 8, @thickness = 1)
    end

    # Check if a pixel should be filled based on pattern
    def fill_at?(x : Int32, y : Int32) : Bool
      case @type
      when .solid?
        true
      when .horizontal_lines?
        y % @spacing < @thickness
      when .vertical_lines?
        x % @spacing < @thickness
      when .diagonal_up?
        (x + y) % @spacing < @thickness
      when .diagonal_down?
        (x - y).abs % @spacing < @thickness
      when .crosshatch?
        (x % @spacing < @thickness) || (y % @spacing < @thickness)
      when .diagonal_cross?
        ((x + y) % @spacing < @thickness) || ((x - y).abs % @spacing < @thickness)
      when .dots?
        dx = x % @spacing
        dy = y % @spacing
        # Center the dot in the cell
        cx = @spacing // 2
        cy = @spacing // 2
        dist_sq = (dx - cx) ** 2 + (dy - cy) ** 2
        radius = @thickness
        dist_sq <= radius * radius
      else
        true
      end
    end

    # Preset patterns for common use cases
    def self.horizontal(color : Color::Color, spacing : Int32 = 6, thickness : Int32 = 2) : Pattern
      new(PatternType::HorizontalLines, color, spacing: spacing, thickness: thickness)
    end

    def self.vertical(color : Color::Color, spacing : Int32 = 6, thickness : Int32 = 2) : Pattern
      new(PatternType::VerticalLines, color, spacing: spacing, thickness: thickness)
    end

    def self.diagonal(color : Color::Color, spacing : Int32 = 8, thickness : Int32 = 2) : Pattern
      new(PatternType::DiagonalUp, color, spacing: spacing, thickness: thickness)
    end

    def self.crosshatch(color : Color::Color, spacing : Int32 = 8, thickness : Int32 = 1) : Pattern
      new(PatternType::Crosshatch, color, spacing: spacing, thickness: thickness)
    end

    def self.dots(color : Color::Color, spacing : Int32 = 8, size : Int32 = 2) : Pattern
      new(PatternType::Dots, color, spacing: spacing, thickness: size)
    end
  end

  # Fills a polygon with a pattern.
  #
  # Example:
  # ```
  # pattern = CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6)
  # CrImage::Draw.fill_polygon_pattern(img, points, pattern)
  # ```
  def self.fill_polygon_pattern(img : Image, points : Array(Point), pattern : Pattern)
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
          if bg = pattern.background
            img.set(x, y, bg)
          end
          if pattern.fill_at?(x, y)
            img.set(x, y, pattern.color)
          end
        end

        i += 2
      end
    end
  end

  # Fills a rectangle with a pattern.
  def self.fill_rect_pattern(img : Image, rect : Rectangle, pattern : Pattern)
    bounds = img.bounds
    clipped = rect.intersect(bounds)
    return if clipped.empty

    (clipped.min.y...clipped.max.y).each do |y|
      (clipped.min.x...clipped.max.x).each do |x|
        if bg = pattern.background
          img.set(x, y, bg)
        end
        if pattern.fill_at?(x, y)
          img.set(x, y, pattern.color)
        end
      end
    end
  end

  # Fills a path with a pattern.
  def self.fill_path_pattern(img : Image, path : Path, pattern : Pattern)
    points = path.flatten
    return if points.size < 3
    fill_polygon_pattern(img, points, pattern)
  end

  # Fills a pie slice (filled arc) with a pattern.
  #
  # Useful for accessible pie charts where color alone shouldn't distinguish slices.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the pie
  # - `radius` : Radius in pixels
  # - `start_angle` : Starting angle in radians (0 = right, PI/2 = down)
  # - `end_angle` : Ending angle in radians
  # - `pattern` : Fill pattern
  #
  # Example:
  # ```
  # pattern = CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6)
  # CrImage::Draw.fill_pie_pattern(img, center, 100, 0.0, Math::PI/2, pattern)
  # ```
  def self.fill_pie_pattern(img : Image, center : Point, radius : Int32,
                            start_angle : Float64, end_angle : Float64, pattern : Pattern)
    return if radius <= 0

    bounds = img.bounds

    # Normalize angles
    while end_angle < start_angle
      end_angle += 2 * ::Math::PI
    end

    radius_sq = radius * radius

    (-radius..radius).each do |dy|
      y = center.y + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-radius..radius).each do |dx|
        x = center.x + dx
        next if x < bounds.min.x || x >= bounds.max.x

        # Check if point is within radius
        dist_sq = dx * dx + dy * dy
        next if dist_sq > radius_sq

        # Check if point is within angle range
        angle = ::Math.atan2(dy.to_f64, dx.to_f64)
        while angle < start_angle
          angle += 2 * ::Math::PI
        end

        if angle <= end_angle
          if bg = pattern.background
            img.set(x, y, bg)
          end
          if pattern.fill_at?(x, y)
            img.set(x, y, pattern.color)
          end
        end
      end
    end
  end

  # Fills a ring slice (donut segment) with a pattern.
  #
  # Useful for accessible donut charts where color alone shouldn't distinguish slices.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the ring
  # - `inner_radius` : Inner radius in pixels (hole size)
  # - `outer_radius` : Outer radius in pixels
  # - `start_angle` : Starting angle in radians
  # - `end_angle` : Ending angle in radians
  # - `pattern` : Fill pattern
  #
  # Example:
  # ```
  # pattern = CrImage::Draw::Pattern.crosshatch(CrImage::Color::RED, spacing: 8)
  # CrImage::Draw.fill_ring_pattern(img, center, 50, 100, 0.0, Math::PI/2, pattern)
  # ```
  def self.fill_ring_pattern(img : Image, center : Point, inner_radius : Int32, outer_radius : Int32,
                             start_angle : Float64, end_angle : Float64, pattern : Pattern)
    return if outer_radius <= 0
    return if inner_radius >= outer_radius
    inner_radius = [inner_radius, 0].max

    bounds = img.bounds

    # Normalize angles
    while end_angle < start_angle
      end_angle += 2 * ::Math::PI
    end

    inner_r_sq = inner_radius * inner_radius
    outer_r_sq = outer_radius * outer_radius

    (-outer_radius..outer_radius).each do |dy|
      y = center.y + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-outer_radius..outer_radius).each do |dx|
        x = center.x + dx
        next if x < bounds.min.x || x >= bounds.max.x

        # Check if point is within ring (between inner and outer radius)
        dist_sq = dx * dx + dy * dy
        next if dist_sq > outer_r_sq
        next if dist_sq < inner_r_sq

        # Check if point is within angle range
        angle = ::Math.atan2(dy.to_f64, dx.to_f64)
        while angle < start_angle
          angle += 2 * ::Math::PI
        end

        if angle <= end_angle
          if bg = pattern.background
            img.set(x, y, bg)
          end
          if pattern.fill_at?(x, y)
            img.set(x, y, pattern.color)
          end
        end
      end
    end
  end
end
