require "../image"
require "../color"
require "../geom"
require "../font/font"

module CrImage::Draw
  # Draws text along a curved path (bezier curve or arc).
  #
  # Each character is positioned and rotated to follow the curve tangent.
  # Useful for circular labels around pie/donut charts, curved axis labels.
  #
  # Parameters:
  # - `img` : Image to draw on
  # - `text` : Text to render
  # - `curve` : Cubic bezier curve to follow
  # - `face` : Font face
  # - `color` : Text color
  # - `offset` : Starting position along curve (0.0 = auto-center)
  # - `text_offset` : Perpendicular offset from curve (negative = above, positive = below)
  #
  # Example:
  # ```
  # # Text along a bezier curve, positioned above the line
  # curve = CrImage::Draw::CubicBezier.new(
  #   {50.0, 200.0}, {150.0, 50.0}, {250.0, 50.0}, {350.0, 200.0}
  # )
  # CrImage::Draw.text_on_curve(img, "Hello Curved World!", curve, face, color, text_offset: -20)
  # ```
  def self.text_on_curve(img : Image, text : String, curve : CubicBezier,
                         face : Font::Face, color : Color::Color,
                         offset : Float64 = 0.0, text_offset : Int32 = 0)
    return if text.empty?

    # Calculate total curve length (approximate)
    curve_length = estimate_curve_length(curve, 100)

    # Measure text width
    text_width = face.measure(text).to_f64

    # Starting t position (centered on curve by default)
    start_t = offset
    if start_t == 0.0
      # Center text on curve
      start_t = (curve_length - text_width) / 2.0 / curve_length
      start_t = [start_t, 0.0].max
    end

    # Create uniform color source
    src = Uniform.new(color)

    current_t = start_t
    prev_char = Char::ZERO

    text.each_char do |char|
      # Get character advance
      advance, ok = face.glyph_advance(char)
      next unless ok

      char_width = advance.to_i.to_f64 / 64.0

      # Calculate position on curve
      t = current_t + (char_width / 2.0) / curve_length
      t = [[t, 0.0].max, 1.0].min

      pos = curve.at(t)
      tangent = curve_tangent(curve, t)

      # Calculate perpendicular (normal) vector for offset
      # Normal is perpendicular to tangent: rotate 90 degrees counter-clockwise
      normal_x = -tangent[1]
      normal_y = tangent[0]

      # Apply text offset perpendicular to curve
      draw_x = (pos[0] + normal_x * text_offset).round.to_i
      draw_y = (pos[1] + normal_y * text_offset).round.to_i

      # Calculate rotation angle from tangent
      angle = ::Math.atan2(tangent[1], tangent[0])

      # Draw rotated character
      draw_rotated_char(img, char, draw_x, draw_y, angle, face, src)

      # Advance along curve
      current_t += char_width / curve_length

      # Add kerning
      if prev_char != Char::ZERO
        kern = face.kern(prev_char, char)
        current_t += (kern.to_i.to_f64 / 64.0) / curve_length
      end

      prev_char = char
    end
  end

  # Draws text along a circular arc.
  #
  # Parameters:
  # - `img` : Image to draw on
  # - `text` : Text to render
  # - `center` : Center of the arc
  # - `radius` : Radius of the arc (text baseline position)
  # - `start_angle` : Starting angle in radians
  # - `end_angle` : Ending angle in radians
  # - `face` : Font face
  # - `color` : Text color
  # - `align` : Text alignment on arc (:start, :center, :end)
  # - `text_offset` : Radial offset from arc (negative = toward center, positive = away)
  def self.text_on_arc(img : Image, text : String, center : Point, radius : Int32,
                       start_angle : Float64, end_angle : Float64,
                       face : Font::Face, color : Color::Color,
                       align : Symbol = :center, text_offset : Int32 = 0)
    return if text.empty?

    # Effective radius includes text offset
    effective_radius = radius + text_offset

    # Calculate arc length at effective radius
    arc_length = effective_radius.to_f64.abs * (end_angle - start_angle).abs

    # Measure text
    text_width = face.measure(text).to_f64

    # Calculate starting angle based on alignment
    angle_per_pixel = (end_angle - start_angle) / arc_length

    start_offset = case align
                   when :center then (arc_length - text_width) / 2.0
                   when :end    then arc_length - text_width
                   else              0.0
                   end

    current_angle = start_angle + start_offset * angle_per_pixel

    src = Uniform.new(color)
    prev_char = Char::ZERO

    text.each_char do |char|
      advance, ok = face.glyph_advance(char)
      next unless ok

      char_width = advance.to_i.to_f64 / 64.0

      # Position at center of character
      char_angle = current_angle + (char_width / 2.0) * angle_per_pixel

      x = center.x + (effective_radius * ::Math.cos(char_angle)).round.to_i
      y = center.y + (effective_radius * ::Math.sin(char_angle)).round.to_i

      # Rotation: tangent to circle (perpendicular to radius)
      rotation = char_angle + ::Math::PI / 2

      draw_rotated_char(img, char, x, y, rotation, face, src)

      current_angle += char_width * angle_per_pixel

      if prev_char != Char::ZERO
        kern = face.kern(prev_char, char)
        current_angle += (kern.to_i.to_f64 / 64.0) * angle_per_pixel
      end

      prev_char = char
    end
  end

  # Estimate curve length by sampling
  private def self.estimate_curve_length(curve : CubicBezier, samples : Int32) : Float64
    length = 0.0
    prev = curve.at(0.0)

    (1..samples).each do |i|
      t = i.to_f64 / samples
      current = curve.at(t)
      dx = current[0] - prev[0]
      dy = current[1] - prev[1]
      length += ::Math.sqrt(dx * dx + dy * dy)
      prev = current
    end

    length
  end

  # Calculate tangent vector at point t on curve
  private def self.curve_tangent(curve : CubicBezier, t : Float64) : {Float64, Float64}
    # Derivative of cubic bezier
    p0, p1, p2, p3 = curve.p0, curve.p1, curve.p2, curve.p3
    inv_t = 1.0 - t

    # B'(t) = 3(1-t)²(P1-P0) + 6(1-t)t(P2-P1) + 3t²(P3-P2)
    dx = 3 * inv_t * inv_t * (p1[0] - p0[0]) +
         6 * inv_t * t * (p2[0] - p1[0]) +
         3 * t * t * (p3[0] - p2[0])

    dy = 3 * inv_t * inv_t * (p1[1] - p0[1]) +
         6 * inv_t * t * (p2[1] - p1[1]) +
         3 * t * t * (p3[1] - p2[1])

    # Normalize
    len = ::Math.sqrt(dx * dx + dy * dy)
    if len > 0.001
      {dx / len, dy / len}
    else
      {1.0, 0.0}
    end
  end

  # Draw a single rotated character
  private def self.draw_rotated_char(img : Image, char : Char, cx : Int32, cy : Int32,
                                     angle : Float64, face : Font::Face, src : Image)
    # Get glyph at origin
    dot = Math::Fixed::Point26_6.new(
      Math::Fixed::Int26_6[0],
      Math::Fixed::Int26_6[0]
    )

    dr, mask, maskp, _, ok = face.glyph(dot, char)
    return unless ok

    cos_a = ::Math.cos(angle)
    sin_a = ::Math.sin(angle)

    bounds = img.bounds

    # For each pixel in the glyph mask, rotate and draw
    (dr.min.y...dr.max.y).each do |gy|
      (dr.min.x...dr.max.x).each do |gx|
        # Get mask value
        mx = maskp.x + (gx - dr.min.x)
        my = maskp.y + (gy - dr.min.y)

        mask_bounds = mask.bounds
        next unless mx >= mask_bounds.min.x && mx < mask_bounds.max.x
        next unless my >= mask_bounds.min.y && my < mask_bounds.max.y

        _, _, _, ma = mask.at(mx, my).rgba
        next if ma == 0

        # Rotate around center
        rx = gx - dr.min.x - (dr.width // 2)
        ry = gy - dr.min.y - (dr.height // 2)

        nx = (rx * cos_a - ry * sin_a).round.to_i + cx
        ny = (rx * sin_a + ry * cos_a).round.to_i + cy

        next unless nx >= bounds.min.x && nx < bounds.max.x
        next unless ny >= bounds.min.y && ny < bounds.max.y

        # Blend with alpha
        sr, sg, sb, sa = src.at(0, 0).rgba
        dr_c, dg, db, da = img.at(nx, ny).rgba

        alpha = (ma.to_f64 / Color::MAX_32BIT)
        inv_alpha = 1.0 - alpha

        nr = (sr.to_f64 * alpha + dr_c.to_f64 * inv_alpha).clamp(0.0, 65535.0).to_u16
        ng = (sg.to_f64 * alpha + dg.to_f64 * inv_alpha).clamp(0.0, 65535.0).to_u16
        nb = (sb.to_f64 * alpha + db.to_f64 * inv_alpha).clamp(0.0, 65535.0).to_u16
        na = (sa.to_f64 * alpha + da.to_f64 * inv_alpha).clamp(0.0, 65535.0).to_u16

        img.set(nx, ny, Color::RGBA64.new(nr, ng, nb, na))
      end
    end
  end
end
