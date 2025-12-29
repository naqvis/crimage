# Module Raster provides an anti-aliasing 2-D rasterizer.
#
# It is part of the larger Freetype suite of font-related modules, but the
# Raster module is not specific to font rasterization, and can be used
# standalone without any other Freetype shard.
#
# Rasterization is done by the same area/coverage accumulation algorithm as
# the Freetype "smooth" module, and the Anti-Grain Geometry library. A
# description of the area/coverage algorithm is at
# http://projects.tuxee.net/cl-vectors/section-the-cl-aa-algorithm
module FreeType::Raster
  alias Point26_6 = CrImage::Math::Fixed::Point26_6
  alias Int26_6 = CrImage::Math::Fixed::Int26_6

  # A Cell is part of a linked list (for a given yi co-ordinate) of accumulated
  # area/coverage for the pixel at (xi, yi)
  private class Cell
    property xi : Int32
    property area : Int32
    property cover : Int32
    property next : Int32

    def initialize(@xi = 0, @area = 0, @cover = 0, @next = 0)
    end
  end

  class Rasterizer
    # if false, the default behavior is to use the even-odd winding fill rule during rasterize.
    property use_non_zero_winding : Bool
    # An offset (in pixels) to the painted spans.
    property dx : Int32
    property dy : Int32

    def initialize(@use_non_zero_winding = false, @dx = 0, @dy = 0)
      # The width of the Rasterizer. The height is implicit in cell_index.size
      @width = 0
      # split_scale_x is the scaling factor used to determine how many times
      # to decompose a quadratic or cubic segment into a linear approximation.
      @split_scale_2 = 0
      @split_scale_3 = 0

      # The current pen position
      @a = Point26_6.new
      # The current cell and its area/coverage being accumulated.
      @xi = 0
      @yi = 0
      @area = 0
      @cover = 0

      # Saved cells.
      @cell = Array(Cell).new
      # Linked list of cells, one per row.
      @cell_index = Array(Int32).new
      # buffers
      @cell_buf = StaticArray(Cell, 256).new(Cell.new) # uninitialized Cell[256]
      @cell_index_buf = uninitialized Int32[64]
      @span_buf = StaticArray(Span, 64).new(Span.new)
    end

    # find_cell returns the index for the cell corresponding to
    # (xi, yi). The cell is created if necessary.
    private def find_cell
      return -1 if @yi < 0 || @yi >= @cell_index.size
      xi = @xi
      if xi < 0
        xi = -1
      elsif xi > @width
        xi = @width
      end
      i, prev = @cell_index[@yi], -1
      while i != -1 && @cell[i].xi <= xi
        return i if @cell[i].xi == xi
        i, prev = @cell[i].next, i
      end
      c = @cell.size
      @cell << Cell.new(xi, 0, 0, i)
      if prev == -1
        @cell_index[@yi] = c
      else
        @cell[prev].next = c
      end
      c
    end

    # save_cell saves any accumulated area/cover for (xi,yi)
    private def save_cell
      if @area != 0 || @cover != 0
        i = find_cell
        if i != -1
          @cell[i].area += @area
          @cell[i].cover += @cover
        end
        @area = 0
        @cover = 0
      end
    end

    # set_cell sets the (xi,yi) cell that is accumulating area/coverage for.
    private def set_cell(xi, yi)
      if @xi != xi || @yi != yi
        save_cell
        @xi, @yi = xi, yi
      end
    end

    # scan accumulates area/coverage for the yi'th scanline, going from
    # x0 to x1 in the horizontal direction (in 26.6 fixed point co-ordinates)
    # and from y0f to y1f fractional vertical units within that scanline.
    private def scan(yi, x0, y0f, x1, y1f)
      x0i = x0.to_i // 64
      x0f = x0 - Int26_6[64*x0i]
      x1i = x1.to_i // 64
      x1f = x1 - Int26_6[64*x1i]

      # A perfectly horizontal scan
      if y0f == y1f
        set_cell(x1i, yi.to_i)
        return
      end

      dx = x1 - x0
      # Convert to Int26_6 if needed
      y0f_fixed = y0f.is_a?(Int26_6) ? y0f : Int26_6[y0f]
      y1f_fixed = y1f.is_a?(Int26_6) ? y1f : Int26_6[y1f]
      dy = y1f_fixed - y0f_fixed

      # A single cell scan.
      if x0i == x1i
        @area += ((x0f + x1f).to_i * dy.to_i)
        @cover += dy.to_i
        return
      end
      # There are at least two cells. Apart from the first and last cells,
      # all intermediate cells go through the full width of the cell,
      # or 64 units in 26.6 fixed point format.
      if dx > Int26_6[0]
        p, q = dy * (64 - x0f.to_i), dx
        edge0, edge1, xi_delta = 0, 64, 1
      else
        p, q = x0f * dy, -dx
        edge0, edge1, xi_delta = 64, 0, -1
      end

      y_delta, y_rem = p.to_i//q.to_i, p.to_i % q.to_i
      if y_rem < 0
        y_delta -= 1
        y_rem += q.to_i
      end

      # Do the first cell.
      xi, y = x0i, y0f
      @area += ((x0f.to_i + edge1) * y_delta)
      @cover += y_delta
      xi, y = xi + xi_delta, y + y_delta
      set_cell(xi.to_i, yi.to_i)
      if xi != x1i
        # Do all the intermediate cells.
        p = (y1f_fixed - y + y_delta) * 64
        full_delta, full_rem = p.to_i//q.to_i, p.to_i % q.to_i
        if full_rem < 0
          full_delta -= 1
          full_rem += q.to_i
        end
        y_rem -= q.to_i
        while xi != x1i
          y_delta = full_delta
          y_rem += full_rem
          if y_rem >= 0
            y_delta += 1
            y_rem -= q.to_i
          end
          @area += (y_delta * 64)
          @cover += y_delta
          xi, y = xi + xi_delta, y + y_delta
          set_cell(xi.to_i, yi.to_i)
        end
      end

      # Do the last cell.
      y_delta = y1f_fixed - y
      @area += ((edge0.to_i + x1f.to_i) * y_delta.to_i)
      @cover += y_delta.to_i
    end

    # start starts a new curve at the given point
    def start(a : Point26_6)
      set_cell((a.x//64).to_i, (a.y//64).to_i)
      @a = a
    end

    # adds a linear segment to the current curve.
    def add1(b : Point26_6)
      x0, y0 = @a.x, @a.y
      x1, y1 = b.x, b.y
      dx, dy = x1 - x0, y1 - y0

      # Break the 26.6 fixed point y co-ordinates into integeral and fractional parts.
      y0i = (y0 // 64).to_i
      y0f = y0 - Int26_6[64*y0i]
      y1i = (y1 // 64).to_i
      y1f = y1 - Int26_6[64*y1i]

      if y0i == y1i
        # There is only one scanline.
        scan(y0i, x0, y0f, x1, y1f)
      elsif dx == Int26_6[0]
        # This is a vertical line segment. We avoid calling scan and instead
        # manipulate area and cover directly
        if dy > Int26_6[0]
          edge0, edge1, yi_delta = 0, 64, 1
        else
          edge0, edge1, yi_delta = 64, 0, -1
        end
        x0i, yi = x0.to_i//64, y0i
        x0f_times2 = (x0.to_i - (64 * x0i)) * 2
        # do the first pixel.
        dcover = (edge1 - y0f.to_i)
        darea = (x0f_times2 * dcover)
        @area += darea
        @cover += dcover
        yi += yi_delta
        set_cell(x0i, yi)
        # Do all the intermediate pixels.
        dcover = (edge1 - edge0)
        darea = (x0f_times2 * dcover)
        while yi != y1i
          @area += darea
          @cover += dcover
          yi += yi_delta
          set_cell(x0i, yi)
        end
        # Do the last pixel.
        dcover = (y1f.to_i - edge0)
        darea = (x0f_times2 * dcover)
        @area += darea
        @cover += dcover
      else
        # There are at least two scanlines. Apart from the first and last
        # scanlines, all intermediate scanlines go through the full height of
        # the row, or 64 units in 26.6 fixed point format.
        if dy > Int26_6[0]
          p, q = (y0f - 64) * dx, dy
          edge0, edge1, yi_delta = 0, 64, 1
        else
          p, q = y0f * dx, -dy
          edge0, edge1, yi_delta = 64, 0, -1
        end
        x_delta, x_rem = p.to_i / q.to_i, p.to_i % q.to_i
        if x_rem < 0
          x_delta -= 1
          x_rem += q.to_i
        end

        # Do the first scanline
        x, yi = x0, y0i
        scan(yi, x, y0f, x + x_delta, edge1)
        x, yi = x + x_delta, yi + yi_delta
        set_cell(x.to_i // 64, yi)
        if yi != y1i
          # Do all the intermediate scanlines
          p = dx * 64
          full_delta, full_rem = p.to_i/q.to_i, p.to_i % q.to_i
          if full_rem < 0
            full_delta -= 1
            full_rem += q.to_i
          end
          x_rem -= q.to_i
          while yi != y1i
            x_delta = full_delta
            x_rem += full_rem
            if x_rem >= 0
              x_delta += 1
              x_rem -= q.to_i
            end
            scan(yi, x, edge0, x + x_delta, edge1)
            x, yi = x + x_delta, yi + yi_delta
            set_cell(x.to_i//64, yi)
          end
        end
        # Do the last scanline.
        scan(yi, x, edge0, x1, y1f)
      end
      # The next line_to starts from b.
      @a = b
    end

    # add2 adds a quadratic Bézier segment to the current curve
    def add2(b : Point26_6, c : Point26_6)
      # Calculate nSplit based on how curvy it is
      # Specifically, how much the middle point b deviates from (a+c)/2
      dev_x = @a.x - b.x - b.x + c.x
      dev_y = @a.y - b.y - b.y + c.y
      dev = [dev_x.to_i.abs, dev_y.to_i.abs].max // 64 # Convert to pixels

      nsplit = 0
      while dev > 0
        dev //= 4
        nsplit += 1
      end

      # Maximum 16 splits
      nsplit = 16 if nsplit > 16

      # Use iterative subdivision with a stack
      if nsplit == 0
        add1(c)
        return
      end

      # Stack-based subdivision
      p_stack = Array(Point26_6).new(2 * nsplit + 3, Point26_6.new(Int26_6[0], Int26_6[0]))
      s_stack = Array(Int32).new(nsplit + 1, 0)

      s_stack[0] = nsplit
      p_stack[0] = c
      p_stack[1] = b
      p_stack[2] = @a

      i = 0
      while i >= 0
        s = s_stack[i]
        p_idx = 2 * i

        if s > 0
          # Split the quadratic curve
          mx = p_stack[p_idx + 1].x
          p_stack[p_idx + 4] = Point26_6.new(p_stack[p_idx + 2].x, p_stack[p_idx + 2].y)
          p_stack[p_idx + 3] = Point26_6.new((p_stack[p_idx + 4].x + mx) // 2, (p_stack[p_idx + 4].y + p_stack[p_idx + 1].y) // 2)
          p_stack[p_idx + 1] = Point26_6.new((p_stack[p_idx].x + mx) // 2, (p_stack[p_idx].y + p_stack[p_idx + 1].y) // 2)
          p_stack[p_idx + 2] = Point26_6.new((p_stack[p_idx + 1].x + p_stack[p_idx + 3].x) // 2, (p_stack[p_idx + 1].y + p_stack[p_idx + 3].y) // 2)

          s_stack[i] = s - 1
          s_stack[i + 1] = s - 1
          i += 1
        else
          # Draw line approximation
          midx = (p_stack[p_idx].x + p_stack[p_idx + 1].x + p_stack[p_idx + 1].x + p_stack[p_idx + 2].x) // 4
          midy = (p_stack[p_idx].y + p_stack[p_idx + 1].y + p_stack[p_idx + 1].y + p_stack[p_idx + 2].y) // 4
          add1(Point26_6.new(midx, midy))
          add1(p_stack[p_idx])
          i -= 1
        end
      end
    end

    # add3 adds a cubic Bézier segment to the current curve
    def add3(b : Point26_6, c : Point26_6, d : Point26_6)
      # Calculate nSplit based on how curvy the cubic is
      # Measure deviation of control points from the line a-d
      dev_x1 = @a.x - b.x - b.x - b.x + c.x + c.x + c.x
      dev_y1 = @a.y - b.y - b.y - b.y + c.y + c.y + c.y
      dev_x2 = @a.x + b.x + b.x + b.x - c.x - c.x - c.x - d.x - d.x - d.x + d.x + d.x + d.x
      dev_y2 = @a.y + b.y + b.y + b.y - c.y - c.y - c.y - d.y - d.y - d.y + d.y + d.y + d.y

      dev = [dev_x1.to_i.abs, dev_y1.to_i.abs, dev_x2.to_i.abs, dev_y2.to_i.abs].max // 64

      nsplit = 0
      while dev > 0
        dev //= 8
        nsplit += 1
      end

      # Maximum 16 splits
      nsplit = 16 if nsplit > 16

      # Use iterative subdivision with a stack
      if nsplit == 0
        add1(d)
        return
      end

      # Stack-based subdivision for cubic curves
      p_stack = Array(Point26_6).new(3 * nsplit + 4, Point26_6.new(Int26_6[0], Int26_6[0]))
      s_stack = Array(Int32).new(nsplit + 1, 0)

      s_stack[0] = nsplit
      p_stack[0] = d
      p_stack[1] = c
      p_stack[2] = b
      p_stack[3] = @a

      i = 0
      while i >= 0
        s = s_stack[i]
        p_idx = 3 * i

        if s > 0
          # Split the cubic curve using De Casteljau's algorithm
          # Calculate midpoints
          m01x = (p_stack[p_idx + 3].x + p_stack[p_idx + 2].x) // 2
          m01y = (p_stack[p_idx + 3].y + p_stack[p_idx + 2].y) // 2
          m12x = (p_stack[p_idx + 2].x + p_stack[p_idx + 1].x) // 2
          m12y = (p_stack[p_idx + 2].y + p_stack[p_idx + 1].y) // 2
          m23x = (p_stack[p_idx + 1].x + p_stack[p_idx].x) // 2
          m23y = (p_stack[p_idx + 1].y + p_stack[p_idx].y) // 2

          m012x = (m01x + m12x) // 2
          m012y = (m01y + m12y) // 2
          m123x = (m12x + m23x) // 2
          m123y = (m12y + m23y) // 2

          m0123x = (m012x + m123x) // 2
          m0123y = (m012y + m123y) // 2

          # First half: a, m01, m012, m0123
          p_stack[p_idx + 6] = Point26_6.new(p_stack[p_idx + 3].x, p_stack[p_idx + 3].y)
          p_stack[p_idx + 5] = Point26_6.new(m01x, m01y)
          p_stack[p_idx + 4] = Point26_6.new(m012x, m012y)
          p_stack[p_idx + 3] = Point26_6.new(m0123x, m0123y)

          # Second half: m0123, m123, m23, d
          p_stack[p_idx + 2] = Point26_6.new(m123x, m123y)
          p_stack[p_idx + 1] = Point26_6.new(m23x, m23y)

          s_stack[i] = s - 1
          s_stack[i + 1] = s - 1
          i += 1
        else
          # Draw line approximation
          add1(p_stack[p_idx])
          i -= 1
        end
      end
    end

    # Convert area to alpha value
    private def area_to_alpha(area : Int32) : UInt32
      # Round to nearest
      a = (area + 1) // 2
      a = -a if a < 0
      alpha = a.to_u32

      if @use_non_zero_winding
        alpha = 0x0fff_u32 if alpha > 0x0fff_u32
      else
        alpha &= 0x1fff_u32
        if alpha > 0x1000_u32
          alpha = 0x2000_u32 - alpha
        elsif alpha == 0x1000_u32
          alpha = 0x0fff_u32
        end
      end

      # Convert 12-bit alpha to 16-bit alpha
      (alpha << 4) | (alpha >> 8)
    end

    # rasterize rasterizes the accumulated curves
    def rasterize(painter : Painter, width : Int32, height : Int32)
      @width = width

      # Initialize cell index if needed
      if @cell_index.empty?
        @cell_index = Array(Int32).new(height, -1)
      end

      save_cell

      # Paint spans
      spans = @span_buf.to_a
      span_count = 0

      @cell_index.each_with_index do |cell_idx, y_idx|
        next if cell_idx == -1

        xi, cover = 0, 0
        i = cell_idx

        while i != -1
          cell = @cell[i]

          # Paint span from xi to cell.xi if cover is non-zero
          if cover != 0 && cell.xi > xi
            alpha = area_to_alpha(cover * 64 * 2)
            if alpha != 0
              xi0, xi1 = xi, cell.xi
              xi0 = 0 if xi0 < 0
              xi1 = @width if xi1 >= @width
              if xi0 < xi1
                spans[span_count] = Span.new(
                  y: y_idx + @dy,
                  x0: xi0 + @dx,
                  x1: xi1 + @dx,
                  alpha: alpha
                )
                span_count += 1
                if span_count > spans.size - 2
                  painter.paint(spans[0...span_count], false)
                  span_count = 0
                end
              end
            end
          end

          # Update cover BEFORE painting the cell
          cover += cell.cover

          # Paint the current cell
          alpha = area_to_alpha(cover * 64 * 2 - cell.area)
          xi = cell.xi + 1

          if alpha != 0
            xi0, xi1 = cell.xi, xi
            xi0 = 0 if xi0 < 0
            xi1 = @width if xi1 >= @width
            if xi0 < xi1
              spans[span_count] = Span.new(
                y: y_idx + @dy,
                x0: xi0 + @dx,
                x1: xi1 + @dx,
                alpha: alpha
              )
              span_count += 1
              if span_count > spans.size - 2
                painter.paint(spans[0...span_count], false)
                span_count = 0
              end
            end
          end

          i = cell.next
        end
      end

      # Paint remaining spans
      if span_count > 0
        painter.paint(spans[0...span_count], true)
      else
        painter.paint([] of Span, true)
      end

      # Clear for next use
      @cell.clear
      @cell_index.clear
    end

    # reset resets the rasterizer for reuse
    def reset(width : Int32, height : Int32)
      @width = width
      @cell.clear
      @cell_index = Array(Int32).new(height, -1)
      @xi = 0
      @yi = 0
      @area = 0
      @cover = 0
    end
  end
end

require "./paint"
require "../../crimage/math/fixed"
