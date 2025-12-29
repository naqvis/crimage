require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # CornerRadii defines individual corner radii for rounded rectangles.
  struct CornerRadii
    property top_left : Int32
    property top_right : Int32
    property bottom_right : Int32
    property bottom_left : Int32

    def initialize(@top_left = 0, @top_right = 0, @bottom_right = 0, @bottom_left = 0)
    end

    # Uniform radius for all corners
    def self.uniform(radius : Int32) : CornerRadii
      new(radius, radius, radius, radius)
    end

    # Top corners only (useful for bar charts)
    def self.top(radius : Int32) : CornerRadii
      new(radius, radius, 0, 0)
    end

    # Bottom corners only
    def self.bottom(radius : Int32) : CornerRadii
      new(0, 0, radius, radius)
    end

    # Left corners only
    def self.left(radius : Int32) : CornerRadii
      new(radius, 0, 0, radius)
    end

    # Right corners only
    def self.right(radius : Int32) : CornerRadii
      new(0, radius, radius, 0)
    end
  end

  # Draws a rounded rectangle with per-corner radius control.
  #
  # Example:
  # ```
  # # Bar chart with rounded top only
  # CrImage::Draw.rounded_rect(img, rect,
  #   CrImage::Draw::CornerRadii.top(10),
  #   fill: CrImage::Color::BLUE)
  #
  # # Custom per-corner radii
  # CrImage::Draw.rounded_rect(img, rect,
  #   CrImage::Draw::CornerRadii.new(top_left: 20, top_right: 5, bottom_right: 20, bottom_left: 5),
  #   fill: CrImage::Color::RED, stroke: CrImage::Color::BLACK)
  # ```
  def self.rounded_rect(img : Image, rect : Rectangle, radii : CornerRadii,
                        fill : Color::Color? = nil, stroke : Color::Color? = nil,
                        stroke_thickness : Int32 = 1)
    bounds = img.bounds
    x1, y1 = rect.min.x, rect.min.y
    x2, y2 = rect.max.x - 1, rect.max.y - 1
    w = rect.width
    h = rect.height

    # Clamp radii to half the smallest dimension
    max_radius = [w, h].min // 2
    tl = [radii.top_left, max_radius].min
    tr = [radii.top_right, max_radius].min
    br = [radii.bottom_right, max_radius].min
    bl = [radii.bottom_left, max_radius].min

    if fill
      fill_rounded_rect_impl(img, x1, y1, x2, y2, tl, tr, br, bl, fill, bounds)
    end

    if stroke
      stroke_rounded_rect_impl(img, x1, y1, x2, y2, tl, tr, br, bl, stroke, stroke_thickness, bounds)
    end
  end

  private def self.fill_rounded_rect_impl(img : Image, x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32,
                                          tl : Int32, tr : Int32, br : Int32, bl : Int32,
                                          color : Color::Color, bounds : Rectangle)
    # Fill row by row
    (y1..y2).each do |y|
      next if y < bounds.min.y || y >= bounds.max.y

      # Calculate x range for this row, accounting for corners
      left_x = x1
      right_x = x2

      # Top-left corner
      if y < y1 + tl && tl > 0
        dy = y1 + tl - y
        dx = tl - ::Math.sqrt((tl * tl - dy * dy).to_f64).round.to_i
        left_x = [left_x + dx, x1 + tl].min
      end

      # Top-right corner
      if y < y1 + tr && tr > 0
        dy = y1 + tr - y
        dx = tr - ::Math.sqrt((tr * tr - dy * dy).to_f64).round.to_i
        right_x = [right_x - dx, x2 - tr].max
      end

      # Bottom-left corner
      if y > y2 - bl && bl > 0
        dy = y - (y2 - bl)
        dx = bl - ::Math.sqrt((bl * bl - dy * dy).to_f64).round.to_i
        left_x = [left_x + dx, x1 + bl].min
      end

      # Bottom-right corner
      if y > y2 - br && br > 0
        dy = y - (y2 - br)
        dx = br - ::Math.sqrt((br * br - dy * dy).to_f64).round.to_i
        right_x = [right_x - dx, x2 - br].max
      end

      # Fill the row
      left_x = [left_x, bounds.min.x].max
      right_x = [right_x, bounds.max.x - 1].min

      (left_x..right_x).each do |x|
        img.set(x, y, color)
      end
    end
  end

  private def self.stroke_rounded_rect_impl(img : Image, x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32,
                                            tl : Int32, tr : Int32, br : Int32, bl : Int32,
                                            color : Color::Color, thickness : Int32, bounds : Rectangle)
    # Draw the four straight edges
    line_style = LineStyle.new(color, thickness)

    # Top edge (between corners)
    line(img, Point.new(x1 + tl, y1), Point.new(x2 - tr, y1), line_style)
    # Bottom edge
    line(img, Point.new(x1 + bl, y2), Point.new(x2 - br, y2), line_style)
    # Left edge
    line(img, Point.new(x1, y1 + tl), Point.new(x1, y2 - bl), line_style)
    # Right edge
    line(img, Point.new(x2, y1 + tr), Point.new(x2, y2 - br), line_style)

    # Draw corner arcs
    draw_corner_arc(img, x1 + tl, y1 + tl, tl, ::Math::PI, ::Math::PI * 1.5, color, thickness, bounds) if tl > 0
    draw_corner_arc(img, x2 - tr, y1 + tr, tr, ::Math::PI * 1.5, ::Math::PI * 2, color, thickness, bounds) if tr > 0
    draw_corner_arc(img, x2 - br, y2 - br, br, 0.0, ::Math::PI * 0.5, color, thickness, bounds) if br > 0
    draw_corner_arc(img, x1 + bl, y2 - bl, bl, ::Math::PI * 0.5, ::Math::PI, color, thickness, bounds) if bl > 0
  end

  private def self.draw_corner_arc(img : Image, cx : Int32, cy : Int32, radius : Int32,
                                   start_angle : Float64, end_angle : Float64,
                                   color : Color::Color, thickness : Int32, bounds : Rectangle)
    return if radius <= 0

    steps = [radius * 2, 16].max
    prev_x = (cx + radius * ::Math.cos(start_angle)).round.to_i
    prev_y = (cy + radius * ::Math.sin(start_angle)).round.to_i

    (1..steps).each do |i|
      angle = start_angle + (end_angle - start_angle) * i / steps
      x = (cx + radius * ::Math.cos(angle)).round.to_i
      y = (cy + radius * ::Math.sin(angle)).round.to_i

      if thickness == 1
        if BoundsCheck.in_bounds?(x, y, bounds)
          img.set(x, y, color)
        end
      else
        line(img, Point.new(prev_x, prev_y), Point.new(x, y), LineStyle.new(color, thickness))
      end

      prev_x, prev_y = x, y
    end
  end
end
