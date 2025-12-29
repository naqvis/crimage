require "../image"
require "../color"
require "../geom"

module CrImage::Draw
  # CalloutStyle defines the appearance of a callout annotation.
  class CalloutStyle
    property background : Color::Color?
    property border : Color::Color?
    property border_thickness : Int32
    property corner_radius : Int32
    property padding : Int32
    property leader_thickness : Int32

    def initialize(@background = nil, @border = nil, @border_thickness = 1,
                   @corner_radius = 5, @padding = 8, @leader_thickness = 2)
    end
  end

  # Draws a callout box with a leader line pointing to a target.
  #
  # Example:
  # ```
  # style = CrImage::Draw::CalloutStyle.new(
  #   background: CrImage::Color::WHITE,
  #   border: CrImage::Color::BLACK
  # )
  # CrImage::Draw.callout(img, "Note: Important!", box_pos, target_pos, style)
  # ```
  def self.callout(img : Image, text : String, box_center : Point, target : Point,
                   style : CalloutStyle, face : Font::Face? = nil, text_color : Color::Color = Color::BLACK)
    # Calculate text bounds if face provided
    text_width = 100
    text_height = 20

    if f = face
      text_width = f.measure(text) + style.padding * 2
      text_height = f.line_height + style.padding * 2
    end

    # Box rectangle
    half_w = text_width // 2
    half_h = text_height // 2
    box_rect = CrImage.rect(
      box_center.x - half_w,
      box_center.y - half_h,
      box_center.x + half_w,
      box_center.y + half_h
    )

    # Draw leader line first (behind box)
    leader_style = LineStyle.new(style.border || Color::BLACK, style.leader_thickness)

    # Find closest point on box edge to target
    edge_point = closest_box_edge_point(box_rect, target)
    line(img, edge_point, target, leader_style)

    # Draw box background
    if bg = style.background
      radii = CornerRadii.uniform(style.corner_radius)
      rounded_rect(img, box_rect, radii, fill: bg)
    end

    # Draw box border
    if border = style.border
      radii = CornerRadii.uniform(style.corner_radius)
      rounded_rect(img, box_rect, radii, stroke: border, stroke_thickness: style.border_thickness)
    end

    # Draw text if face provided
    if f = face
      src = Uniform.new(text_color)
      drawer = Font::Drawer.new(img, src, f)
      text_x = box_center.x - (f.measure(text) // 2)
      text_y = box_center.y + (f.ascent // 2)
      drawer.draw_text(text, text_x, text_y)
    end
  end

  # Find closest point on box edge to external point
  private def self.closest_box_edge_point(box : Rectangle, target : Point) : Point
    cx = (box.min.x + box.max.x) // 2
    cy = (box.min.y + box.max.y) // 2

    dx = target.x - cx
    dy = target.y - cy

    if dx.abs > dy.abs
      # Horizontal edge
      if dx > 0
        Point.new(box.max.x, cy + dy * (box.max.x - cx) // dx.abs)
      else
        Point.new(box.min.x, cy - dy * (cx - box.min.x) // dx.abs)
      end
    else
      # Vertical edge
      if dy > 0
        Point.new(cx + dx * (box.max.y - cy) // dy.abs, box.max.y)
      else
        Point.new(cx - dx * (cy - box.min.y) // dy.abs, box.min.y)
      end
    end
  end

  # DimensionStyle defines the appearance of dimension lines.
  class DimensionStyle
    property color : Color::Color
    property thickness : Int32
    property extension_length : Int32 # Length of extension lines
    property arrow_size : Int32
    property gap : Int32 # Gap between object and extension line

    def initialize(@color = Color::BLACK, @thickness = 1, @extension_length = 10,
                   @arrow_size = 8, @gap = 5)
    end
  end

  # Draws a dimension line with measurements.
  #
  # Example:
  # ```
  # style = CrImage::Draw::DimensionStyle.new(color: CrImage::Color::BLACK)
  # CrImage::Draw.dimension_line(img, p1, p2, "100 px", style, face, offset: 30)
  # ```
  def self.dimension_line(img : Image, p1 : Point, p2 : Point, label : String,
                          style : DimensionStyle, face : Font::Face? = nil,
                          offset : Int32 = 20)
    # Calculate perpendicular direction
    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64
    length = ::Math.sqrt(dx * dx + dy * dy)

    return if length < 1

    # Unit vectors
    ux = dx / length
    uy = dy / length

    # Perpendicular (pointing away from object)
    px = -uy
    py = ux

    # Extension line endpoints
    ext1_start = Point.new(
      (p1.x + px * style.gap).round.to_i,
      (p1.y + py * style.gap).round.to_i
    )
    ext1_end = Point.new(
      (p1.x + px * (offset + style.extension_length)).round.to_i,
      (p1.y + py * (offset + style.extension_length)).round.to_i
    )

    ext2_start = Point.new(
      (p2.x + px * style.gap).round.to_i,
      (p2.y + py * style.gap).round.to_i
    )
    ext2_end = Point.new(
      (p2.x + px * (offset + style.extension_length)).round.to_i,
      (p2.y + py * (offset + style.extension_length)).round.to_i
    )

    # Dimension line endpoints
    dim1 = Point.new(
      (p1.x + px * offset).round.to_i,
      (p1.y + py * offset).round.to_i
    )
    dim2 = Point.new(
      (p2.x + px * offset).round.to_i,
      (p2.y + py * offset).round.to_i
    )

    line_style = LineStyle.new(style.color, style.thickness)

    # Draw extension lines
    line(img, ext1_start, ext1_end, line_style)
    line(img, ext2_start, ext2_end, line_style)

    # Draw dimension line with arrows
    arrow_style = ArrowStyle.new(style.color, style.thickness,
      head_size: style.arrow_size, head_at_start: true, head_at_end: true)
    arrow(img, dim1, dim2, arrow_style)

    # Draw label at center
    if f = face
      mid_x = (dim1.x + dim2.x) // 2
      mid_y = (dim1.y + dim2.y) // 2

      # Clear background for text
      text_width = f.measure(label)
      text_height = f.line_height

      bg_rect = CrImage.rect(
        mid_x - text_width // 2 - 2,
        mid_y - text_height // 2,
        mid_x + text_width // 2 + 2,
        mid_y + text_height // 2
      )

      # Fill background (assuming white, could be parameterized)
      (bg_rect.min.y...bg_rect.max.y).each do |y|
        (bg_rect.min.x...bg_rect.max.x).each do |x|
          if x >= 0 && x < img.bounds.max.x && y >= 0 && y < img.bounds.max.y
            img.set(x, y, Color::WHITE)
          end
        end
      end

      src = Uniform.new(style.color)
      drawer = Font::Drawer.new(img, src, f)
      drawer.draw_text(label, mid_x - text_width // 2, mid_y + f.ascent // 2)
    end
  end

  # BracketStyle defines the appearance of bracket annotations.
  class BracketStyle
    property color : Color::Color
    property thickness : Int32
    property tip_length : Int32 # Length of bracket tips

    def initialize(@color = Color::BLACK, @thickness = 2, @tip_length = 8)
    end
  end

  # Draws a bracket annotation (curly brace style).
  #
  # Example:
  # ```
  # style = CrImage::Draw::BracketStyle.new(color: CrImage::Color::BLACK)
  # CrImage::Draw.bracket(img, p1, p2, style, side: :right)
  # ```
  def self.bracket(img : Image, p1 : Point, p2 : Point, style : BracketStyle,
                   side : Symbol = :right, curve_amount : Int32 = 10)
    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64
    length = ::Math.sqrt(dx * dx + dy * dy)

    return if length < 1

    # Unit vectors
    ux = dx / length
    uy = dy / length

    # Perpendicular
    px = -uy
    py = ux

    # Flip for left side
    if side == :left
      px = -px
      py = -py
    end

    # Midpoint
    mid_x = (p1.x + p2.x) / 2.0
    mid_y = (p1.y + p2.y) / 2.0

    # Control points for curly brace shape
    tip1 = Point.new(
      (p1.x + px * style.tip_length).round.to_i,
      (p1.y + py * style.tip_length).round.to_i
    )

    tip2 = Point.new(
      (p2.x + px * style.tip_length).round.to_i,
      (p2.y + py * style.tip_length).round.to_i
    )

    mid_tip = Point.new(
      (mid_x + px * (style.tip_length + curve_amount)).round.to_i,
      (mid_y + py * (style.tip_length + curve_amount)).round.to_i
    )

    line_style = LineStyle.new(style.color, style.thickness)

    # Draw bracket as connected curves
    # Top half
    bezier_style = BezierStyle.new(style.color, style.thickness)
    quadratic_bezier(img, p1, tip1, Point.new(mid_x.round.to_i, mid_y.round.to_i), bezier_style)

    # Middle tip
    line(img, Point.new(mid_x.round.to_i, mid_y.round.to_i), mid_tip, line_style)

    # Bottom half
    quadratic_bezier(img, Point.new(mid_x.round.to_i, mid_y.round.to_i), tip2, p2, bezier_style)
  end

  # Draws a simple brace/bracket (square style).
  def self.square_bracket(img : Image, p1 : Point, p2 : Point, style : BracketStyle,
                          side : Symbol = :right)
    dx = (p2.x - p1.x).to_f64
    dy = (p2.y - p1.y).to_f64

    # Perpendicular
    px = -dy
    py = dx
    len = ::Math.sqrt(px * px + py * py)
    if len > 0
      px /= len
      py /= len
    end

    if side == :left
      px = -px
      py = -py
    end

    tip1 = Point.new(
      (p1.x + px * style.tip_length).round.to_i,
      (p1.y + py * style.tip_length).round.to_i
    )

    tip2 = Point.new(
      (p2.x + px * style.tip_length).round.to_i,
      (p2.y + py * style.tip_length).round.to_i
    )

    line_style = LineStyle.new(style.color, style.thickness)

    # Draw [ shape
    line(img, p1, tip1, line_style)
    line(img, tip1, tip2, line_style)
    line(img, tip2, p2, line_style)
  end
end
