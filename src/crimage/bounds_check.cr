module CrImage
  # BoundsCheck provides common bounds checking and clipping operations
  # to reduce code duplication across draw operations
  module BoundsCheck
    # Clip a rectangle to image bounds
    def self.clip_rect(rect : Rectangle, bounds : Rectangle) : Rectangle
      rect.intersect(bounds)
    end

    # Check if a point is within bounds
    def self.in_bounds?(x : Int32, y : Int32, bounds : Rectangle) : Bool
      x >= bounds.min.x && x < bounds.max.x && y >= bounds.min.y && y < bounds.max.y
    end

    # Check if a point is within bounds
    def self.in_bounds?(point : Point, bounds : Rectangle) : Bool
      point.in(bounds)
    end

    # Clip a line to rectangle bounds using Cohen-Sutherland algorithm
    # Returns nil if line is completely outside, otherwise returns clipped coordinates
    def self.clip_line(x0 : Int32, y0 : Int32, x1 : Int32, y1 : Int32, bounds : Rectangle) : Tuple(Int32, Int32, Int32, Int32)?
      # Cohen-Sutherland region codes
      inside = 0 # 0000
      left = 1   # 0001
      right = 2  # 0010
      bottom = 4 # 0100
      top = 8    # 1000

      compute_code = ->(x : Int32, y : Int32) {
        code = inside
        code |= left if x < bounds.min.x
        code |= right if x >= bounds.max.x
        code |= bottom if y < bounds.min.y
        code |= top if y >= bounds.max.y
        code
      }

      code0 = compute_code.call(x0, y0)
      code1 = compute_code.call(x1, y1)

      loop do
        # Both endpoints inside
        return {x0, y0, x1, y1} if (code0 | code1) == 0

        # Both endpoints in same outside region
        return nil if (code0 & code1) != 0

        # Pick an endpoint outside the clip rectangle
        code_out = code0 != 0 ? code0 : code1

        # Find intersection point
        if (code_out & top) != 0
          x = x0 + (x1 - x0) * (bounds.max.y - 1 - y0) // (y1 - y0)
          y = bounds.max.y - 1
        elsif (code_out & bottom) != 0
          x = x0 + (x1 - x0) * (bounds.min.y - y0) // (y1 - y0)
          y = bounds.min.y
        elsif (code_out & right) != 0
          y = y0 + (y1 - y0) * (bounds.max.x - 1 - x0) // (x1 - x0)
          x = bounds.max.x - 1
        else # left
          y = y0 + (y1 - y0) * (bounds.min.x - x0) // (x1 - x0)
          x = bounds.min.x
        end

        # Update the point and code
        if code_out == code0
          x0, y0 = x, y
          code0 = compute_code.call(x0, y0)
        else
          x1, y1 = x, y
          code1 = compute_code.call(x1, y1)
        end
      end
    end

    # Validate that a rectangle is within bounds, raise error if not
    def self.validate_rect!(rect : Rectangle, bounds : Rectangle)
      unless rect.in(bounds)
        raise BoundsError.new("Rectangle #{rect} is outside bounds #{bounds}")
      end
    end

    # Get the overlapping region between two rectangles
    def self.overlap(r1 : Rectangle, r2 : Rectangle) : Rectangle?
      result = r1.intersect(r2)
      result.empty ? nil : result
    end

    # Clamp a value to a range
    def self.clamp(value : Int32, min : Int32, max : Int32) : Int32
      return min if value < min
      return max if value > max
      value
    end

    # Clamp coordinates to bounds
    def self.clamp_point(x : Int32, y : Int32, bounds : Rectangle) : Tuple(Int32, Int32)
      {
        clamp(x, bounds.min.x, bounds.max.x - 1),
        clamp(y, bounds.min.y, bounds.max.y - 1),
      }
    end

    # Clamp color value to 0-255 range
    def self.clamp_u8(value : Int32 | Float64) : UInt8
      value.clamp(0, 255).to_u8
    end
  end
end
