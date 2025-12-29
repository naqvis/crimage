module CrImage
  # A Point represents an (x, y) coordinate on the integer grid.
  #
  # Coordinate system:
  # - X-axis increases to the right
  # - Y-axis increases downward
  # - A Point is neither a pixel nor a grid square
  # - A Point has no intrinsic width, height, or color
  #
  # Example:
  # ```
  # p1 = CrImage::Point.new(10, 20)
  # p2 = CrImage.point(30, 40) # Factory method
  # p3 = p1 + p2               # Point arithmetic
  # ```
  struct Point
    property x : Int32
    property y : Int32

    def initialize(@x, @y)
    end

    # Create Point from tuple
    def self.from(tuple : {Int32, Int32}) : Point
      new(tuple[0], tuple[1])
    end

    # Allow implicit conversion from tuple
    def self.new(tuple : {Int32, Int32}) : Point
      new(tuple[0], tuple[1])
    end

    def to_s(io : IO) : Nil
      io << "(#{x},#{y})"
    end

    def +(o : Point)
      Point.new(x + o.x, y + o.y)
    end

    def -(o : Point)
      Point.new(x - o.x, y - o.y)
    end

    def *(o : Point)
      Point.new(x * o.x, y * o.y)
    end

    def /(o : Point)
      Point.new(x // o.x, y // o.y)
    end

    # Reports whether this point is inside the given rectangle.
    #
    # A point is considered inside if it satisfies:
    # - `r.min.x <= x < r.max.x`
    # - `r.min.y <= y < r.max.y`
    #
    # Note: The max bounds are exclusive.
    def in(r : Rectangle) : Bool
      r.min.x <= x && x < r.max.x &&
        r.min.y <= y && y < r.max.y
    end

    # Returns the point q in Rectangle r such that p.x - q.x is a multiple
    # of r's width and p.y - q.y is a multiple of r's height.
    #
    # This is useful for wrapping coordinates within a rectangular region,
    # similar to modulo arithmetic but for 2D coordinates.
    def mod(r : Rectangle) : Point
      w, h = r.width, r.height
      p = self - r.min
      p.x = p.x % w
      p.x += w if p.x < 0
      p.y = p.y % h
      p.y += h if p.y < 0
      p + r.min
    end

    def eq(o : Point)
      self == o
    end

    def self.zero
      Point.new(0, 0)
    end
  end

  # A Rectangle is an axis-aligned rectangle on the integer grid.
  #
  # Defined by two points:
  # - `min` : Top-left corner (inclusive)
  # - `max` : Bottom-right corner (exclusive)
  #
  # Properties:
  # - A Rectangle has no intrinsic color
  # - Adding a Point translates the Rectangle
  # - Rectangles can exist in any quadrant (not restricted to bottom-right)
  # - Intersecting two Rectangles yields another Rectangle (possibly empty)
  # - Passed and returned by value for efficiency
  #
  # Example:
  # ```
  # r = CrImage.rect(10, 20, 100, 200) # x0, y0, x1, y1
  # r2 = r + CrImage.point(50, 50)     # Translate
  # intersection = r.intersect(r2)
  # ```
  struct Rectangle
    property min : Point
    property max : Point

    def initialize(@min, @max)
    end

    def to_s(io : IO) : Nil
      io << "#{min} - #{max}"
    end

    def width
      max.x - min.x
    end

    def height
      max.y - min.y
    end

    # size returns width and height
    def size : Point
      Point.new(max.x - min.x, max.y - min.y)
    end

    def +(p : Point)
      Rectangle.new(
        Point.new(min.x + p.x, min.y + p.y),
        Point.new(max.x + p.x, max.y + p.y)
      )
    end

    def -(p : Point)
      Rectangle.new(
        Point.new(min.x - p.x, min.y - p.y),
        Point.new(max.x - p.x, max.y - p.y)
      )
    end

    # Returns a rectangle inset by n pixels on all sides.
    #
    # The parameter n can be:
    # - Positive: Shrinks the rectangle inward
    # - Negative: Expands the rectangle outward
    #
    # If either dimension is less than 2*n, returns an empty rectangle
    # near the center of the original.
    #
    # Example:
    # ```
    # r = CrImage.rect(10, 10, 100, 100)
    # inner = r.inset(5)  # Shrink by 5 pixels on each side
    # outer = r.inset(-5) # Expand by 5 pixels on each side
    # ```
    def inset(n : Int32)
      new_min_x = min.x
      new_min_y = min.y
      new_max_x = max.x
      new_max_y = max.y

      if width < 2 * n
        new_min_x = (min.x + max.x) // 2
        new_max_x = new_min_x
      else
        new_min_x += n
        new_max_x -= n
      end
      if height < 2 * n
        new_min_y = (min.y + max.y) // 2
        new_max_y = new_min_y
      else
        new_min_y += n
        new_max_y -= n
      end
      Rectangle.new(Point.new(new_min_x, new_min_y), Point.new(new_max_x, new_max_y))
    end

    # Returns the largest rectangle contained by both this and s.
    #
    # If the two rectangles do not overlap, returns a zero rectangle.
    # This is useful for clipping operations.
    #
    # Example:
    # ```
    # r1 = CrImage.rect(0, 0, 100, 100)
    # r2 = CrImage.rect(50, 50, 150, 150)
    # overlap = r1.intersect(r2) # rect(50, 50, 100, 100)
    # ```
    def intersect(s : Rectangle)
      min.x = s.min.x if min.x < s.min.x
      min.y = s.min.y if min.y < s.min.y

      max.x = s.max.x if max.x > s.max.x
      max.y = s.max.y if max.y > s.max.y

      return Rectangle.zero if empty
      Rectangle.new(min, max)
    end

    def self.zero
      Rectangle.new(Point.zero, Point.zero)
    end

    # Returns the smallest rectangle that contains both this and s.
    #
    # This is the bounding box of the two rectangles.
    #
    # Example:
    # ```
    # r1 = CrImage.rect(0, 0, 50, 50)
    # r2 = CrImage.rect(100, 100, 150, 150)
    # bounding = r1.union(r2) # rect(0, 0, 150, 150)
    # ```
    def union(s : Rectangle) : Rectangle
      return s if empty
      return self if s.empty

      min.x = s.min.x if min.x > s.min.x
      min.y = s.min.y if min.y > s.min.y

      max.x = s.max.x if max.x < s.max.x
      max.y = s.max.y if max.y < s.max.y

      Rectangle.new(min, max)
    end

    # Reports whether the rectangle contains no points.
    #
    # A rectangle is empty if min.x >= max.x or min.y >= max.y.
    def empty
      min.x >= max.x || min.y >= max.y
    end

    # Reports whether this and Rectangle s contain the same set of points.
    #
    # All empty rectangles are considered equal.
    def eq(s : Rectangle)
      self == s || self.empty && s.empty
    end

    # Reports whether this and s have a non-empty intersection.
    #
    # Returns true if the rectangles overlap in any way.
    def overlaps(s : Rectangle)
      !self.empty && !s.empty &&
        min.x < s.max.x && s.min.x < max.x &&
        min.y < s.max.y && s.min.y < max.y
    end

    # Reports whether every point in this rectangle is contained in s.
    #
    # Note: max is an exclusive bound, so self.in(s) does not require
    # that self.max.in(s).
    def in(s : Rectangle)
      return true if empty()
      # note that max is an exclusive bound for this, so that self.in(s)
      # does not require that self.max.in(s)
      s.min.x <= min.x && max.x <= s.max.x &&
        s.min.y <= min.y && max.y <= s.max.y
    end

    # Returns the canonical (well-formed) version of this rectangle.
    #
    # Swaps minimum and maximum coordinates if necessary to ensure min < max.
    # This is useful when creating rectangles from user input where the order
    # of coordinates might be reversed.
    def canon
      if max.x < min.x
        min.x, max.x = max.x, min.x
      end
      if max.y < min.y
        min.y, max.y = max.y, min.y
      end
      self
    end

    # at implements the Image module
    def at(x : Int32, y : Int32) : Color::Color
      if Point.new(x, y).in(self)
        Color::OPAQUE
      else
        Color::TRANSPARENT
      end
    end

    # bounds implements the Image module
    def bounds : Rectangle
      self
    end

    def clone : Rectangle
      Rectangle.new(min, max)
    end

    def to_s
      "#{min}-#{max}"
    end
  end

  # Creates a Rectangle from coordinate pairs.
  #
  # Convenience factory method that automatically ensures the rectangle is well-formed
  # by swapping coordinates if necessary (min < max).
  #
  # Parameters:
  # - `x0` : Left edge x-coordinate
  # - `y0` : Top edge y-coordinate
  # - `x1` : Right edge x-coordinate
  # - `y1` : Bottom edge y-coordinate
  #
  # Returns: A well-formed Rectangle
  #
  # Example:
  # ```
  # r = CrImage.rect(10, 20, 100, 200)
  # # Creates Rectangle from (10,20) to (100,200)
  #
  # # Coordinates are automatically swapped if needed
  # r2 = CrImage.rect(100, 200, 10, 20) # Same as above
  # ```
  def self.rect(x0 : Int32, y0 : Int32, x1 : Int32, y1 : Int32) : Rectangle
    x0, x1 = x1, x0 if x0 > x1
    y0, y1 = y1, y0 if y0 > y1
    Rectangle.new(Point.new(x0, y0), Point.new(x1, y1))
  end
end
