require "./spec_helper"

module CrImage
  private def self.test_in(f : Rectangle, g : Rectangle)
    return false if !f.in(g)
    y = f.min.y
    while y < f.max.y
      x = f.min.x
      while x < f.max.x
        p = Point.new(x, y)
        return false if !p.in(g)
        x += 1
      end
      y += 1
    end
    true
  end

  describe "Geometry Tests" do
    it "Test Rectangle" do
      rects = [
        CrImage.rect(0, 0, 10, 10),
        CrImage.rect(10, 0, 20, 10),
        CrImage.rect(1, 2, 3, 4),
        CrImage.rect(4, 6, 10, 10),
        CrImage.rect(2, 3, 12, 5),
        CrImage.rect(-1, -2, 0, 0),
        CrImage.rect(-1, -2, 4, 6),
        CrImage.rect(-10, -20, 30, 40),
        CrImage.rect(8, 8, 8, 8),
        CrImage.rect(88, 88, 88, 88),
        CrImage.rect(6, 5, 4, 3),
      ]

      # r.eq(s) should be equivalent to every point in r being in s, and every
      # point in s being in r.
      rects.each do |r|
        rects.each do |s|
          got = r.eq(s)
          want = test_in(r, s) && test_in(s, r)
          got.should eq(want)
        end
      end

      # The intersection should be the largest rectangle a such that every point
      # in a is both in r and in s.
      rects.each do |r|
        rects.each do |s|
          a = r.intersect(s)
          if !test_in(a, r)
            fail "intersect: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, a not in r"
          end
          if !test_in(a, s)
            fail "intersect: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, a not in s"
          end

          is_zero = a == Rectangle.zero
          overlaps = r.overlaps(s)

          fail "intersect: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, is_zero=#{is_zero} same as overlaps=#{overlaps}" if is_zero == overlaps

          larger_than_a = [a, a, a, a]
          larger_than_a.each_with_index do |b, i|
            larger_than_a[i] = Rectangle.new(Point.new(b.min.x - 1, b.min.y), b.max) if i == 0
            larger_than_a[i] = Rectangle.new(Point.new(b.min.x, b.min.y - 1), b.max) if i == 1
            larger_than_a[i] = Rectangle.new(b.min, Point.new(b.max.x + 1, b.max.y)) if i == 2
            larger_than_a[i] = Rectangle.new(b.min, Point.new(b.max.x, b.max.y + 1)) if i == 3
          end

          larger_than_a.each_with_index do |b, i|
            next if b.empty

            if test_in(b, r) && test_in(b, s)
              fail "intersect: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, b=#{b.to_s}, i=#{i}: intersection could be larger"
            end
          end
        end
      end

      # The union should be the smallest rectangle a such that every point in r is in a
      # and every point in s is in a
      rects.each do |r|
        rects.each do |s|
          a = r.union(s)
          if !test_in(r, a)
            fail "union: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, r not in a"
          end
          if !test_in(s, a)
            fail "union: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, s not in a"
          end
          # You can't get any smaller than a
          next if a.empty

          smaller_than_a = [a, a, a, a]
          smaller_than_a.each_with_index do |b, i|
            smaller_than_a[i] = Rectangle.new(Point.new(b.min.x + 1, b.min.y), b.max) if i == 0
            smaller_than_a[i] = Rectangle.new(Point.new(b.min.x, b.min.y + 1), b.max) if i == 1
            smaller_than_a[i] = Rectangle.new(b.min, Point.new(b.max.x - 1, b.max.y)) if i == 2
            smaller_than_a[i] = Rectangle.new(b.min, Point.new(b.max.x, b.max.y - 1)) if i == 3
          end

          smaller_than_a.each_with_index do |b, i|
            next if b.empty

            if test_in(r, b) && test_in(s, b)
              fail "union: r=#{r.to_s}, s=#{s.to_s}, a=#{a.to_s}, b=#{b.to_s}, i=#{i}: union could be smaller"
            end
          end
        end
      end
    end
  end
end
