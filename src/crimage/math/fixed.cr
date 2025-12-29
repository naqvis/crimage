# CrImage::Math::Fixed provides fixed-point arithmetic for precise positioning.
#
# Fixed-point numbers are used in font rendering and graphics operations
# where sub-pixel precision is needed without floating-point overhead.
module CrImage::Math::Fixed
  # Int26_6 is a signed 26.6 fixed-point number.
  #
  # Format: 26 bits for integer part, 6 bits for fractional part
  # - Integer range: -33554432 to 33554431
  # - Fractional precision: 1/64 (0.015625)
  #
  # Used for sub-pixel positioning in font rendering and graphics.
  #
  # Example:
  # ```
  # # One and a quarter: 1 + 16/64 = 1.25
  # value = CrImage::Math::Fixed::Int26_6[1 << 6 + 1 << 4]
  # puts value.to_s # => "1:16"
  # ```
  struct Int26_6
    @val : Int32
    protected getter val
    private SHIFT = 6
    private MASK  = (1 << 6) - 1

    # Rounding constants for fixed-point arithmetic
    private ROUND_HALF = 0x20 # Half of 1<<6 for round-to-nearest
    private ROUND_CEIL = 0x3f # (1<<6)-1 for ceiling

    def self.[](value : Number)
      new(value.to_i)
    end

    # returns human-readable representation of 26.6 fixed-point number.
    # For example, the number one-and-a-quarter becomes "1:16".
    def to_s
      return sprintf("%d:%02d", @val >> SHIFT, @val & MASK) if @val >= 0
      x = -@val
      return sprintf("-%d:%02d", x >> SHIFT, x & MASK) if x >= 0
      "-33554432:00" # The minimum value is -(1<<25).
    end

    def to_s(io : IO) : Nil
      io << to_s
    end

    # returns the integer value i as in Int26_6
    def self.from_i(i : Int)
      Int26_6[i << 6]
    end

    def to_i
      val
    end

    # floor returns the greatest integer value less than or equal to @val.
    #
    # Its return is Int32, not Int26_6
    def floor : Int
      ((@val + 0x00) >> 6).to_i
    end

    # round returns the nearest integer value to @val.
    #
    # Its return is Int32, not Int26_6
    def round : Int
      ((@val + ROUND_HALF) >> 6).to_i
    end

    # ceil returns the least integer value less than or equal to @val.
    #
    # Its return is Int32, not Int26_6
    def ceil : Int
      ((@val + ROUND_CEIL) >> 6).to_i
    end

    def *(y : Int26_6)
      Int26_6[(@val.to_i64 * y.val.to_i64 + (1i64 << 5)) >> 6]
    end

    def *(y : Number)
      Int26_6[@val * y.to_i]
    end

    def +(y : self)
      Int26_6[@val + y.val]
    end

    def +(y : Number)
      Int26_6[@val + y.to_i]
    end

    def -(y : Int26_6)
      Int26_6[@val - y.val]
    end

    def -(y : Number)
      Int26_6[@val - y]
    end

    def *(y : Int32)
      Int26_6[@val * y]
    end

    def /(y : Int32)
      Int26_6[@val / y]
    end

    def -
      Int26_6[-@val]
    end

    def >(y : Int26_6)
      @val > y.val
    end

    def >=(y : Int26_6)
      @val >= y.val
    end

    def <(y : Int26_6)
      @val < y.val
    end

    def <=(y : Int26_6)
      @val <= y.val
    end

    def ==(y : Int26_6)
      @val == y.val
    end

    def ==(y : Number)
      @val == y
    end

    def //(y : Int26_6)
      Int26_6[@val // y.val]
    end

    def //(y : Number)
      Int26_6[@val // y]
    end

    def %(y : Int26_6)
      @val = @val % y.val
    end

    def %(y : Number)
      @val = @val % y
    end

    private def initialize(@val)
    end

    # forward_missing_to @val
  end

  # Int52_12 is a signed 52.12 fixed-point number.
  # The Integer part ranges from -2251799813685248 to 2251799813685247. The
  # fractional part has 12 bits of precision.
  #
  # For example, the number one-and-a-quarter is Int26_6[1<<12 + 1<<10].
  struct Int52_12
    @val : Int64
    protected getter val
    private SHIFT = 12i64
    private MASK  = (1i64 << 12i64) - 1i64

    # Rounding constants for fixed-point arithmetic
    private ROUND_HALF = 0x800_i64 # Half of 1<<12 for round-to-nearest
    private ROUND_CEIL = 0xfff_i64 # (1<<12)-1 for ceiling

    def self.[](value : Number)
      new(value.to_i64)
    end

    # returns human-readable representation of 52.12 fixed-point number.
    # For example, the number one-and-a-quarter becomes "1:1024".
    def to_s
      return sprintf("%d:%04d", @val >> SHIFT, @val & MASK) if @val >= 0
      x = -@val
      return sprintf("-%d:%04d", x >> SHIFT, x & MASK) if x >= 0
      "-2251799813685248:0000" # The minimum value is -(1i64<<51).
    end

    def to_s(io : IO) : Nil
      io << to_s
    end

    # returns the integer value i as in Int52_12
    def self.from_i(i : Int)
      Int52_12[i << 12]
    end

    def to_i
      val
    end

    # floor returns the greatest integer value less than or equal to @val.
    #
    # Its return is Int64, not Int52_12
    def floor : Int
      ((@val + 0x000) >> 12).to_i64
    end

    # round returns the nearest integer value to @val. Ties are rounded up.
    #
    # Its return is Int64, not Int52_12
    def round : Int
      ((@val + ROUND_HALF) >> 12).to_i64
    end

    # ceil returns the least integer value less than or equal to @val.
    #
    # Its return is Int64, not Int52_12
    def ceil : Int
      ((@val + ROUND_CEIL) >> 12).to_i64
    end

    def *(y : Int52_12)
      m, n = 52, 12
      lo, hi = Fixed.muli64(@val, y.val)
      ret = Int52_12[(hi << m) | (lo >> n)]
      ret += Int52_12[(lo >> (n - 1)) & 1] # Round to the nearest, instead of rounding down.
      ret
    end

    def *(y : Number)
      Int52_12[@val * y.to_i]
    end

    def +(y : Int52_12)
      Int52_12[@val + y.val]
    end

    def -(y : Int52_12)
      Int52_12[@val - y.val]
    end

    def >(y : Int52_12)
      @val > y.val
    end

    def >=(y : Int52_12)
      @val >= y.val
    end

    def <(y : Int52_12)
      @val < y.val
    end

    def <=(y : Int52_12)
      @val <= y.val
    end

    def ==(y : Int52_12)
      @val == y.val
    end

    def ==(y : Number)
      @val == y
    end

    private def initialize(@val)
    end

    forward_missing_to @val
  end

  # Point26_6 is a 26.6 fixed-point coordinate pair.
  # It is analogous to the `CrImage::Point`
  class Point26_6
    property x : Int26_6
    property y : Int26_6

    def initialize(@x = Int26_6[0], @y = Int26_6[0])
    end

    def self.new(x : Number, y : Number)
      new(Int26_6[x], Int26_6[y])
    end

    def to_s(io : IO) : Nil
      io << "(#{x},#{y})"
    end

    def +(o : Point26_6)
      Point26_6.new(x + o.x, y + o.y)
    end

    def -(o : Point26_6)
      Point26_6.new(x - o.x, y - o.y)
    end

    def *(o : Point26_6)
      Point26_6.new((x * o.x) // 64, (y * o.y) // 64)
    end

    def /(o : Point26_6)
      Point26_6.new((x * 64) // o.x, (y * 64) // o.y)
    end

    # reports whether point is in Rectangle r
    def in(r : Rectangle26_6) : Bool
      r.min.x <= x && x < r.max.x &&
        r.min.y <= y && y < r.max.y
    end

    def ==(o : Point26_6)
      self.x == o.x && self.y == o.y
    end

    def self.zero
      Point26_6.new(0, 0)
    end
  end

  # Point52_12 is a 52.12 fixed-point coordinate pair.
  # It is analogous to the `CrImage::Point`
  class Point52_12
    property x : Int52_12
    property y : Int52_12

    def initialize(@x, @y)
    end

    def self.new(x : Number, y : Number)
      new(Int52_12[x], Int52_12[y])
    end

    def to_s(io : IO) : Nil
      io << "(#{x},#{y})"
    end

    def +(o : Point52_12)
      Point52_12.new(x + o.x, y + o.y)
    end

    def -(o : Point52_12)
      Point52_12.new(x - o.x, y - o.y)
    end

    def *(o : Point52_12)
      Point52_12.new((x * o.x) // 4096, (y * o.y) // 4096)
    end

    def /(o : Point52_12)
      Point52_12.new((x * 4096) // o.x, (y * 4096) // o.y)
    end

    # reports whether point is in Rectangle r
    def in(r : Rectangle52_12) : Bool
      r.min.x <= x && x < r.max.x &&
        r.min.y <= y && y < r.max.y
    end

    def ==(o : Point52_12)
      self.x == o.x && self.y == o.y
    end

    def self.zero
      Point52_12.new(0, 0)
    end
  end

  # Rectangle26_6 is a 26.6 fixed-point coordinate retangle. The min bound is
  # inclusive and the max bound is exclusive. It is well-formed if min.x <= max.x and likewise for y.
  #
  # It is analogous to the `CrImage::Rectangle`
  struct Rectangle26_6
    property min : Point26_6
    property max : Point26_6

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

    def +(p : Point26_6)
      Rectangle26_6.new(
        Point26_6.new(min.x + p.x, min.y + p.y),
        Point26_6.new(max.x + p.x, max.y + p.y)
      )
    end

    def -(p : Point26_6)
      Rectangle26_6.new(
        Point26_6.new(min.x - p.x, min.y - p.y),
        Point26_6.new(max.x - p.x, max.y - p.y)
      )
    end

    # intersect return the largest rectangle contained by both self and s. If the
    # two rectangle do not overlap then the zero rectangle will be returned
    def intersect(s : Rectangle26_6)
      min.x = s.min.x if min.x < s.min.x
      min.y = s.min.y if min.y < s.min.y

      max.x = s.max.x if max.x > s.max.x
      max.y = s.max.y if max.y > s.max.y

      return Rectangle26_6.zero if empty
      Rectangle26_6.new(min, max)
    end

    # union returns the smalles rectangle that contains both self and s
    def union(s : Rectangle26_6) : Rectangle26_6
      return s if empty
      return self if s.empty

      min.x = s.min.x if min.x > s.min.x
      min.y = s.min.y if min.y > s.min.y

      max.x = s.max.x if max.x < s.max.x
      max.y = s.max.y if max.y < s.max.y

      Rectangle26_6.new(min, max)
    end

    # empty reports whether the rectangle contains no points
    def empty
      min.x >= max.x || min.y >= max.y
    end

    def self.zero
      Rectangle26_6.new(Point26_6.zero, Point26_6.zero)
    end

    # in reports whether every point in this is in s
    def in(s : Rectangle26_6)
      return true if empty()
      # note that max is an exclusive bound for this, so that self.in(s)
      # does not require that self.max.in(s)
      s.min.x <= min.x && max.x <= s.max.x &&
        s.min.y <= min.y && max.y <= s.max.y
    end

    # eq reports whether this and Rectangle s contain the same set of points. All empty
    # rectangles are considered equal.
    def eq(s : Rectangle26_6)
      self.min == s.min && self.max == s.max
    end

    def clone : Rectangle26_6
      Rectangle26_6.new(min, max)
    end

    def to_s
      "#{min}-#{max}"
    end
  end

  # Rectangle52_12 is a 52.12 fixed-point coordinate retangle. The min bound is
  # inclusive and the max bound is exclusive. It is well-formed if min.x <= max.x and likewise for y.
  #
  # It is analogous to the `CrImage::Rectangle`
  class Rectangle52_12
    property min : Point52_12
    property max : Point52_12

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

    def +(p : Point52_12)
      Rectangle52_12.new(
        Point52_12.new(min.x + p.x, min.y + p.y),
        Point52_12.new(max.x + p.x, max.y + p.y)
      )
    end

    def -(p : Point52_12)
      Rectangle52_12.new(
        Point52_12.new(min.x - p.x, min.y - p.y),
        Point52_12.new(max.x - p.x, max.y - p.y)
      )
    end

    # intersect return the largest rectangle contained by both self and s. If the
    # two rectangle do not overlap then the zero rectangle will be returned
    def intersect(s : Rectangle52_12)
      min.x = s.min.x if min.x < s.min.x
      min.y = s.min.y if min.y < s.min.y

      max.x = s.max.x if max.x > s.max.x
      max.y = s.max.y if max.y > s.max.y

      return Rectangle52_12.zero if empty
      Rectangle52_12.new(min, max)
    end

    # union returns the smalles rectangle that contains both self and s
    def union(s : Rectangle52_12) : Rectangle52_12
      return s if empty
      return self if s.empty

      min.x = s.min.x if min.x > s.min.x
      min.y = s.min.y if min.y > s.min.y

      max.x = s.max.x if max.x < s.max.x
      max.y = s.max.y if max.y < s.max.y

      Rectangle52_12.new(min, max)
    end

    # empty reports whether the rectangle contains no points
    def empty
      min.x >= max.x || min.y >= max.y
    end

    def self.zero
      Rectangle52_12.new(Point52_12.zero, Point52_12.zero)
    end

    # in reports whether every point in this is in s
    def in(s : Rectangle52_12)
      return true if empty()
      # note that max is an exclusive bound for this, so that self.in(s)
      # does not require that self.max.in(s)
      s.min.x <= min.x && max.x <= s.max.x &&
        s.min.y <= min.y && max.y <= s.max.y
    end

    # eq reports whether this and Rectangle s contain the same set of points. All empty
    # rectangles are considered equal.
    def eq(s : Rectangle52_12)
      self == s || self.empty && s.empty
    end

    def clone : Rectangle52_12
      Rectangle52_12.new(min, max)
    end

    def to_s
      "#{min}-#{max}"
    end
  end

  # r returns the integer values min_x, min_y, max_x, max_y as Rectangle26_6.
  #
  # For example, passing the integer values (0,1,2,3) yields
  # Rectangle26_6(Point26_6(0,64), Point26_6(128,192)).
  #
  # Like the `CrImage.rect` function, the returned rectangle has
  # minimum and maximum coordinates swapped if necessary so that it is
  # well-formed
  def self.r(min_x, min_y, max_x, max_y) : Rectangle26_6
    if min_x > max_x
      min_x, max_x = max_x, min_x
    end
    if min_y > max_y
      min_y, max_y = max_y, min_y
    end

    Rectangle26_6.new(Point26_6.new(Int26_16[min_x << 6], Int26_16[min_y << 6]),
      Point26_6.new(Int26_16[max_x << 6], Int26_16[max_y << 6]))
  end

  protected def self.muli64(u : Int64, v : Int64)
    s = 32
    mask = (1i64 << s) - 1

    u1 = (u >> s).to_u64!
    u0 = (u & mask).to_u64
    v1 = (v >> s).to_u64!
    v0 = (v & mask).to_u64

    w0 = u0 * v0
    t = u1 &* v0 &+ (w0 >> s)
    w1 = t & mask
    w2 = (t.to_u64 >> s).to_u64
    w1 += u0 * v1
    {u.to_u64! &* v.to_u64!, u1 &* v1 &+ w2 &+ (w1.to_i64 >> s).to_u64!}
  end

  # p returns the integer values x and y as a Point26_6.
  # For example, passing the interger values(2,-3) yields Point26_6(128,-192)
  def self.p(x : Int32, y : Int32)
    Point26_6.new(Int26_6[x << 6], Int26_6[y << 6])
  end
end
