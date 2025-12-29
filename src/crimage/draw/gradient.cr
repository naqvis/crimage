require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # ColorStop represents a color at a specific position in a gradient.
  #
  # Used to define gradient transitions. Position ranges from 0.0 (start)
  # to 1.0 (end), with colors interpolated between stops.
  #
  # Example:
  # ```
  # stop1 = CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED)
  # stop2 = CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE)
  # ```
  struct ColorStop
    property position : Float64 # 0.0 to 1.0
    property color : Color::Color

    def initialize(@position, @color)
    end
  end

  # LinearGradient represents a linear color gradient between two points.
  #
  # The gradient interpolates colors along a line from start_point to end_point,
  # using the defined color stops. Colors are smoothly blended between stops.
  #
  # Example:
  # ```
  # stops = [
  #   CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  #   CrImage::Draw::ColorStop.new(0.5, CrImage::Color::GREEN),
  #   CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
  # ]
  # gradient = CrImage::Draw::LinearGradient.new(
  #   CrImage.point(0, 0),
  #   CrImage.point(100, 0),
  #   stops
  # )
  # ```
  class LinearGradient
    property start_point : Point
    property end_point : Point
    property stops : Array(ColorStop)

    def initialize(@start_point, @end_point, @stops)
      InputValidation.validate_color_stops(@stops)
    end

    # Gets the interpolated color at a given position along the gradient.
    #
    # Parameters:
    # - `t` : Position along gradient (0.0 = start, 1.0 = end)
    #
    # Returns: Interpolated color at position t
    def color_at(t : Float64) : Color::Color
      return @stops.first.color if @stops.size == 1

      # Clamp t to [0, 1]
      t = [[t, 0.0].max, 1.0].min

      # Find the two stops to interpolate between
      if t <= @stops.first.position
        return @stops.first.color
      end

      if t >= @stops.last.position
        return @stops.last.color
      end

      # Find the surrounding stops
      @stops.each_cons(2) do |pair|
        stop1, stop2 = pair[0], pair[1]

        if t >= stop1.position && t <= stop2.position
          # Interpolate between these two stops
          local_t = (t - stop1.position) / (stop2.position - stop1.position)
          return interpolate_colors(stop1.color, stop2.color, local_t)
        end
      end

      # Fallback (should not reach here)
      @stops.last.color
    end

    # Interpolate between two colors
    private def interpolate_colors(c1 : Color::Color, c2 : Color::Color, t : Float64) : Color::Color
      r1, g1, b1, a1 = c1.rgba
      r2, g2, b2, a2 = c2.rgba

      # Convert to Float64 for safe arithmetic
      r = (r1.to_f64 + (r2.to_f64 - r1.to_f64) * t).to_u16
      g = (g1.to_f64 + (g2.to_f64 - g1.to_f64) * t).to_u16
      b = (b1.to_f64 + (b2.to_f64 - b1.to_f64) * t).to_u16
      a = (a1.to_f64 + (a2.to_f64 - a1.to_f64) * t).to_u16

      Color::RGBA64.new(r, g, b, a)
    end
  end

  # Fills a rectangle with a linear gradient.
  #
  # Creates a smooth color transition between gradient stops along a line
  # from the start point to the end point. Colors are interpolated in RGB space.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `rect` : Rectangle area to fill with gradient
  # - `gradient` : Linear gradient definition with start/end points and color stops
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # gradient = CrImage::Draw::LinearGradient.new(
  #   CrImage.point(0, 0),
  #   CrImage.point(400, 0),
  #   [
  #     {0.0, CrImage::Color.rgb(255, 0, 0)},
  #     {1.0, CrImage::Color.rgb(0, 0, 255)},
  #   ]
  # )
  # CrImage::Draw.fill_linear_gradient(img, img.bounds, gradient)
  # ```
  def self.fill_linear_gradient(img : Image, rect : Rectangle, gradient : LinearGradient)
    bounds = img.bounds

    # Clip rectangle to image bounds
    clipped_rect = BoundsCheck.clip_rect(rect, bounds)
    return if clipped_rect.empty

    # Calculate gradient vector
    dx = (gradient.end_point.x - gradient.start_point.x).to_f64
    dy = (gradient.end_point.y - gradient.start_point.y).to_f64
    length_sq = dx * dx + dy * dy

    # Handle degenerate case (start == end)
    if length_sq == 0.0
      # Fill with first color
      color = gradient.stops.first.color
      (clipped_rect.min.y...clipped_rect.max.y).each do |y|
        (clipped_rect.min.x...clipped_rect.max.x).each do |x|
          img.set(x, y, color)
        end
      end
      return
    end

    # For each pixel in the rectangle
    (clipped_rect.min.y...clipped_rect.max.y).each do |y|
      (clipped_rect.min.x...clipped_rect.max.x).each do |x|
        # Calculate position along gradient line
        # Project point onto gradient vector
        px = x - gradient.start_point.x
        py = y - gradient.start_point.y

        # Dot product with gradient vector, normalized
        t = (px * dx + py * dy) / length_sq

        # Get color at this position
        color = gradient.color_at(t)
        img.set(x, y, color)
      end
    end
  end

  # RadialGradient represents a circular color gradient radiating from a center point.
  #
  # The gradient interpolates colors radially from the center outward to the radius,
  # using the defined color stops. Colors are smoothly blended between stops.
  #
  # Example:
  # ```
  # stops = [
  #   CrImage::Draw::ColorStop.new(0.0, CrImage::Color::WHITE),
  #   CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLACK),
  # ]
  # gradient = CrImage::Draw::RadialGradient.new(
  #   CrImage.point(200, 150),
  #   100,
  #   stops
  # )
  # ```
  class RadialGradient
    property center : Point
    property radius : Int32
    property stops : Array(ColorStop)

    def initialize(@center, @radius, @stops)
      InputValidation.validate_color_stops(@stops)
    end

    # Gets the interpolated color at a given distance from center.
    #
    # Parameters:
    # - `t` : Normalized distance from center (0.0 = center, 1.0 = radius)
    #
    # Returns: Interpolated color at distance t
    def color_at(t : Float64) : Color::Color
      return @stops.first.color if @stops.size == 1

      # Clamp t to [0, 1]
      t = [[t, 0.0].max, 1.0].min

      # Find the two stops to interpolate between
      if t <= @stops.first.position
        return @stops.first.color
      end

      if t >= @stops.last.position
        return @stops.last.color
      end

      # Find the surrounding stops
      @stops.each_cons(2) do |pair|
        stop1, stop2 = pair[0], pair[1]

        if t >= stop1.position && t <= stop2.position
          # Interpolate between these two stops
          local_t = (t - stop1.position) / (stop2.position - stop1.position)
          return interpolate_colors(stop1.color, stop2.color, local_t)
        end
      end

      # Fallback (should not reach here)
      @stops.last.color
    end

    # Interpolate between two colors
    private def interpolate_colors(c1 : Color::Color, c2 : Color::Color, t : Float64) : Color::Color
      r1, g1, b1, a1 = c1.rgba
      r2, g2, b2, a2 = c2.rgba

      # Convert to Float64 for safe arithmetic
      r = (r1.to_f64 + (r2.to_f64 - r1.to_f64) * t).to_u16
      g = (g1.to_f64 + (g2.to_f64 - g1.to_f64) * t).to_u16
      b = (b1.to_f64 + (b2.to_f64 - b1.to_f64) * t).to_u16
      a = (a1.to_f64 + (a2.to_f64 - a1.to_f64) * t).to_u16

      Color::RGBA64.new(r, g, b, a)
    end
  end

  # Fills a rectangle with a radial gradient.
  #
  # Creates a circular color transition radiating from a center point.
  # Colors are interpolated in RGB space based on distance from center.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `rect` : Rectangle area to fill with gradient
  # - `gradient` : Radial gradient definition with center, radius, and color stops
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # gradient = CrImage::Draw::RadialGradient.new(
  #   CrImage.point(200, 150),
  #   150,
  #   [
  #     {0.0, CrImage::Color.rgb(255, 255, 0)},
  #     {1.0, CrImage::Color.rgb(255, 0, 0)},
  #   ]
  # )
  # CrImage::Draw.fill_radial_gradient(img, img.bounds, gradient)
  # ```
  def self.fill_radial_gradient(img : Image, rect : Rectangle, gradient : RadialGradient)
    bounds = img.bounds

    # Clip rectangle to image bounds
    clipped_rect = BoundsCheck.clip_rect(rect, bounds)
    return if clipped_rect.empty

    # Handle degenerate case (radius == 0)
    if gradient.radius == 0
      # Fill with first color at center point only
      if clipped_rect.min.x <= gradient.center.x && gradient.center.x < clipped_rect.max.x &&
         clipped_rect.min.y <= gradient.center.y && gradient.center.y < clipped_rect.max.y
        img.set(gradient.center.x, gradient.center.y, gradient.stops.first.color)
      end
      return
    end

    radius_f = gradient.radius.to_f64

    # For each pixel in the rectangle
    (clipped_rect.min.y...clipped_rect.max.y).each do |y|
      (clipped_rect.min.x...clipped_rect.max.x).each do |x|
        # Calculate distance from center
        dx = (x - gradient.center.x).to_f64
        dy = (y - gradient.center.y).to_f64
        distance = ::Math.sqrt(dx * dx + dy * dy)

        # Normalize distance by radius
        t = distance / radius_f

        # Get color at this position
        color = gradient.color_at(t)
        img.set(x, y, color)
      end
    end
  end

  # ConicGradient represents an angular/conic color gradient sweeping around a center point.
  #
  # The gradient interpolates colors based on angle from the center, creating a
  # "pie chart" or "gauge" style effect. Useful for gauge charts, color wheels,
  # and angular progress indicators.
  #
  # Example:
  # ```
  # stops = [
  #   CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
  #   CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
  #   CrImage::Draw::ColorStop.new(1.0, CrImage::Color::GREEN),
  # ]
  # gradient = CrImage::Draw::ConicGradient.new(
  #   CrImage.point(200, 150),
  #   stops,
  #   start_angle: -Math::PI / 2 # Start from top
  # )
  # ```
  class ConicGradient
    property center : Point
    property stops : Array(ColorStop)
    property start_angle : Float64 # Starting angle in radians (0 = right, -PI/2 = top)

    def initialize(@center, @stops, @start_angle = 0.0)
      InputValidation.validate_color_stops(@stops)
    end

    # Gets the interpolated color at a given angle.
    #
    # Parameters:
    # - `t` : Normalized angle position (0.0 = start_angle, 1.0 = start_angle + 2π)
    #
    # Returns: Interpolated color at angle t
    def color_at(t : Float64) : Color::Color
      return @stops.first.color if @stops.size == 1

      # Clamp t to [0, 1]
      t = [[t, 0.0].max, 1.0].min

      # Find the two stops to interpolate between
      if t <= @stops.first.position
        return @stops.first.color
      end

      if t >= @stops.last.position
        return @stops.last.color
      end

      # Find the surrounding stops
      @stops.each_cons(2) do |pair|
        stop1, stop2 = pair[0], pair[1]

        if t >= stop1.position && t <= stop2.position
          # Interpolate between these two stops
          local_t = (t - stop1.position) / (stop2.position - stop1.position)
          return interpolate_colors(stop1.color, stop2.color, local_t)
        end
      end

      # Fallback (should not reach here)
      @stops.last.color
    end

    # Interpolate between two colors
    private def interpolate_colors(c1 : Color::Color, c2 : Color::Color, t : Float64) : Color::Color
      r1, g1, b1, a1 = c1.rgba
      r2, g2, b2, a2 = c2.rgba

      r = (r1.to_f64 + (r2.to_f64 - r1.to_f64) * t).to_u16
      g = (g1.to_f64 + (g2.to_f64 - g1.to_f64) * t).to_u16
      b = (b1.to_f64 + (b2.to_f64 - b1.to_f64) * t).to_u16
      a = (a1.to_f64 + (a2.to_f64 - a1.to_f64) * t).to_u16

      Color::RGBA64.new(r, g, b, a)
    end
  end

  # Fills a rectangle with a conic/angular gradient.
  #
  # Creates a color transition that sweeps around a center point based on angle.
  # Useful for gauge charts, color wheels, and progress indicators.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `rect` : Rectangle area to fill with gradient
  # - `gradient` : Conic gradient definition with center, color stops, and start angle
  #
  # Example:
  # ```
  # # Gauge-style gradient (green to yellow to red)
  # img = CrImage.rgba(400, 400)
  # gradient = CrImage::Draw::ConicGradient.new(
  #   CrImage.point(200, 200),
  #   [
  #     CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(0, 255, 0)),   # Green
  #     CrImage::Draw::ColorStop.new(0.5, CrImage::Color.rgb(255, 255, 0)), # Yellow
  #     CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(255, 0, 0)),   # Red
  #   ],
  #   start_angle: -Math::PI # Start from left
  # )
  # CrImage::Draw.fill_conic_gradient(img, img.bounds, gradient)
  # ```
  def self.fill_conic_gradient(img : Image, rect : Rectangle, gradient : ConicGradient)
    bounds = img.bounds

    # Clip rectangle to image bounds
    clipped_rect = BoundsCheck.clip_rect(rect, bounds)
    return if clipped_rect.empty

    two_pi = 2.0 * ::Math::PI

    # For each pixel in the rectangle
    (clipped_rect.min.y...clipped_rect.max.y).each do |y|
      (clipped_rect.min.x...clipped_rect.max.x).each do |x|
        # Calculate angle from center
        dx = (x - gradient.center.x).to_f64
        dy = (y - gradient.center.y).to_f64

        # atan2 returns angle in [-π, π], adjust to start from start_angle
        angle = ::Math.atan2(dy, dx) - gradient.start_angle

        # Normalize angle to [0, 2π)
        while angle < 0
          angle += two_pi
        end
        while angle >= two_pi
          angle -= two_pi
        end

        # Convert to [0, 1] range
        t = angle / two_pi

        # Get color at this angle
        color = gradient.color_at(t)
        img.set(x, y, color)
      end
    end
  end

  # Fills a ring (donut shape) with a conic gradient.
  #
  # Combines angular gradient with ring shape - perfect for gauge charts.
  # Only fills pixels between inner_radius and outer_radius.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the ring
  # - `inner_radius` : Inner radius (hole size)
  # - `outer_radius` : Outer radius
  # - `gradient` : Conic gradient for coloring
  # - `start_angle` : Starting angle in radians (default: 0)
  # - `end_angle` : Ending angle in radians (default: 2π for full circle)
  #
  # Example:
  # ```
  # # Gauge chart with gradient fill
  # gradient = CrImage::Draw::ConicGradient.new(
  #   CrImage.point(200, 200),
  #   [
  #     CrImage::Draw::ColorStop.new(0.0, CrImage::Color.rgb(0, 255, 0)),
  #     CrImage::Draw::ColorStop.new(1.0, CrImage::Color.rgb(255, 0, 0)),
  #   ],
  #   start_angle: -Math::PI * 0.75
  # )
  # CrImage::Draw.fill_conic_ring(img, CrImage.point(200, 200), 60, 100, gradient,
  #   start_angle: -Math::PI * 0.75, end_angle: Math::PI * 0.75)
  # ```
  def self.fill_conic_ring(img : Image, center : Point, inner_radius : Int32, outer_radius : Int32,
                           gradient : ConicGradient,
                           start_angle : Float64 = 0.0, end_angle : Float64 = 2.0 * ::Math::PI)
    return if outer_radius <= 0
    return if inner_radius >= outer_radius
    inner_radius = [inner_radius, 0].max

    bounds = img.bounds
    inner_r_sq = inner_radius * inner_radius
    outer_r_sq = outer_radius * outer_radius

    two_pi = 2.0 * ::Math::PI

    # Normalize angles
    while end_angle < start_angle
      end_angle += two_pi
    end

    (-outer_radius..outer_radius).each do |dy|
      y = center.y + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-outer_radius..outer_radius).each do |dx|
        x = center.x + dx
        next if x < bounds.min.x || x >= bounds.max.x

        # Check if point is within ring
        dist_sq = dx * dx + dy * dy
        next if dist_sq > outer_r_sq
        next if dist_sq < inner_r_sq

        # Calculate angle
        angle = ::Math.atan2(dy.to_f64, dx.to_f64)

        # Normalize angle relative to start_angle
        normalized_angle = angle
        while normalized_angle < start_angle
          normalized_angle += two_pi
        end

        # Check if within angle range
        next if normalized_angle > end_angle

        # Calculate t for gradient (0 at start_angle, 1 at end_angle)
        angle_range = end_angle - start_angle
        t = (normalized_angle - start_angle) / angle_range

        color = gradient.color_at(t)
        img.set(x, y, color)
      end
    end
  end
end

# InvalidGradientError is defined in errors.cr
