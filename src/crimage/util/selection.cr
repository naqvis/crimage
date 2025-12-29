module CrImage::Util
  # Selection and flood fill operations for image editing.
  #
  # Provides tools for selecting regions based on color similarity
  # and filling areas with new colors.
  module Selection
    # Performs flood fill starting from a seed point.
    #
    # Fills all connected pixels that are similar to the seed pixel's color
    # within the specified tolerance.
    #
    # Parameters:
    # - `img` : The image to modify (modified in place)
    # - `x` : Starting X coordinate
    # - `y` : Starting Y coordinate
    # - `fill_color` : Color to fill with
    # - `tolerance` : Maximum color difference to consider "similar" (0-255)
    #
    # Returns: Number of pixels filled
    def self.flood_fill(img : RGBA, x : Int32, y : Int32,
                        fill_color : Color::Color,
                        tolerance : Int32 = 10) : Int32
      bounds = img.bounds
      return 0 unless BoundsCheck.in_bounds?(x, y, bounds)

      # Get the target color at seed point
      target = img.at(x, y)
      tr, tg, tb, ta = target.rgba

      # Check if fill color is same as target (nothing to do)
      fr, fg, fb, fa = fill_color.rgba
      if colors_similar?(tr, tg, tb, ta, fr, fg, fb, fa, 0)
        return 0
      end

      # Use a queue-based flood fill (more efficient than recursion)
      queue = Deque({Int32, Int32}).new
      queue << {x, y}

      # Track visited pixels
      visited = Set({Int32, Int32}).new
      visited << {x, y}

      filled = 0

      while !queue.empty?
        cx, cy = queue.shift

        # Get current pixel color
        current = img.at(cx, cy)
        cr, cg, cb, ca = current.rgba

        # Check if this pixel matches the target color
        if colors_similar?(tr, tg, tb, ta, cr, cg, cb, ca, tolerance)
          # Fill this pixel
          img.set(cx, cy, fill_color)
          filled += 1

          # Add neighbors to queue
          [{cx - 1, cy}, {cx + 1, cy}, {cx, cy - 1}, {cx, cy + 1}].each do |nx, ny|
            if BoundsCheck.in_bounds?(nx, ny, bounds) && !visited.includes?({nx, ny})
              visited << {nx, ny}
              queue << {nx, ny}
            end
          end
        end
      end

      filled
    end

    # Creates a selection mask based on color similarity.
    #
    # Returns a grayscale image where white (255) indicates selected pixels
    # and black (0) indicates unselected pixels.
    #
    # Parameters:
    # - `img` : Source image
    # - `x` : Seed point X coordinate
    # - `y` : Seed point Y coordinate
    # - `tolerance` : Maximum color difference (0-255)
    # - `contiguous` : If true, only selects connected pixels; if false, selects all similar pixels
    #
    # Returns: Gray image representing the selection mask
    def self.select_by_color(img : Image, x : Int32, y : Int32,
                             tolerance : Int32 = 10,
                             contiguous : Bool = true) : Gray
      bounds = img.bounds
      width = bounds.width
      height = bounds.height
      mask = CrImage.gray(width, height)

      return mask unless BoundsCheck.in_bounds?(x, y, bounds)

      # Get the target color at seed point
      target = img.at(x + bounds.min.x, y + bounds.min.y)
      tr, tg, tb, ta = target.rgba

      if contiguous
        # Flood fill approach for contiguous selection
        queue = Deque({Int32, Int32}).new
        queue << {x, y}
        visited = Set({Int32, Int32}).new
        visited << {x, y}

        while !queue.empty?
          cx, cy = queue.shift
          current = img.at(cx + bounds.min.x, cy + bounds.min.y)
          cr, cg, cb, ca = current.rgba

          if colors_similar?(tr, tg, tb, ta, cr, cg, cb, ca, tolerance)
            mask.set(cx, cy, Color::Gray.new(255_u8))

            [{cx - 1, cy}, {cx + 1, cy}, {cx, cy - 1}, {cx, cy + 1}].each do |nx, ny|
              if nx >= 0 && nx < width && ny >= 0 && ny < height && !visited.includes?({nx, ny})
                visited << {nx, ny}
                queue << {nx, ny}
              end
            end
          end
        end
      else
        # Select all pixels with similar color
        height.times do |py|
          width.times do |px|
            current = img.at(px + bounds.min.x, py + bounds.min.y)
            cr, cg, cb, ca = current.rgba

            if colors_similar?(tr, tg, tb, ta, cr, cg, cb, ca, tolerance)
              mask.set(px, py, Color::Gray.new(255_u8))
            end
          end
        end
      end

      mask
    end

    # Replaces all pixels of one color with another.
    #
    # Parameters:
    # - `img` : Source image
    # - `target_color` : Color to replace
    # - `replacement_color` : New color
    # - `tolerance` : Maximum color difference (0-255)
    #
    # Returns: New RGBA image with colors replaced
    def self.replace_color(img : Image, target_color : Color::Color,
                           replacement_color : Color::Color,
                           tolerance : Int32 = 10) : RGBA
      bounds = img.bounds
      width = bounds.width
      height = bounds.height
      result = CrImage.rgba(width, height)

      tr, tg, tb, ta = target_color.rgba

      height.times do |y|
        width.times do |x|
          current = img.at(x + bounds.min.x, y + bounds.min.y)
          cr, cg, cb, ca = current.rgba

          if colors_similar?(tr, tg, tb, ta, cr, cg, cb, ca, tolerance)
            result.set(x, y, replacement_color)
          else
            result.set(x, y, Color::RGBA.new((cr >> 8).to_u8, (cg >> 8).to_u8, (cb >> 8).to_u8, (ca >> 8).to_u8))
          end
        end
      end

      result
    end

    # Checks if two colors are similar within tolerance.
    private def self.colors_similar?(r1 : UInt32, g1 : UInt32, b1 : UInt32, a1 : UInt32,
                                     r2 : UInt32, g2 : UInt32, b2 : UInt32, a2 : UInt32,
                                     tolerance : Int32) : Bool
      # Convert to 8-bit for comparison
      dr = ((r1 >> 8).to_i32 - (r2 >> 8).to_i32).abs
      dg = ((g1 >> 8).to_i32 - (g2 >> 8).to_i32).abs
      db = ((b1 >> 8).to_i32 - (b2 >> 8).to_i32).abs
      da = ((a1 >> 8).to_i32 - (a2 >> 8).to_i32).abs

      dr <= tolerance && dg <= tolerance && db <= tolerance && da <= tolerance
    end
  end
end

module CrImage
  class RGBA
    # Performs flood fill starting from a point.
    def flood_fill(x : Int32, y : Int32, fill_color : Color::Color, tolerance : Int32 = 10) : Int32
      Util::Selection.flood_fill(self, x, y, fill_color, tolerance)
    end
  end

  module Image
    # Creates a selection mask based on color similarity.
    def select_by_color(x : Int32, y : Int32, tolerance : Int32 = 10, contiguous : Bool = true) : Gray
      Util::Selection.select_by_color(self, x, y, tolerance, contiguous)
    end

    # Replaces all pixels of one color with another.
    def replace_color(target_color : Color::Color, replacement_color : Color::Color, tolerance : Int32 = 10) : RGBA
      Util::Selection.replace_color(self, target_color, replacement_color, tolerance)
    end
  end
end
