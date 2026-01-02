require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # BlendMode defines how colors are combined when drawing.
  enum BlendMode
    Normal    # Standard alpha compositing
    Multiply  # Darkens: result = src * dst
    Screen    # Lightens: result = 1 - (1-src) * (1-dst)
    Overlay   # Combines multiply and screen
    SoftLight # Gentle lighting effect
  end

  # Blends two colors using the specified blend mode.
  def self.blend_colors(src : Color::Color, dst : Color::Color, mode : BlendMode) : Color::Color
    sr, sg, sb, sa = src.rgba
    dr, dg, db, da = dst.rgba

    # Normalize to 0-1 range
    sr_f = sr.to_f64 / Color::MAX_32BIT
    sg_f = sg.to_f64 / Color::MAX_32BIT
    sb_f = sb.to_f64 / Color::MAX_32BIT
    sa_f = sa.to_f64 / Color::MAX_32BIT

    dr_f = dr.to_f64 / Color::MAX_32BIT
    dg_f = dg.to_f64 / Color::MAX_32BIT
    db_f = db.to_f64 / Color::MAX_32BIT
    da_f = da.to_f64 / Color::MAX_32BIT

    rr, rg, rb = case mode
                 when .normal?
                   {sr_f, sg_f, sb_f}
                 when .multiply?
                   {sr_f * dr_f, sg_f * dg_f, sb_f * db_f}
                 when .screen?
                   {1.0 - (1.0 - sr_f) * (1.0 - dr_f),
                    1.0 - (1.0 - sg_f) * (1.0 - dg_f),
                    1.0 - (1.0 - sb_f) * (1.0 - db_f)}
                 when .overlay?
                   {overlay_channel(sr_f, dr_f),
                    overlay_channel(sg_f, dg_f),
                    overlay_channel(sb_f, db_f)}
                 when .soft_light?
                   {soft_light_channel(sr_f, dr_f),
                    soft_light_channel(sg_f, dg_f),
                    soft_light_channel(sb_f, db_f)}
                 else
                   {sr_f, sg_f, sb_f}
                 end

    # Apply source alpha for compositing
    out_r = (rr * sa_f + dr_f * (1.0 - sa_f)).clamp(0.0, 1.0)
    out_g = (rg * sa_f + dg_f * (1.0 - sa_f)).clamp(0.0, 1.0)
    out_b = (rb * sa_f + db_f * (1.0 - sa_f)).clamp(0.0, 1.0)
    out_a = (sa_f + da_f * (1.0 - sa_f)).clamp(0.0, 1.0)

    Color::RGBA64.new(
      (out_r * Color::MAX_16BIT).to_u16,
      (out_g * Color::MAX_16BIT).to_u16,
      (out_b * Color::MAX_16BIT).to_u16,
      (out_a * Color::MAX_16BIT).to_u16
    )
  end

  private def self.overlay_channel(src : Float64, dst : Float64) : Float64
    if dst < 0.5
      2.0 * src * dst
    else
      1.0 - 2.0 * (1.0 - src) * (1.0 - dst)
    end
  end

  private def self.soft_light_channel(src : Float64, dst : Float64) : Float64
    if src < 0.5
      dst - (1.0 - 2.0 * src) * dst * (1.0 - dst)
    else
      d = dst < 0.25 ? ((16.0 * dst - 12.0) * dst + 4.0) * dst : ::Math.sqrt(dst)
      dst + (2.0 * src - 1.0) * (d - dst)
    end
  end

  # LineStyle defines the visual appearance of a line.
  #
  # Properties:
  # - `color` : Line color
  # - `thickness` : Line width in pixels
  # - `anti_alias` : Enable smooth edges
  #
  # Example:
  # ```
  # style = CrImage::Draw::LineStyle.new(
  #   CrImage::Color::RED,
  #   thickness: 2,
  #   anti_alias: true
  # )
  # ```
  class LineStyle
    property color : Color::Color
    property thickness : Int32
    property anti_alias : Bool

    def initialize(@color, @thickness = 1, @anti_alias = false)
    end

    # Builder pattern methods for fluent API
    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end

    def with_anti_alias(enabled : Bool = true) : self
      @anti_alias = enabled
      self
    end

    def with_color(color : Color::Color) : self
      @color = color
      self
    end

    # DSL-style builder
    def self.build(&block : LineStyle ->) : LineStyle
      style = new(Color::BLACK)
      yield style
      style
    end
  end

  # Draws a line from one point to another.
  #
  # Supports multiple rendering modes based on style settings:
  # - Thin lines (thickness=1, no anti-aliasing): Uses fast Bresenham algorithm
  # - Thick lines: Draws parallel lines with perpendicular offset
  # - Anti-aliased lines: Uses Wu's algorithm for smooth edges
  # - Thick anti-aliased lines: Uses polygon-based stroke with AA edges
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `p1` : Starting point
  # - `p2` : Ending point
  # - `style` : Line appearance settings (color, thickness, anti-aliasing)
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # style = CrImage::Draw::LineStyle.new(CrImage::Color.rgb(255, 0, 0), thickness: 2)
  # CrImage::Draw.line(img, CrImage.point(10, 10), CrImage.point(100, 100), style)
  # ```
  def self.line(img : Image, p1 : Point, p2 : Point, style : LineStyle)
    if style.thickness == 1 && !style.anti_alias
      bresenham_line(img, p1, p2, style.color)
    elsif style.thickness > 1 && style.anti_alias
      thick_aa_line(img, p1, p2, style.color, style.thickness)
    elsif style.thickness > 1 && !style.anti_alias
      thick_line(img, p1, p2, style.color, style.thickness)
    elsif style.anti_alias
      wu_line(img, p1, p2, style.color)
    end
  end

  # Bresenham's line algorithm - handles all octants
  private def self.bresenham_line(img : Image, p1 : Point, p2 : Point, color : Color::Color)
    x0, y0 = p1.x, p1.y
    x1, y1 = p2.x, p2.y

    dx = (x1 - x0).abs
    dy = (y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx - dy

    bounds = img.bounds

    loop do
      # Only set pixel if within bounds (clipping)
      if BoundsCheck.in_bounds?(x0, y0, bounds)
        img.set(x0, y0, color)
      end

      break if x0 == x1 && y0 == y1

      e2 = 2 * err
      if e2 > -dy
        err -= dy
        x0 += sx
      end
      if e2 < dx
        err += dx
        y0 += sy
      end
    end
  end

  # Draw a thick line by drawing filled circle at each point along the line
  private def self.thick_line(img : Image, p1 : Point, p2 : Point, color : Color::Color, thickness : Int32)
    return bresenham_line(img, p1, p2, color) if thickness <= 1

    # For thick lines, we draw a filled circle at each point along the line
    # This ensures no gaps regardless of line angle
    radius = thickness // 2

    x0, y0 = p1.x, p1.y
    x1, y1 = p2.x, p2.y

    dx = (x1 - x0).abs
    dy = (y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx - dy

    circle_style = CircleStyle.new(color, fill: true)

    loop do
      # Draw filled circle at current point
      circle(img, Point.new(x0, y0), radius, circle_style)

      break if x0 == x1 && y0 == y1

      e2 = 2 * err
      if e2 > -dy
        err -= dy
        x0 += sx
      end
      if e2 < dx
        err += dx
        y0 += sy
      end
    end
  end

  # Draw a thick anti-aliased line using polygon-based stroke
  # This creates a rectangle along the line with anti-aliased edges
  private def self.thick_aa_line(img : Image, p1 : Point, p2 : Point, color : Color::Color, thickness : Int32)
    return wu_line(img, p1, p2, color) if thickness <= 1

    bounds = img.bounds
    half_thick = thickness.to_f64 / 2.0

    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64
    length = ::Math.sqrt(dx * dx + dy * dy)

    # Handle zero-length line (draw a circle)
    if length < 0.001
      circle(img, p1, (half_thick).round.to_i, CircleStyle.new(color, fill: true, anti_alias: true))
      return
    end

    # Perpendicular unit vector
    px = -dy / length
    py = dx / length

    # Calculate the four corners of the line rectangle
    # Extend slightly at endpoints for round caps effect
    cap_extend = half_thick * 0.5

    # Direction unit vector
    ux = dx / length
    uy = dy / length

    # Extended endpoints
    x1_ext = p1.x.to_f64 - ux * cap_extend
    y1_ext = p1.y.to_f64 - uy * cap_extend
    x2_ext = p2.x.to_f64 + ux * cap_extend
    y2_ext = p2.y.to_f64 + uy * cap_extend

    # Four corners
    c1x = x1_ext + px * half_thick
    c1y = y1_ext + py * half_thick
    c2x = x1_ext - px * half_thick
    c2y = y1_ext - py * half_thick
    c3x = x2_ext - px * half_thick
    c3y = y2_ext - py * half_thick
    c4x = x2_ext + px * half_thick
    c4y = y2_ext + py * half_thick

    # Bounding box
    min_x = [c1x, c2x, c3x, c4x].min.floor.to_i
    max_x = [c1x, c2x, c3x, c4x].max.ceil.to_i
    min_y = [c1y, c2y, c3y, c4y].min.floor.to_i
    max_y = [c1y, c2y, c3y, c4y].max.ceil.to_i

    # Clip to image bounds
    min_x = [min_x, bounds.min.x].max
    max_x = [max_x, bounds.max.x - 1].min
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    # For each pixel in bounding box, calculate distance to line segment
    (min_y..max_y).each do |y|
      (min_x..max_x).each do |x|
        # Calculate signed distance to the line segment
        dist = point_to_line_segment_distance(x.to_f64, y.to_f64, p1.x.to_f64, p1.y.to_f64, p2.x.to_f64, p2.y.to_f64)

        if dist <= half_thick
          # Inside the line
          if dist >= half_thick - 1.0
            # Anti-alias the edge
            alpha = half_thick - dist
            alpha = [[alpha, 0.0].max, 1.0].min
            plot_aa(img, x, y, color, alpha)
          else
            img.set(x, y, color)
          end
        end
      end
    end

    # Draw round caps at endpoints
    draw_aa_filled_circle(img, p1.x, p1.y, half_thick, color, bounds)
    draw_aa_filled_circle(img, p2.x, p2.y, half_thick, color, bounds)
  end

  # Calculate distance from point to line segment
  private def self.point_to_line_segment_distance(px : Float64, py : Float64,
                                                  x1 : Float64, y1 : Float64,
                                                  x2 : Float64, y2 : Float64) : Float64
    dx = x2 - x1
    dy = y2 - y1
    length_sq = dx * dx + dy * dy

    if length_sq < 0.0001
      # Line segment is essentially a point
      return ::Math.sqrt((px - x1) ** 2 + (py - y1) ** 2)
    end

    # Parameter t for closest point on line
    t = ((px - x1) * dx + (py - y1) * dy) / length_sq
    t = [[t, 0.0].max, 1.0].min

    # Closest point on segment
    closest_x = x1 + t * dx
    closest_y = y1 + t * dy

    ::Math.sqrt((px - closest_x) ** 2 + (py - closest_y) ** 2)
  end

  # Draw anti-aliased filled circle for line caps
  private def self.draw_aa_filled_circle(img : Image, cx : Int32, cy : Int32, radius : Float64, color : Color::Color, bounds : Rectangle)
    r_int = radius.ceil.to_i

    (-r_int..r_int).each do |dy|
      y = cy + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-r_int..r_int).each do |dx|
        x = cx + dx
        next if x < bounds.min.x || x >= bounds.max.x

        dist = ::Math.sqrt((dx * dx + dy * dy).to_f64)
        if dist <= radius
          if dist >= radius - 1.0
            alpha = radius - dist
            alpha = [[alpha, 0.0].max, 1.0].min
            plot_aa(img, x, y, color, alpha)
          else
            img.set(x, y, color)
          end
        end
      end
    end
  end

  # Xiaolin Wu's anti-aliased line algorithm
  private def self.wu_line(img : Image, p1 : Point, p2 : Point, color : Color::Color)
    x0, y0 = p1.x.to_f64, p1.y.to_f64
    x1, y1 = p2.x.to_f64, p2.y.to_f64

    steep = (y1 - y0).abs > (x1 - x0).abs

    if steep
      x0, y0 = y0, x0
      x1, y1 = y1, x1
    end

    if x0 > x1
      x0, x1 = x1, x0
      y0, y1 = y1, y0
    end

    dx = x1 - x0
    dy = y1 - y0
    gradient = dy / dx

    gradient = 1.0 if dx == 0.0

    # Handle first endpoint
    xend = x0.round
    yend = y0 + gradient * (xend - x0)
    xgap = 1.0 - fpart(x0 + 0.5)
    xpxl1 = xend.to_i
    ypxl1 = yend.floor.to_i

    if steep
      plot_aa(img, ypxl1, xpxl1, color, (1.0 - fpart(yend)) * xgap)
      plot_aa(img, ypxl1 + 1, xpxl1, color, fpart(yend) * xgap)
    else
      plot_aa(img, xpxl1, ypxl1, color, (1.0 - fpart(yend)) * xgap)
      plot_aa(img, xpxl1, ypxl1 + 1, color, fpart(yend) * xgap)
    end

    intery = yend + gradient

    # Handle second endpoint
    xend = x1.round
    yend = y1 + gradient * (xend - x1)
    xgap = fpart(x1 + 0.5)
    xpxl2 = xend.to_i
    ypxl2 = yend.floor.to_i

    if steep
      plot_aa(img, ypxl2, xpxl2, color, (1.0 - fpart(yend)) * xgap)
      plot_aa(img, ypxl2 + 1, xpxl2, color, fpart(yend) * xgap)
    else
      plot_aa(img, xpxl2, ypxl2, color, (1.0 - fpart(yend)) * xgap)
      plot_aa(img, xpxl2, ypxl2 + 1, color, fpart(yend) * xgap)
    end

    # Main loop
    (xpxl1 + 1).upto(xpxl2 - 1) do |x|
      if steep
        plot_aa(img, intery.floor.to_i, x, color, 1.0 - fpart(intery))
        plot_aa(img, intery.floor.to_i + 1, x, color, fpart(intery))
      else
        plot_aa(img, x, intery.floor.to_i, color, 1.0 - fpart(intery))
        plot_aa(img, x, intery.floor.to_i + 1, color, fpart(intery))
      end
      intery += gradient
    end
  end

  # Get fractional part of a number
  private def self.fpart(x : Float64) : Float64
    x - x.floor
  end

  # Plot a pixel with alpha blending for anti-aliasing
  private def self.plot_aa(img : Image, x : Int32, y : Int32, color : Color::Color, alpha : Float64)
    bounds = img.bounds
    return unless BoundsCheck.in_bounds?(x, y, bounds)

    # Get the color components
    r, g, b, a = color.rgba

    # Apply alpha blending
    alpha_u16 = (alpha * Color::MAX_16BIT).to_u16
    blended_a = (a.to_u32 * alpha_u16.to_u32 / Color::MAX_32BIT).to_u16

    # Get existing pixel
    existing = img.at(x, y)
    er, eg, eb, ea = existing.rgba

    # Blend colors (simple over operation)
    inv_alpha = Color::MAX_16BIT - blended_a
    final_r = ((r.to_u32 * blended_a + er * inv_alpha) / Color::MAX_32BIT).to_u16
    final_g = ((g.to_u32 * blended_a + eg * inv_alpha) / Color::MAX_32BIT).to_u16
    final_b = ((b.to_u32 * blended_a + eb * inv_alpha) / Color::MAX_32BIT).to_u16
    final_a = ((blended_a.to_u32 + ea * inv_alpha / Color::MAX_32BIT)).to_u16

    img.set(x, y, Color::RGBA64.new(final_r, final_g, final_b, final_a))
  end

  # CircleStyle defines the appearance of a circle or ellipse
  class CircleStyle
    property color : Color::Color
    property fill : Bool
    property anti_alias : Bool
    property thickness : Int32
    property blend_mode : BlendMode?

    def initialize(@color, @fill = false, @anti_alias = false, @thickness = 1, @blend_mode = nil)
    end

    # Builder pattern methods for fluent API
    def with_fill(enabled : Bool = true) : self
      @fill = enabled
      self
    end

    def with_anti_alias(enabled : Bool = true) : self
      @anti_alias = enabled
      self
    end

    def with_color(color : Color::Color) : self
      @color = color
      self
    end

    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end

    def with_blend_mode(mode : BlendMode) : self
      @blend_mode = mode
      self
    end

    # DSL-style builder
    def self.build(&block : CircleStyle ->) : CircleStyle
      style = new(Color::BLACK)
      yield style
      style
    end
  end

  # Draws a circle using the midpoint circle algorithm.
  #
  # Supports both outlined and filled circles with optional anti-aliasing.
  # The algorithm is efficient and produces symmetric circles.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the circle
  # - `radius` : Circle radius in pixels (must be non-negative)
  # - `style` : Circle appearance settings (color, fill, anti-aliasing)
  #
  # Raises: `ArgumentError` if radius is negative
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # style = CrImage::Draw::CircleStyle.new(CrImage::Color.rgb(0, 255, 0), filled: true)
  # CrImage::Draw.circle(img, CrImage.point(200, 150), 50, style)
  # ```
  def self.circle(img : Image, center : Point, radius : Int32, style : CircleStyle)
    InputValidation.validate_radius(radius)
    return if radius == 0

    if style.fill
      if blend_mode = style.blend_mode
        filled_circle_blended(img, center, radius, style.color, blend_mode)
      else
        filled_circle(img, center, radius, style.color, style.anti_alias)
      end
    elsif style.thickness > 1
      thick_circle_outline(img, center, radius, style.color, style.thickness)
    else
      circle_outline(img, center, radius, style.color, style.anti_alias)
    end
  end

  # Draw thick circle outline by drawing filled ring
  private def self.thick_circle_outline(img : Image, center : Point, radius : Int32, color : Color::Color, thickness : Int32)
    bounds = img.bounds
    cx, cy = center.x, center.y
    half_thick = thickness // 2
    outer_r = radius + half_thick
    inner_r = [radius - half_thick, 0].max

    outer_r_sq = outer_r * outer_r
    inner_r_sq = inner_r * inner_r

    (-outer_r..outer_r).each do |dy|
      y = cy + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-outer_r..outer_r).each do |dx|
        x = cx + dx
        next if x < bounds.min.x || x >= bounds.max.x

        dist_sq = dx * dx + dy * dy
        if dist_sq <= outer_r_sq && dist_sq >= inner_r_sq
          img.set(x, y, color)
        end
      end
    end
  end

  # Draw circle outline using midpoint circle algorithm
  private def self.circle_outline(img : Image, center : Point, radius : Int32, color : Color::Color, anti_alias : Bool)
    return if radius == 0

    bounds = img.bounds
    cx, cy = center.x, center.y

    if anti_alias
      # Anti-aliased circle using Wu's algorithm
      draw_aa_circle(img, cx, cy, radius, color)
    else
      # Standard midpoint circle algorithm
      x = 0
      y = radius
      d = 1 - radius

      # Plot initial points in all octants
      plot_circle_points(img, cx, cy, x, y, color, bounds)

      while x < y
        x += 1
        if d < 0
          d += 2 * x + 1
        else
          y -= 1
          d += 2 * (x - y) + 1
        end
        plot_circle_points(img, cx, cy, x, y, color, bounds)
      end
    end
  end

  # Draw filled circle using scanline fill
  private def self.filled_circle(img : Image, center : Point, radius : Int32, color : Color::Color, anti_alias : Bool)
    return if radius == 0

    bounds = img.bounds
    cx, cy = center.x, center.y

    if anti_alias
      # For filled anti-aliased circles, draw filled interior then anti-aliased edge
      # First fill the interior
      (-radius..radius).each do |dy|
        y = cy + dy
        next if y < bounds.min.y || y >= bounds.max.y

        # Calculate x extent for this y
        dx = ::Math.sqrt((radius * radius - dy * dy).to_f64).to_i
        x_start = [cx - dx, bounds.min.x].max
        x_end = [cx + dx, bounds.max.x - 1].min

        (x_start..x_end).each do |x|
          img.set(x, y, color)
        end
      end

      # Draw anti-aliased edge
      draw_aa_circle(img, cx, cy, radius, color)
    else
      # Use midpoint algorithm to determine scanlines
      x = 0
      y = radius
      d = 1 - radius

      # Fill horizontal lines for each y value
      fill_circle_scanline(img, cx, cy, x, y, color, bounds)

      while x < y
        x += 1
        if d < 0
          d += 2 * x + 1
        else
          y -= 1
          d += 2 * (x - y) + 1
        end
        fill_circle_scanline(img, cx, cy, x, y, color, bounds)
      end
    end
  end

  # Draw filled circle with blend mode
  private def self.filled_circle_blended(img : Image, center : Point, radius : Int32, color : Color::Color, mode : BlendMode)
    return if radius == 0

    bounds = img.bounds
    cx, cy = center.x, center.y

    # Use simple scanline approach for blended circles
    (-radius..radius).each do |dy|
      y = cy + dy
      next if y < bounds.min.y || y >= bounds.max.y

      # Calculate x extent for this y
      dx = ::Math.sqrt((radius * radius - dy * dy).to_f64).to_i
      x_start = [cx - dx, bounds.min.x].max
      x_end = [cx + dx, bounds.max.x - 1].min

      (x_start..x_end).each do |x|
        dst = img.at(x, y)
        blended = blend_colors(color, dst, mode)
        img.set(x, y, blended)
      end
    end
  end

  # Plot circle points in all 8 octants
  private def self.plot_circle_points(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    # Plot 8 symmetric points
    plot_if_in_bounds(img, cx + x, cy + y, color, bounds)
    plot_if_in_bounds(img, cx - x, cy + y, color, bounds)
    plot_if_in_bounds(img, cx + x, cy - y, color, bounds)
    plot_if_in_bounds(img, cx - x, cy - y, color, bounds)
    plot_if_in_bounds(img, cx + y, cy + x, color, bounds)
    plot_if_in_bounds(img, cx - y, cy + x, color, bounds)
    plot_if_in_bounds(img, cx + y, cy - x, color, bounds)
    plot_if_in_bounds(img, cx - y, cy - x, color, bounds)
  end

  # Fill horizontal scanlines for filled circle
  private def self.fill_circle_scanline(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    # Fill horizontal lines at y offsets
    fill_horizontal_line(img, cx - x, cx + x, cy + y, color, bounds)
    fill_horizontal_line(img, cx - x, cx + x, cy - y, color, bounds)
    fill_horizontal_line(img, cx - y, cx + y, cy + x, color, bounds)
    fill_horizontal_line(img, cx - y, cx + y, cy - x, color, bounds)
  end

  # Fill a horizontal line segment
  private def self.fill_horizontal_line(img : Image, x1 : Int32, x2 : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    return if y < bounds.min.y || y >= bounds.max.y

    x_start = [x1, bounds.min.x].max
    x_end = [x2, bounds.max.x - 1].min

    (x_start..x_end).each do |x|
      img.set(x, y, color)
    end
  end

  # Plot pixel if within bounds
  private def self.plot_if_in_bounds(img : Image, x : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    return unless BoundsCheck.in_bounds?(x, y, bounds)
    img.set(x, y, color)
  end

  # Draw anti-aliased circle using Wu's algorithm
  private def self.draw_aa_circle(img : Image, cx : Int32, cy : Int32, radius : Int32, color : Color::Color)
    # Use parametric approach for anti-aliasing
    # We'll sample points around the circle and use distance for alpha
    x = radius
    y = 0

    while x >= y
      # For each octant point, calculate the fractional coverage
      draw_aa_circle_octants(img, cx, cy, x, y, radius, color)
      y += 1
      x = ::Math.sqrt((radius * radius - y * y).to_f64).round.to_i
    end
  end

  # Draw anti-aliased points in all octants
  private def self.draw_aa_circle_octants(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, radius : Int32, color : Color::Color)
    # Calculate distance from ideal circle for anti-aliasing
    dist = ::Math.sqrt((x * x + y * y).to_f64)
    alpha = 1.0 - (dist - radius).abs
    alpha = [[alpha, 0.0].max, 1.0].min

    # Plot in all 8 octants with anti-aliasing
    plot_aa(img, cx + x, cy + y, color, alpha)
    plot_aa(img, cx - x, cy + y, color, alpha)
    plot_aa(img, cx + x, cy - y, color, alpha)
    plot_aa(img, cx - x, cy - y, color, alpha)
    plot_aa(img, cx + y, cy + x, color, alpha)
    plot_aa(img, cx - y, cy + x, color, alpha)
    plot_aa(img, cx + y, cy - x, color, alpha)
    plot_aa(img, cx - y, cy - x, color, alpha)
  end

  # Draws an ellipse using the midpoint ellipse algorithm.
  #
  # Supports both outlined and filled ellipses with optional anti-aliasing.
  # The algorithm efficiently handles ellipses of any aspect ratio.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the ellipse
  # - `rx` : Horizontal radius in pixels (must be non-negative)
  # - `ry` : Vertical radius in pixels (must be non-negative)
  # - `style` : Ellipse appearance settings (color, fill, anti-aliasing)
  #
  # Raises: `ArgumentError` if either radius is negative
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # style = CrImage::Draw::CircleStyle.new(CrImage::Color.rgb(0, 0, 255), filled: false)
  # CrImage::Draw.ellipse(img, CrImage.point(200, 150), 80, 50, style)
  # ```
  def self.ellipse(img : Image, center : Point, rx : Int32, ry : Int32, style : CircleStyle)
    raise ArgumentError.new("Radii must be non-negative, got rx=#{rx}, ry=#{ry}") if rx < 0 || ry < 0
    return if rx == 0 || ry == 0

    if style.fill
      filled_ellipse(img, center, rx, ry, style.color, style.anti_alias)
    else
      ellipse_outline(img, center, rx, ry, style.color, style.anti_alias)
    end
  end

  # Draw ellipse outline using midpoint ellipse algorithm
  private def self.ellipse_outline(img : Image, center : Point, rx : Int32, ry : Int32, color : Color::Color, anti_alias : Bool)
    return if rx == 0 || ry == 0

    bounds = img.bounds
    cx, cy = center.x, center.y

    if anti_alias
      # Anti-aliased ellipse
      draw_aa_ellipse(img, cx, cy, rx, ry, color)
    else
      # Midpoint ellipse algorithm
      # Region 1
      x = 0
      y = ry
      rx_sq = rx * rx
      ry_sq = ry * ry
      two_rx_sq = 2 * rx_sq
      two_ry_sq = 2 * ry_sq

      px = 0
      py = two_rx_sq * y

      # Plot initial points
      plot_ellipse_points(img, cx, cy, x, y, color, bounds)

      # Region 1: slope > -1
      p = ry_sq - (rx_sq * ry) + (0.25 * rx_sq)
      while px < py
        x += 1
        px += two_ry_sq

        if p < 0
          p += ry_sq + px
        else
          y -= 1
          py -= two_rx_sq
          p += ry_sq + px - py
        end

        plot_ellipse_points(img, cx, cy, x, y, color, bounds)
      end

      # Region 2: slope < -1
      p = ry_sq * (x + 0.5) * (x + 0.5) + rx_sq * (y - 1) * (y - 1) - rx_sq * ry_sq
      while y > 0
        y -= 1
        py -= two_rx_sq

        if p > 0
          p += rx_sq - py
        else
          x += 1
          px += two_ry_sq
          p += rx_sq - py + px
        end

        plot_ellipse_points(img, cx, cy, x, y, color, bounds)
      end
    end
  end

  # Draw filled ellipse using scanline fill
  private def self.filled_ellipse(img : Image, center : Point, rx : Int32, ry : Int32, color : Color::Color, anti_alias : Bool)
    return if rx == 0 || ry == 0

    bounds = img.bounds
    cx, cy = center.x, center.y

    if anti_alias
      # Fill interior then draw anti-aliased edge
      (-ry..ry).each do |dy|
        y = cy + dy
        next if y < bounds.min.y || y >= bounds.max.y

        # Calculate x extent for this y using ellipse equation
        # x^2/rx^2 + y^2/ry^2 = 1
        # x = rx * sqrt(1 - y^2/ry^2)
        if ry > 0
          factor = 1.0 - (dy * dy).to_f64 / (ry * ry)
          factor = [factor, 0.0].max
          dx = (rx * ::Math.sqrt(factor)).to_i

          x_start = [cx - dx, bounds.min.x].max
          x_end = [cx + dx, bounds.max.x - 1].min

          (x_start..x_end).each do |x|
            img.set(x, y, color)
          end
        end
      end

      # Draw anti-aliased edge
      draw_aa_ellipse(img, cx, cy, rx, ry, color)
    else
      # Use midpoint algorithm to determine scanlines
      x = 0
      y = ry
      rx_sq = rx * rx
      ry_sq = ry * ry
      two_rx_sq = 2 * rx_sq
      two_ry_sq = 2 * ry_sq

      px = 0
      py = two_rx_sq * y

      # Fill initial scanlines
      fill_ellipse_scanline(img, cx, cy, x, y, color, bounds)

      # Region 1
      p = ry_sq - (rx_sq * ry) + (0.25 * rx_sq)
      while px < py
        x += 1
        px += two_ry_sq

        if p < 0
          p += ry_sq + px
        else
          y -= 1
          py -= two_rx_sq
          p += ry_sq + px - py
        end

        fill_ellipse_scanline(img, cx, cy, x, y, color, bounds)
      end

      # Region 2
      p = ry_sq * (x + 0.5) * (x + 0.5) + rx_sq * (y - 1) * (y - 1) - rx_sq * ry_sq
      while y > 0
        y -= 1
        py -= two_rx_sq

        if p > 0
          p += rx_sq - py
        else
          x += 1
          px += two_ry_sq
          p += rx_sq - py + px
        end

        fill_ellipse_scanline(img, cx, cy, x, y, color, bounds)
      end
    end
  end

  # Plot ellipse points in all 4 quadrants
  private def self.plot_ellipse_points(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    plot_if_in_bounds(img, cx + x, cy + y, color, bounds)
    plot_if_in_bounds(img, cx - x, cy + y, color, bounds)
    plot_if_in_bounds(img, cx + x, cy - y, color, bounds)
    plot_if_in_bounds(img, cx - x, cy - y, color, bounds)
  end

  # Fill horizontal scanlines for filled ellipse
  private def self.fill_ellipse_scanline(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, color : Color::Color, bounds : Rectangle)
    fill_horizontal_line(img, cx - x, cx + x, cy + y, color, bounds)
    fill_horizontal_line(img, cx - x, cx + x, cy - y, color, bounds)
  end

  # Draw anti-aliased ellipse
  private def self.draw_aa_ellipse(img : Image, cx : Int32, cy : Int32, rx : Int32, ry : Int32, color : Color::Color)
    # Sample points around the ellipse perimeter
    # Use parametric form: x = rx*cos(t), y = ry*sin(t)
    steps = [rx, ry].max * 4
    steps.times do |i|
      t = 2.0 * ::Math::PI * i / steps
      x = (rx * ::Math.cos(t)).round.to_i
      y = (ry * ::Math.sin(t)).round.to_i

      # Calculate distance from ideal ellipse for alpha
      # For simplicity, use fixed alpha for now
      plot_aa(img, cx + x, cy + y, color, 1.0)
    end
  end

  # PolygonStyle defines the appearance of a polygon
  class PolygonStyle
    property outline_color : Color::Color?
    property fill_color : Color::Color?
    property anti_alias : Bool
    property blend_mode : BlendMode?

    def initialize(@outline_color = nil, @fill_color = nil, @anti_alias = false, @blend_mode = nil)
    end

    # Builder pattern methods for fluent API
    def with_outline(color : Color::Color) : self
      @outline_color = color
      self
    end

    def with_fill(color : Color::Color) : self
      @fill_color = color
      self
    end

    def with_anti_alias(enabled : Bool = true) : self
      @anti_alias = enabled
      self
    end

    def with_blend_mode(mode : BlendMode) : self
      @blend_mode = mode
      self
    end

    # DSL-style builder
    def self.build(&block : PolygonStyle ->) : PolygonStyle
      style = new
      yield style
      style
    end
  end

  # Draws a polygon from an array of points.
  #
  # Supports both outlined and filled polygons. Filled polygons use scanline
  # filling for efficiency. Requires at least 3 points to form a valid polygon.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of points defining the polygon vertices
  # - `style` : Polygon appearance settings (color, fill, outline)
  #
  # Raises: `ArgumentError` if fewer than 3 points are provided
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300)
  # triangle = [
  #   CrImage.point(200, 50),
  #   CrImage.point(100, 200),
  #   CrImage.point(300, 200),
  # ]
  # style = CrImage::Draw::PolygonStyle.new(CrImage::Color.rgb(255, 255, 0), filled: true)
  # CrImage::Draw.polygon(img, triangle, style)
  # ```
  def self.polygon(img : Image, points : Array(Point), style : PolygonStyle)
    # Validate minimum number of points
    InputValidation.validate_polygon_points(points)

    # Draw filled polygon first (if requested)
    if fill_color = style.fill_color
      if blend_mode = style.blend_mode
        fill_polygon_blended(img, points, fill_color, blend_mode)
      else
        scanline_fill_polygon(img, points, fill_color)
      end
    end

    # Draw outline (if requested)
    if outline_color = style.outline_color
      polygon_outline(img, points, outline_color, style.anti_alias)
    end
  end

  # Draw polygon outline by connecting points with lines
  private def self.polygon_outline(img : Image, points : Array(Point), color : Color::Color, anti_alias : Bool)
    # Connect each point to the next, and close the polygon
    points.size.times do |i|
      p1 = points[i]
      p2 = points[(i + 1) % points.size]

      # Use existing line drawing
      line_style = LineStyle.new(color, 1, anti_alias)
      line(img, p1, p2, line_style)
    end
  end

  # Fill polygon interior using scanline algorithm
  private def self.scanline_fill_polygon(img : Image, points : Array(Point), color : Color::Color)
    return if points.size < 3

    bounds = img.bounds

    # Find bounding box of polygon
    min_y = points.map(&.y).min
    max_y = points.map(&.y).max
    min_y = [min_y, bounds.min.y].max
    max_y = [max_y, bounds.max.y - 1].min

    # For each scanline
    (min_y..max_y).each do |y|
      # Find intersections with polygon edges
      intersections = [] of Int32

      points.size.times do |i|
        p1 = points[i]
        p2 = points[(i + 1) % points.size]

        # Skip horizontal edges
        next if p1.y == p2.y

        # Check if scanline intersects this edge
        if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)
          # Calculate x intersection
          # Using line equation: x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
          x = p1.x + (y - p1.y) * (p2.x - p1.x) // (p2.y - p1.y)
          intersections << x
        end
      end

      # Sort intersections
      intersections.sort!

      # Fill between pairs of intersections
      i = 0
      while i < intersections.size - 1
        x1 = intersections[i]
        x2 = intersections[i + 1]

        # Clip to image bounds
        x1 = [x1, bounds.min.x].max
        x2 = [x2, bounds.max.x - 1].min

        # Fill horizontal line
        (x1..x2).each do |x|
          img.set(x, y, color)
        end

        i += 2
      end
    end
  end

  # RectStyle defines the appearance of a rectangle
  class RectStyle
    property outline_color : Color::Color?
    property fill_color : Color::Color?
    property corner_radius : Int32
    property blend_mode : BlendMode?

    def initialize(@outline_color = nil, @fill_color = nil, @corner_radius = 0, @blend_mode = nil)
    end

    def with_outline(color : Color::Color) : self
      @outline_color = color
      self
    end

    def with_fill(color : Color::Color) : self
      @fill_color = color
      self
    end

    def with_corner_radius(radius : Int32) : self
      @corner_radius = radius
      self
    end

    def with_blend_mode(mode : BlendMode) : self
      @blend_mode = mode
      self
    end

    def self.build(&block : RectStyle ->) : RectStyle
      style = new
      yield style
      style
    end
  end

  # Draws a rectangle with optional rounded corners.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `rect` : Rectangle bounds
  # - `style` : Rectangle appearance settings
  def self.rectangle(img : Image, rect : Rectangle, style : RectStyle)
    if style.corner_radius > 0
      rounded_rectangle(img, rect, style)
    else
      simple_rectangle(img, rect, style)
    end
  end

  private def self.simple_rectangle(img : Image, rect : Rectangle, style : RectStyle)
    bounds = img.bounds
    blend_mode = style.blend_mode

    if fill_color = style.fill_color
      (rect.min.y...rect.max.y).each do |y|
        next if y < bounds.min.y || y >= bounds.max.y
        (rect.min.x...rect.max.x).each do |x|
          next if x < bounds.min.x || x >= bounds.max.x
          if blend_mode
            dst = img.at(x, y)
            blended = blend_colors(fill_color, dst, blend_mode)
            img.set(x, y, blended)
          else
            img.set(x, y, fill_color)
          end
        end
      end
    end

    if outline_color = style.outline_color
      # Top and bottom edges
      (rect.min.x...rect.max.x).each do |x|
        next if x < bounds.min.x || x >= bounds.max.x
        plot_if_in_bounds(img, x, rect.min.y, outline_color, bounds)
        plot_if_in_bounds(img, x, rect.max.y - 1, outline_color, bounds)
      end
      # Left and right edges
      (rect.min.y...rect.max.y).each do |y|
        next if y < bounds.min.y || y >= bounds.max.y
        plot_if_in_bounds(img, rect.min.x, y, outline_color, bounds)
        plot_if_in_bounds(img, rect.max.x - 1, y, outline_color, bounds)
      end
    end
  end

  private def self.rounded_rectangle(img : Image, rect : Rectangle, style : RectStyle)
    bounds = img.bounds
    radius = style.corner_radius
    width = rect.max.x - rect.min.x
    height = rect.max.y - rect.min.y
    blend_mode = style.blend_mode

    # Clamp radius to half the smaller dimension
    radius = [radius, width // 2, height // 2].min

    if fill_color = style.fill_color
      (rect.min.y...rect.max.y).each do |y|
        next if y < bounds.min.y || y >= bounds.max.y
        (rect.min.x...rect.max.x).each do |x|
          next if x < bounds.min.x || x >= bounds.max.x

          # Check if pixel is in rounded corner area
          local_x = x - rect.min.x
          local_y = y - rect.min.y

          if should_draw_rounded_pixel(local_x, local_y, width, height, radius)
            if blend_mode
              dst = img.at(x, y)
              blended = blend_colors(fill_color, dst, blend_mode)
              img.set(x, y, blended)
            else
              img.set(x, y, fill_color)
            end
          end
        end
      end
    end

    if outline_color = style.outline_color
      draw_rounded_rect_outline(img, rect, radius, outline_color, bounds)
    end
  end

  private def self.should_draw_rounded_pixel(x : Int32, y : Int32, width : Int32, height : Int32, radius : Int32) : Bool
    # Top-left corner
    if x < radius && y < radius
      dx = radius - x
      dy = radius - y
      return dx * dx + dy * dy <= radius * radius
    end

    # Top-right corner
    if x >= width - radius && y < radius
      dx = x - (width - radius - 1)
      dy = radius - y
      return dx * dx + dy * dy <= radius * radius
    end

    # Bottom-left corner
    if x < radius && y >= height - radius
      dx = radius - x
      dy = y - (height - radius - 1)
      return dx * dx + dy * dy <= radius * radius
    end

    # Bottom-right corner
    if x >= width - radius && y >= height - radius
      dx = x - (width - radius - 1)
      dy = y - (height - radius - 1)
      return dx * dx + dy * dy <= radius * radius
    end

    true
  end

  private def self.draw_rounded_rect_outline(img : Image, rect : Rectangle, radius : Int32, color : Color::Color, bounds : Rectangle)
    x1, y1 = rect.min.x, rect.min.y
    x2, y2 = rect.max.x - 1, rect.max.y - 1

    # Draw straight edges (excluding corners)
    # Top edge
    ((x1 + radius)..(x2 - radius)).each do |x|
      plot_if_in_bounds(img, x, y1, color, bounds)
    end
    # Bottom edge
    ((x1 + radius)..(x2 - radius)).each do |x|
      plot_if_in_bounds(img, x, y2, color, bounds)
    end
    # Left edge
    ((y1 + radius)..(y2 - radius)).each do |y|
      plot_if_in_bounds(img, x1, y, color, bounds)
    end
    # Right edge
    ((y1 + radius)..(y2 - radius)).each do |y|
      plot_if_in_bounds(img, x2, y, color, bounds)
    end

    # Draw corner arcs using midpoint circle algorithm
    draw_corner_arc(img, x1 + radius, y1 + radius, radius, :top_left, color, bounds)
    draw_corner_arc(img, x2 - radius, y1 + radius, radius, :top_right, color, bounds)
    draw_corner_arc(img, x1 + radius, y2 - radius, radius, :bottom_left, color, bounds)
    draw_corner_arc(img, x2 - radius, y2 - radius, radius, :bottom_right, color, bounds)
  end

  private def self.draw_corner_arc(img : Image, cx : Int32, cy : Int32, radius : Int32, corner : Symbol, color : Color::Color, bounds : Rectangle)
    x = 0
    y = radius
    d = 1 - radius

    plot_corner_point(img, cx, cy, x, y, corner, color, bounds)

    while x < y
      x += 1
      if d < 0
        d += 2 * x + 1
      else
        y -= 1
        d += 2 * (x - y) + 1
      end
      plot_corner_point(img, cx, cy, x, y, corner, color, bounds)
      plot_corner_point(img, cx, cy, y, x, corner, color, bounds) if x != y
    end
  end

  private def self.plot_corner_point(img : Image, cx : Int32, cy : Int32, x : Int32, y : Int32, corner : Symbol, color : Color::Color, bounds : Rectangle)
    case corner
    when :top_left
      plot_if_in_bounds(img, cx - x, cy - y, color, bounds)
    when :top_right
      plot_if_in_bounds(img, cx + x, cy - y, color, bounds)
    when :bottom_left
      plot_if_in_bounds(img, cx - x, cy + y, color, bounds)
    when :bottom_right
      plot_if_in_bounds(img, cx + x, cy + y, color, bounds)
    end
  end

  # DashedLineStyle defines the appearance of a dashed or dotted line
  class DashedLineStyle
    property color : Color::Color
    property dash_length : Int32
    property gap_length : Int32
    property thickness : Int32

    def initialize(@color, @dash_length = 5, @gap_length = 3, @thickness = 1)
    end

    def with_dash(dash : Int32, gap : Int32) : self
      @dash_length = dash
      @gap_length = gap
      self
    end

    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end

    # Preset for dotted line
    def self.dotted(color : Color::Color) : DashedLineStyle
      new(color, dash_length: 1, gap_length: 2)
    end

    # Preset for dashed line
    def self.dashed(color : Color::Color) : DashedLineStyle
      new(color, dash_length: 5, gap_length: 3)
    end

    # Preset for long dashes
    def self.long_dash(color : Color::Color) : DashedLineStyle
      new(color, dash_length: 10, gap_length: 5)
    end
  end

  # Draws a dashed or dotted line.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `p1` : Starting point
  # - `p2` : Ending point
  # - `style` : Dashed line appearance settings
  def self.dashed_line(img : Image, p1 : Point, p2 : Point, style : DashedLineStyle)
    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64
    length = ::Math.sqrt(dx * dx + dy * dy)
    return if length == 0

    # Normalize direction
    dx /= length
    dy /= length

    pattern_length = style.dash_length + style.gap_length
    pos = 0.0

    while pos < length
      # Calculate dash start and end
      dash_start = pos
      dash_end = [pos + style.dash_length, length].min

      # Draw this dash segment
      x1 = (p1.x + dx * dash_start).round.to_i
      y1 = (p1.y + dy * dash_start).round.to_i
      x2 = (p1.x + dx * dash_end).round.to_i
      y2 = (p1.y + dy * dash_end).round.to_i

      line_style = LineStyle.new(style.color, style.thickness, false)
      line(img, Point.new(x1, y1), Point.new(x2, y2), line_style)

      pos += pattern_length
    end
  end

  # ArcStyle defines the appearance of an arc or pie slice
  class ArcStyle
    property color : Color::Color
    property fill : Bool
    property thickness : Int32

    def initialize(@color, @fill = false, @thickness = 1)
    end

    def with_fill(enabled : Bool = true) : self
      @fill = enabled
      self
    end

    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end
  end

  # Draws an arc (portion of a circle).
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the arc
  # - `radius` : Radius in pixels
  # - `start_angle` : Starting angle in radians (0 = right, PI/2 = down)
  # - `end_angle` : Ending angle in radians
  # - `style` : Arc appearance settings
  def self.arc(img : Image, center : Point, radius : Int32, start_angle : Float64, end_angle : Float64, style : ArcStyle)
    return if radius <= 0

    bounds = img.bounds

    # Normalize angles
    while end_angle < start_angle
      end_angle += 2 * ::Math::PI
    end

    # Calculate number of steps based on arc length
    arc_length = (end_angle - start_angle) * radius
    steps = [arc_length.abs.to_i, 4].max

    prev_x = (center.x + radius * ::Math.cos(start_angle)).round.to_i
    prev_y = (center.y + radius * ::Math.sin(start_angle)).round.to_i

    (1..steps).each do |i|
      t = start_angle + (end_angle - start_angle) * i / steps
      curr_x = (center.x + radius * ::Math.cos(t)).round.to_i
      curr_y = (center.y + radius * ::Math.sin(t)).round.to_i

      if style.thickness == 1
        bresenham_line(img, Point.new(prev_x, prev_y), Point.new(curr_x, curr_y), style.color)
      else
        thick_line(img, Point.new(prev_x, prev_y), Point.new(curr_x, curr_y), style.color, style.thickness)
      end

      prev_x = curr_x
      prev_y = curr_y
    end
  end

  # Draws a pie slice (filled arc with lines to center).
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the pie
  # - `radius` : Radius in pixels
  # - `start_angle` : Starting angle in radians
  # - `end_angle` : Ending angle in radians
  # - `style` : Pie appearance settings
  def self.pie(img : Image, center : Point, radius : Int32, start_angle : Float64, end_angle : Float64, style : ArcStyle)
    return if radius <= 0

    bounds = img.bounds

    # Normalize angles
    while end_angle < start_angle
      end_angle += 2 * ::Math::PI
    end

    if style.fill
      # Fill the pie slice using scanline
      fill_pie(img, center, radius, start_angle, end_angle, style.color, bounds)
    end

    # Draw arc outline
    arc(img, center, radius, start_angle, end_angle, ArcStyle.new(style.color, false, style.thickness))

    # Draw lines from center to arc endpoints
    start_x = (center.x + radius * ::Math.cos(start_angle)).round.to_i
    start_y = (center.y + radius * ::Math.sin(start_angle)).round.to_i
    end_x = (center.x + radius * ::Math.cos(end_angle)).round.to_i
    end_y = (center.y + radius * ::Math.sin(end_angle)).round.to_i

    line_style = LineStyle.new(style.color, style.thickness, false)
    line(img, center, Point.new(start_x, start_y), line_style)
    line(img, center, Point.new(end_x, end_y), line_style)
  end

  # RingStyle defines the appearance of a ring (donut) slice
  class RingStyle
    property color : Color::Color
    property fill : Bool
    property thickness : Int32
    property anti_alias : Bool

    def initialize(@color, @fill = true, @thickness = 1, @anti_alias = false)
    end

    def with_fill(enabled : Bool = true) : self
      @fill = enabled
      self
    end

    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end

    def with_anti_alias(enabled : Bool = true) : self
      @anti_alias = enabled
      self
    end
  end

  # Draws a ring slice (donut segment) between two radii.
  #
  # This is useful for donut charts where you need a hollow center.
  # The slice is drawn between inner_radius and outer_radius within
  # the specified angle range.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the ring
  # - `inner_radius` : Inner radius in pixels (hole size)
  # - `outer_radius` : Outer radius in pixels
  # - `start_angle` : Starting angle in radians (0 = right, PI/2 = down)
  # - `end_angle` : Ending angle in radians
  # - `style` : Ring appearance settings
  #
  # Example:
  # ```
  # # Draw a donut chart segment
  # style = CrImage::Draw::RingStyle.new(CrImage::Color::RED, fill: true)
  # CrImage::Draw.ring_slice(img, center, 50, 100, 0.0, Math::PI/2, style)
  # ```
  def self.ring_slice(img : Image, center : Point, inner_radius : Int32, outer_radius : Int32,
                      start_angle : Float64, end_angle : Float64, style : RingStyle)
    return if outer_radius <= 0
    return if inner_radius >= outer_radius
    inner_radius = [inner_radius, 0].max

    bounds = img.bounds

    # Normalize angles
    while end_angle < start_angle
      end_angle += 2 * ::Math::PI
    end

    if style.fill
      fill_ring_slice(img, center, inner_radius, outer_radius, start_angle, end_angle, style.color, bounds, style.anti_alias)
    end

    # Draw outline arcs
    arc(img, center, outer_radius, start_angle, end_angle, ArcStyle.new(style.color, false, style.thickness))
    arc(img, center, inner_radius, start_angle, end_angle, ArcStyle.new(style.color, false, style.thickness)) if inner_radius > 0

    # Draw connecting lines at start and end angles
    inner_start_x = (center.x + inner_radius * ::Math.cos(start_angle)).round.to_i
    inner_start_y = (center.y + inner_radius * ::Math.sin(start_angle)).round.to_i
    outer_start_x = (center.x + outer_radius * ::Math.cos(start_angle)).round.to_i
    outer_start_y = (center.y + outer_radius * ::Math.sin(start_angle)).round.to_i

    inner_end_x = (center.x + inner_radius * ::Math.cos(end_angle)).round.to_i
    inner_end_y = (center.y + inner_radius * ::Math.sin(end_angle)).round.to_i
    outer_end_x = (center.x + outer_radius * ::Math.cos(end_angle)).round.to_i
    outer_end_y = (center.y + outer_radius * ::Math.sin(end_angle)).round.to_i

    line_style = LineStyle.new(style.color, style.thickness, false)
    line(img, Point.new(inner_start_x, inner_start_y), Point.new(outer_start_x, outer_start_y), line_style)
    line(img, Point.new(inner_end_x, inner_end_y), Point.new(outer_end_x, outer_end_y), line_style)
  end

  # Fill a ring slice using scanline algorithm
  private def self.fill_ring_slice(img : Image, center : Point, inner_radius : Int32, outer_radius : Int32,
                                   start_angle : Float64, end_angle : Float64, color : Color::Color,
                                   bounds : Rectangle, anti_alias : Bool)
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
        # Normalize angle to be >= start_angle
        while angle < start_angle
          angle += 2 * ::Math::PI
        end

        if angle <= end_angle
          if anti_alias
            # Calculate edge distance for anti-aliasing
            dist = ::Math.sqrt(dist_sq.to_f64)
            outer_edge = outer_radius - dist
            inner_edge = dist - inner_radius

            alpha = 1.0
            if outer_edge < 1.0 && outer_edge >= 0.0
              alpha = [alpha, outer_edge].min
            end
            if inner_edge < 1.0 && inner_edge >= 0.0
              alpha = [alpha, inner_edge].min
            end

            if alpha < 1.0
              plot_aa(img, x, y, color, alpha)
            else
              img.set(x, y, color)
            end
          else
            img.set(x, y, color)
          end
        end
      end
    end
  end

  private def self.fill_pie(img : Image, center : Point, radius : Int32, start_angle : Float64, end_angle : Float64, color : Color::Color, bounds : Rectangle)
    # Scan through bounding box and check if each pixel is in the pie
    (-radius..radius).each do |dy|
      y = center.y + dy
      next if y < bounds.min.y || y >= bounds.max.y

      (-radius..radius).each do |dx|
        x = center.x + dx
        next if x < bounds.min.x || x >= bounds.max.x

        # Check if point is within radius
        dist_sq = dx * dx + dy * dy
        next if dist_sq > radius * radius

        # Check if point is within angle range
        angle = ::Math.atan2(dy.to_f64, dx.to_f64)
        # Normalize angle to be >= start_angle
        while angle < start_angle
          angle += 2 * ::Math::PI
        end

        if angle <= end_angle
          img.set(x, y, color)
        end
      end
    end
  end

  # Draws a regular polygon (equilateral triangle, square, pentagon, hexagon, etc.)
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `center` : Center point of the polygon
  # - `radius` : Distance from center to vertices
  # - `sides` : Number of sides (3 = triangle, 4 = square, 5 = pentagon, etc.)
  # - `style` : Polygon appearance settings
  # - `rotation` : Rotation angle in radians (default 0, pointing right)
  #
  # Raises: `ArgumentError` if sides < 3 or radius < 0
  def self.regular_polygon(img : Image, center : Point, radius : Int32, sides : Int32, style : PolygonStyle, rotation : Float64 = 0.0)
    raise ArgumentError.new("Regular polygon must have at least 3 sides, got #{sides}") if sides < 3
    raise ArgumentError.new("Radius must be non-negative, got #{radius}") if radius < 0
    return if radius == 0

    # Generate vertices
    points = Array(Point).new(sides)
    sides.times do |i|
      angle = rotation + 2.0 * ::Math::PI * i / sides
      x = (center.x + radius * ::Math.cos(angle)).round.to_i
      y = (center.y + radius * ::Math.sin(angle)).round.to_i
      points << Point.new(x, y)
    end

    polygon(img, points, style)
  end

  # Convenience methods for common regular polygons

  # Draws an equilateral triangle
  def self.triangle(img : Image, center : Point, radius : Int32, style : PolygonStyle, rotation : Float64 = -::Math::PI / 2)
    regular_polygon(img, center, radius, 3, style, rotation)
  end

  # Draws a square (rotated 45° by default to have flat top)
  def self.square(img : Image, center : Point, radius : Int32, style : PolygonStyle, rotation : Float64 = ::Math::PI / 4)
    regular_polygon(img, center, radius, 4, style, rotation)
  end

  # Draws a pentagon
  def self.pentagon(img : Image, center : Point, radius : Int32, style : PolygonStyle, rotation : Float64 = -::Math::PI / 2)
    regular_polygon(img, center, radius, 5, style, rotation)
  end

  # Draws a hexagon (flat-top by default)
  def self.hexagon(img : Image, center : Point, radius : Int32, style : PolygonStyle, rotation : Float64 = 0.0)
    regular_polygon(img, center, radius, 6, style, rotation)
  end

  # BezierStyle defines the appearance of a bezier curve
  class BezierStyle
    property color : Color::Color
    property thickness : Int32
    property anti_alias : Bool
    property segments : Int32

    def initialize(@color, @thickness = 1, @anti_alias = false, @segments = 50)
    end

    def with_thickness(thickness : Int32) : self
      @thickness = thickness
      self
    end

    def with_anti_alias(enabled : Bool = true) : self
      @anti_alias = enabled
      self
    end

    def with_segments(segments : Int32) : self
      @segments = segments
      self
    end
  end

  # Draws a quadratic bezier curve (one control point).
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `p0` : Start point
  # - `p1` : Control point
  # - `p2` : End point
  # - `style` : Bezier curve appearance settings
  def self.quadratic_bezier(img : Image, p0 : Point, p1 : Point, p2 : Point, style : BezierStyle)
    segments = style.segments

    if style.thickness > 2 && style.anti_alias
      # Use stroke path for thick anti-aliased curves
      stroke_quadratic_bezier_thick(img, p0, p1, p2, style)
    else
      line_style = LineStyle.new(style.color, style.thickness, style.anti_alias)

      prev_x = p0.x
      prev_y = p0.y

      (1..segments).each do |i|
        t = i.to_f64 / segments

        # Quadratic bezier formula: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
        inv_t = 1.0 - t
        x = (inv_t * inv_t * p0.x + 2 * inv_t * t * p1.x + t * t * p2.x).round.to_i
        y = (inv_t * inv_t * p0.y + 2 * inv_t * t * p1.y + t * t * p2.y).round.to_i

        line(img, Point.new(prev_x, prev_y), Point.new(x, y), line_style)

        prev_x = x
        prev_y = y
      end
    end
  end

  # Stroke thick quadratic bezier using offset curves
  private def self.stroke_quadratic_bezier_thick(img : Image, p0 : Point, p1 : Point, p2 : Point, style : BezierStyle)
    half_thick = style.thickness.to_f64 / 2.0
    segments = style.segments

    # Generate points along the curve with normals
    points = [] of {Float64, Float64, Float64, Float64} # x, y, nx, ny

    (0..segments).each do |i|
      t = i.to_f64 / segments
      inv_t = 1.0 - t

      # Position
      x = inv_t * inv_t * p0.x + 2 * inv_t * t * p1.x + t * t * p2.x
      y = inv_t * inv_t * p0.y + 2 * inv_t * t * p1.y + t * t * p2.y

      # Tangent (derivative)
      tx = 2 * (1 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x)
      ty = 2 * (1 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)

      # Normalize and get perpendicular
      len = ::Math.sqrt(tx * tx + ty * ty)
      if len > 0.001
        nx = -ty / len
        ny = tx / len
      else
        nx = 0.0
        ny = 1.0
      end

      points << {x, y, nx, ny}
    end

    # Build polygon from offset curves
    polygon_points = [] of {Float64, Float64}

    # Left side (forward)
    points.each do |pt|
      polygon_points << {pt[0] + pt[2] * half_thick, pt[1] + pt[3] * half_thick}
    end

    # Right side (backward)
    points.reverse_each do |pt|
      polygon_points << {pt[0] - pt[2] * half_thick, pt[1] - pt[3] * half_thick}
    end

    fill_polygon_aa_float(img, polygon_points, style.color)
  end

  # Draws a cubic bezier curve (two control points).
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `p0` : Start point
  # - `p1` : First control point
  # - `p2` : Second control point
  # - `p3` : End point
  # - `style` : Bezier curve appearance settings
  def self.cubic_bezier(img : Image, p0 : Point, p1 : Point, p2 : Point, p3 : Point, style : BezierStyle)
    segments = style.segments

    if style.thickness > 2 && style.anti_alias
      # Use stroke path for thick anti-aliased curves
      stroke_cubic_bezier_thick(img, p0, p1, p2, p3, style)
    else
      line_style = LineStyle.new(style.color, style.thickness, style.anti_alias)

      prev_x = p0.x
      prev_y = p0.y

      (1..segments).each do |i|
        t = i.to_f64 / segments

        # Cubic bezier formula: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
        inv_t = 1.0 - t
        inv_t_sq = inv_t * inv_t
        inv_t_cu = inv_t_sq * inv_t
        t_sq = t * t
        t_cu = t_sq * t

        x = (inv_t_cu * p0.x + 3 * inv_t_sq * t * p1.x + 3 * inv_t * t_sq * p2.x + t_cu * p3.x).round.to_i
        y = (inv_t_cu * p0.y + 3 * inv_t_sq * t * p1.y + 3 * inv_t * t_sq * p2.y + t_cu * p3.y).round.to_i

        line(img, Point.new(prev_x, prev_y), Point.new(x, y), line_style)

        prev_x = x
        prev_y = y
      end
    end
  end

  # Stroke thick cubic bezier using offset curves
  private def self.stroke_cubic_bezier_thick(img : Image, p0 : Point, p1 : Point, p2 : Point, p3 : Point, style : BezierStyle)
    half_thick = style.thickness.to_f64 / 2.0
    segments = style.segments

    # Generate points along the curve with normals
    points = [] of {Float64, Float64, Float64, Float64} # x, y, nx, ny

    (0..segments).each do |i|
      t = i.to_f64 / segments
      inv_t = 1.0 - t
      inv_t_sq = inv_t * inv_t
      inv_t_cu = inv_t_sq * inv_t
      t_sq = t * t
      t_cu = t_sq * t

      # Position
      x = inv_t_cu * p0.x + 3 * inv_t_sq * t * p1.x + 3 * inv_t * t_sq * p2.x + t_cu * p3.x
      y = inv_t_cu * p0.y + 3 * inv_t_sq * t * p1.y + 3 * inv_t * t_sq * p2.y + t_cu * p3.y

      # Tangent (derivative of cubic bezier)
      tx = 3 * inv_t_sq * (p1.x - p0.x) + 6 * inv_t * t * (p2.x - p1.x) + 3 * t_sq * (p3.x - p2.x)
      ty = 3 * inv_t_sq * (p1.y - p0.y) + 6 * inv_t * t * (p2.y - p1.y) + 3 * t_sq * (p3.y - p2.y)

      # Normalize and get perpendicular
      len = ::Math.sqrt(tx * tx + ty * ty)
      if len > 0.001
        nx = -ty / len
        ny = tx / len
      else
        nx = 0.0
        ny = 1.0
      end

      points << {x, y, nx, ny}
    end

    # Build polygon from offset curves
    polygon_points = [] of {Float64, Float64}

    # Left side (forward)
    points.each do |pt|
      polygon_points << {pt[0] + pt[2] * half_thick, pt[1] + pt[3] * half_thick}
    end

    # Right side (backward)
    points.reverse_each do |pt|
      polygon_points << {pt[0] - pt[2] * half_thick, pt[1] - pt[3] * half_thick}
    end

    fill_polygon_aa_float(img, polygon_points, style.color)
  end

  # Draws a bezier spline through multiple points using Catmull-Rom interpolation.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of points to pass through
  # - `style` : Bezier curve appearance settings
  # - `tension` : Curve tension (0.0 = sharp corners, 1.0 = smooth)
  def self.spline(img : Image, points : Array(Point), style : BezierStyle, tension : Float64 = 0.5)
    return if points.size < 2

    if points.size == 2
      line(img, points[0], points[1], LineStyle.new(style.color, style.thickness, style.anti_alias))
      return
    end

    # Draw cubic bezier segments between each pair of points
    (0...points.size - 1).each do |i|
      p0 = points[[i - 1, 0].max]
      p1 = points[i]
      p2 = points[i + 1]
      p3 = points[[i + 2, points.size - 1].min]

      # Calculate control points using Catmull-Rom to Bezier conversion
      cp1_x = p1.x + (p2.x - p0.x) * tension / 3
      cp1_y = p1.y + (p2.y - p0.y) * tension / 3
      cp2_x = p2.x - (p3.x - p1.x) * tension / 3
      cp2_y = p2.y - (p3.y - p1.y) * tension / 3

      cubic_bezier(
        img,
        p1,
        Point.new(cp1_x.round.to_i, cp1_y.round.to_i),
        Point.new(cp2_x.round.to_i, cp2_y.round.to_i),
        p2,
        style
      )
    end
  end

  # Flattens a Catmull-Rom spline to an array of points.
  #
  # Useful for fills, clipping paths, hit testing, or any operation that needs
  # the interpolated points without drawing.
  #
  # Parameters:
  # - `points` : Control points the spline passes through
  # - `tension` : Curve tension (0.0 = sharp corners, 1.0 = smooth)
  # - `segments_per_span` : Number of line segments per curve span (default: 16)
  #
  # Returns: Array of interpolated points along the spline
  #
  # Example:
  # ```
  # control_points = [CrImage.point(10, 50), CrImage.point(50, 20), CrImage.point(90, 60)]
  # curve_points = CrImage::Draw.spline_flatten(control_points, tension: 0.5)
  # # Use curve_points for fills, hit testing, etc.
  # ```
  def self.spline_flatten(points : Array(Point), tension : Float64 = 0.5, segments_per_span : Int32 = 16) : Array(Point)
    return [] of Point if points.size < 2
    return points.dup if points.size == 2

    result = [] of Point

    (0...points.size - 1).each do |i|
      p0 = points[[i - 1, 0].max]
      p1 = points[i]
      p2 = points[i + 1]
      p3 = points[[i + 2, points.size - 1].min]

      # Calculate control points using Catmull-Rom to Bezier conversion
      cp1_x = p1.x + (p2.x - p0.x) * tension / 3
      cp1_y = p1.y + (p2.y - p0.y) * tension / 3
      cp2_x = p2.x - (p3.x - p1.x) * tension / 3
      cp2_y = p2.y - (p3.y - p1.y) * tension / 3

      # Sample this segment
      start_t = i == 0 ? 0 : 1
      (start_t..segments_per_span).each do |j|
        t = j.to_f64 / segments_per_span
        inv_t = 1.0 - t
        inv_t_sq = inv_t * inv_t
        inv_t_cu = inv_t_sq * inv_t
        t_sq = t * t
        t_cu = t_sq * t

        x = inv_t_cu * p1.x + 3 * inv_t_sq * t * cp1_x + 3 * inv_t * t_sq * cp2_x + t_cu * p2.x
        y = inv_t_cu * p1.y + 3 * inv_t_sq * t * cp1_y + 3 * inv_t * t_sq * cp2_y + t_cu * p2.y

        result << Point.new(x.round.to_i, y.round.to_i)
      end
    end

    result
  end

  # Draws connected line segments through an array of points.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of points to connect
  # - `style` : Line appearance settings
  #
  # Example:
  # ```
  # points = [CrImage.point(10, 10), CrImage.point(50, 30), CrImage.point(90, 20)]
  # style = CrImage::Draw::LineStyle.new(CrImage::Color::BLUE, thickness: 2)
  # CrImage::Draw.polyline(img, points, style)
  # ```
  def self.polyline(img : Image, points : Array(Point), style : LineStyle)
    return if points.size < 2

    (0...points.size - 1).each do |i|
      line(img, points[i], points[i + 1], style)
    end
  end

  # Draws a thick anti-aliased curve through multiple points.
  #
  # This is optimized for thick curves (like KDE lines in histograms)
  # and produces smooth results without gaps or artifacts.
  #
  # Parameters:
  # - `img` : The image to draw on
  # - `points` : Array of points the curve passes through
  # - `color` : Curve color
  # - `thickness` : Line thickness in pixels
  # - `tension` : Curve tension (0.0 = sharp corners, 1.0 = smooth)
  #
  # Example:
  # ```
  # points = [CrImage.point(10, 50), CrImage.point(50, 20), CrImage.point(90, 60)]
  # CrImage::Draw.thick_curve(img, points, CrImage::Color::BLUE, 4)
  # ```
  def self.thick_curve(img : Image, points : Array(Point), color : Color::Color,
                       thickness : Int32, tension : Float64 = 0.5)
    return if points.size < 2
    return if thickness < 1

    if points.size == 2
      line_style = LineStyle.new(color, thickness, true)
      line(img, points[0], points[1], line_style)
      return
    end

    half_thick = thickness.to_f64 / 2.0
    segments_per_span = 20

    # Generate all curve points with normals
    all_points = [] of {Float64, Float64, Float64, Float64} # x, y, nx, ny

    (0...points.size - 1).each do |i|
      p0 = points[[i - 1, 0].max]
      p1 = points[i]
      p2 = points[i + 1]
      p3 = points[[i + 2, points.size - 1].min]

      # Control points
      cp1_x = p1.x + (p2.x - p0.x) * tension / 3
      cp1_y = p1.y + (p2.y - p0.y) * tension / 3
      cp2_x = p2.x - (p3.x - p1.x) * tension / 3
      cp2_y = p2.y - (p3.y - p1.y) * tension / 3

      # Sample this segment
      start_t = i == 0 ? 0 : 1
      (start_t..segments_per_span).each do |j|
        t = j.to_f64 / segments_per_span
        inv_t = 1.0 - t
        inv_t_sq = inv_t * inv_t
        inv_t_cu = inv_t_sq * inv_t
        t_sq = t * t
        t_cu = t_sq * t

        # Position
        x = inv_t_cu * p1.x + 3 * inv_t_sq * t * cp1_x + 3 * inv_t * t_sq * cp2_x + t_cu * p2.x
        y = inv_t_cu * p1.y + 3 * inv_t_sq * t * cp1_y + 3 * inv_t * t_sq * cp2_y + t_cu * p2.y

        # Tangent
        tx = 3 * inv_t_sq * (cp1_x - p1.x) + 6 * inv_t * t * (cp2_x - cp1_x) + 3 * t_sq * (p2.x - cp2_x)
        ty = 3 * inv_t_sq * (cp1_y - p1.y) + 6 * inv_t * t * (cp2_y - cp1_y) + 3 * t_sq * (p2.y - cp2_y)

        # Normal
        len = ::Math.sqrt(tx * tx + ty * ty)
        if len > 0.001
          nx = -ty / len
          ny = tx / len
        else
          nx = 0.0
          ny = 1.0
        end

        all_points << {x, y, nx, ny}
      end
    end

    return if all_points.size < 2

    # Build stroke polygon
    polygon_points = [] of {Float64, Float64}

    # Left side
    all_points.each do |pt|
      polygon_points << {pt[0] + pt[2] * half_thick, pt[1] + pt[3] * half_thick}
    end

    # Right side (reversed)
    all_points.reverse_each do |pt|
      polygon_points << {pt[0] - pt[2] * half_thick, pt[1] - pt[3] * half_thick}
    end

    fill_polygon_aa_float(img, polygon_points, color)
  end
end
