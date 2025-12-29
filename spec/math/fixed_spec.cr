require "../spec_helper"

module CrImage::Math::Fixed
  describe "Int26_6 Tests" do
    it "creates from integer" do
      val = Int26_6[64]
      val.floor.should eq(1)
    end

    it "performs addition" do
      a = Int26_6[64]  # 1.0
      b = Int26_6[128] # 2.0
      c = a + b
      c.floor.should eq(3)
    end

    it "performs subtraction" do
      a = Int26_6[128] # 2.0
      b = Int26_6[64]  # 1.0
      c = a - b
      c.floor.should eq(1)
    end

    it "performs multiplication" do
      a = Int26_6[64]  # 1.0
      b = Int26_6[128] # 2.0
      c = a * b
      c.floor.should eq(2)
    end

    it "performs division" do
      a = Int26_6[128] # 2.0
      b = 2
      c = a / b
      c.floor.should eq(1)
    end

    it "floors correctly" do
      Int26_6[64].floor.should eq(1)
      Int26_6[96].floor.should eq(1)
      Int26_6[127].floor.should eq(1)
      Int26_6[128].floor.should eq(2)
    end

    it "rounds correctly" do
      Int26_6[64].round.should eq(1)
      Int26_6[96].round.should eq(2)
      Int26_6[32].round.should eq(1)
    end

    it "ceils correctly" do
      Int26_6[64].ceil.should eq(1)
      Int26_6[65].ceil.should eq(2)
      Int26_6[127].ceil.should eq(2)
    end

    it "compares values" do
      a = Int26_6[64]
      b = Int26_6[128]

      (a < b).should be_true
      (b > a).should be_true
      (a == a).should be_true
      (a <= b).should be_true
      (b >= a).should be_true
    end

    it "negates values" do
      a = Int26_6[64]
      b = -a
      b.floor.should eq(-1)
    end

    it "converts to string" do
      Int26_6[64].to_s.should eq("1:00")
      Int26_6[80].to_s.should eq("1:16")
    end
  end

  describe "Int52_12 Tests" do
    it "creates from integer" do
      val = Int52_12[4096]
      val.floor.should eq(1)
    end

    it "performs addition" do
      a = Int52_12[4096] # 1.0
      b = Int52_12[8192] # 2.0
      c = a + b
      c.floor.should eq(3)
    end

    it "performs subtraction" do
      a = Int52_12[8192] # 2.0
      b = Int52_12[4096] # 1.0
      c = a - b
      c.floor.should eq(1)
    end

    it "performs multiplication" do
      a = Int52_12[4096] # 1.0
      b = Int52_12[8192] # 2.0
      c = a * b
      c.floor.should eq(2)
    end

    it "floors correctly" do
      Int52_12[4096].floor.should eq(1)
      Int52_12[6144].floor.should eq(1)
      Int52_12[8192].floor.should eq(2)
    end

    it "rounds correctly" do
      Int52_12[4096].round.should eq(1)
      Int52_12[6144].round.should eq(2)
      Int52_12[2048].round.should eq(1)
    end

    it "ceils correctly" do
      Int52_12[4096].ceil.should eq(1)
      Int52_12[4097].ceil.should eq(2)
    end

    it "compares values" do
      a = Int52_12[4096]
      b = Int52_12[8192]

      (a < b).should be_true
      (b > a).should be_true
      (a == a).should be_true
    end
  end

  describe "Point26_6 Tests" do
    it "creates point" do
      p = Point26_6.new(Int26_6[64], Int26_6[128])
      p.x.floor.should eq(1)
      p.y.floor.should eq(2)
    end

    it "adds points" do
      p1 = Point26_6.new(Int26_6[64], Int26_6[64])
      p2 = Point26_6.new(Int26_6[128], Int26_6[128])
      p3 = p1 + p2

      p3.x.floor.should eq(3)
      p3.y.floor.should eq(3)
    end

    it "subtracts points" do
      p1 = Point26_6.new(Int26_6[128], Int26_6[128])
      p2 = Point26_6.new(Int26_6[64], Int26_6[64])
      p3 = p1 - p2

      p3.x.floor.should eq(1)
      p3.y.floor.should eq(1)
    end

    it "checks if point is in rectangle" do
      rect = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[640])
      )

      p1 = Point26_6.new(Int26_6[320], Int26_6[320])
      p1.in(rect).should be_true

      p2 = Point26_6.new(Int26_6[1000], Int26_6[1000])
      p2.in(rect).should be_false
    end

    it "creates zero point" do
      p = Point26_6.zero
      p.x.floor.should eq(0)
      p.y.floor.should eq(0)
    end
  end

  describe "Rectangle26_6 Tests" do
    it "creates rectangle" do
      rect = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[480])
      )

      rect.width.floor.should eq(10)
      rect.height.floor.should eq(7)
    end

    it "checks if empty" do
      rect1 = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[640])
      )
      rect1.empty.should be_false

      rect2 = Rectangle26_6.new(
        Point26_6.new(Int26_6[640], Int26_6[640]),
        Point26_6.new(Int26_6[0], Int26_6[0])
      )
      rect2.empty.should be_true
    end

    it "intersects rectangles" do
      rect1 = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[640])
      )

      rect2 = Rectangle26_6.new(
        Point26_6.new(Int26_6[320], Int26_6[320]),
        Point26_6.new(Int26_6[960], Int26_6[960])
      )

      intersection = rect1.intersect(rect2)
      intersection.empty.should be_false
    end

    it "unions rectangles" do
      rect1 = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[640])
      )

      rect2 = Rectangle26_6.new(
        Point26_6.new(Int26_6[320], Int26_6[320]),
        Point26_6.new(Int26_6[960], Int26_6[960])
      )

      union = rect1.union(rect2)
      union.empty.should be_false
    end

    it "translates rectangle" do
      rect = Rectangle26_6.new(
        Point26_6.new(Int26_6[0], Int26_6[0]),
        Point26_6.new(Int26_6[640], Int26_6[640])
      )

      offset = Point26_6.new(Int26_6[64], Int26_6[64])
      translated = rect + offset

      translated.min.x.floor.should eq(1)
      translated.min.y.floor.should eq(1)
    end
  end

  describe "Point52_12 Tests" do
    it "creates point" do
      p = Point52_12.new(Int52_12[4096], Int52_12[8192])
      p.x.floor.should eq(1)
      p.y.floor.should eq(2)
    end

    it "adds points" do
      p1 = Point52_12.new(Int52_12[4096], Int52_12[4096])
      p2 = Point52_12.new(Int52_12[8192], Int52_12[8192])
      p3 = p1 + p2

      p3.x.floor.should eq(3)
      p3.y.floor.should eq(3)
    end
  end

  describe "Rectangle52_12 Tests" do
    it "creates rectangle" do
      rect = Rectangle52_12.new(
        Point52_12.new(Int52_12[0], Int52_12[0]),
        Point52_12.new(Int52_12[40960], Int52_12[40960])
      )

      rect.width.floor.should eq(10)
      rect.height.floor.should eq(10)
    end

    it "checks if empty" do
      rect1 = Rectangle52_12.new(
        Point52_12.new(Int52_12[0], Int52_12[0]),
        Point52_12.new(Int52_12[4096], Int52_12[4096])
      )
      rect1.empty.should be_false

      rect2 = Rectangle52_12.new(
        Point52_12.new(Int52_12[4096], Int52_12[4096]),
        Point52_12.new(Int52_12[0], Int52_12[0])
      )
      rect2.empty.should be_true
    end
  end
end
