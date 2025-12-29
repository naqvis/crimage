require "./spec_helper"

module CrImage
  describe "Advanced Geometry Tests" do
    describe "Point" do
      it "creates point with coordinates" do
        p = Point.new(5, 10)
        p.x.should eq(5)
        p.y.should eq(10)
      end

      it "adds points" do
        p1 = Point.new(3, 4)
        p2 = Point.new(1, 2)
        result = p1 + p2
        result.x.should eq(4)
        result.y.should eq(6)
      end

      it "subtracts points" do
        p1 = Point.new(5, 8)
        p2 = Point.new(2, 3)
        result = p1 - p2
        result.x.should eq(3)
        result.y.should eq(5)
      end

      it "multiplies points" do
        p1 = Point.new(3, 4)
        p2 = Point.new(2, 5)
        result = p1 * p2
        result.x.should eq(6)
        result.y.should eq(20)
      end

      it "divides points" do
        p1 = Point.new(10, 20)
        p2 = Point.new(2, 4)
        result = p1 / p2
        result.x.should eq(5)
        result.y.should eq(5)
      end

      it "checks if point is in rectangle" do
        r = CrImage.rect(0, 0, 10, 10)
        Point.new(5, 5).in(r).should be_true
        Point.new(0, 0).in(r).should be_true
        Point.new(9, 9).in(r).should be_true
        Point.new(10, 10).in(r).should be_false
        Point.new(-1, 5).in(r).should be_false
      end

      it "calculates modulo with rectangle" do
        r = CrImage.rect(0, 0, 10, 10)
        p = Point.new(15, 23)
        result = p.mod(r)
        result.x.should eq(5)
        result.y.should eq(3)
      end

      it "checks equality" do
        p1 = Point.new(5, 10)
        p2 = Point.new(5, 10)
        p3 = Point.new(3, 7)
        p1.eq(p2).should be_true
        p1.eq(p3).should be_false
      end

      it "creates zero point" do
        p = Point.zero
        p.x.should eq(0)
        p.y.should eq(0)
      end

      it "converts to string" do
        p = Point.new(5, 10)
        p.to_s.should eq("(5,10)")
      end
    end

    describe "Rectangle" do
      it "calculates width and height" do
        r = CrImage.rect(2, 3, 12, 13)
        r.width.should eq(10)
        r.height.should eq(10)
      end

      it "returns size as point" do
        r = CrImage.rect(0, 0, 10, 20)
        size = r.size
        size.x.should eq(10)
        size.y.should eq(20)
      end

      it "adds point to rectangle" do
        r = CrImage.rect(0, 0, 10, 10)
        p = Point.new(5, 5)
        result = r + p
        result.min.x.should eq(5)
        result.min.y.should eq(5)
        result.max.x.should eq(15)
        result.max.y.should eq(15)
      end

      it "subtracts point from rectangle" do
        r = CrImage.rect(5, 5, 15, 15)
        p = Point.new(2, 3)
        result = r - p
        result.min.x.should eq(3)
        result.min.y.should eq(2)
        result.max.x.should eq(13)
        result.max.y.should eq(12)
      end

      it "insets rectangle" do
        r = CrImage.rect(0, 0, 10, 10)
        result = r.inset(2)
        result.min.x.should eq(2)
        result.min.y.should eq(2)
        result.max.x.should eq(8)
        result.max.y.should eq(8)
      end

      it "insets rectangle with large value returns center" do
        r = CrImage.rect(0, 0, 10, 10)
        result = r.inset(10)
        result.min.x.should eq(5)
        result.max.x.should eq(5)
      end

      it "intersects rectangles" do
        r1 = CrImage.rect(0, 0, 10, 10)
        r2 = CrImage.rect(5, 5, 15, 15)
        result = r1.intersect(r2)
        result.min.x.should eq(5)
        result.min.y.should eq(5)
        result.max.x.should eq(10)
        result.max.y.should eq(10)
      end

      it "intersects non-overlapping rectangles returns zero" do
        r1 = CrImage.rect(0, 0, 5, 5)
        r2 = CrImage.rect(10, 10, 15, 15)
        result = r1.intersect(r2)
        result.should eq(Rectangle.zero)
      end

      it "unions rectangles" do
        r1 = CrImage.rect(0, 0, 5, 5)
        r2 = CrImage.rect(3, 3, 8, 8)
        result = r1.union(r2)
        result.min.x.should eq(0)
        result.min.y.should eq(0)
        result.max.x.should eq(8)
        result.max.y.should eq(8)
      end

      it "union with empty rectangle returns non-empty" do
        r1 = CrImage.rect(0, 0, 10, 10)
        r2 = Rectangle.zero
        result = r1.union(r2)
        result.should eq(r1)
      end

      it "checks if rectangle is empty" do
        CrImage.rect(0, 0, 10, 10).empty.should be_false
        CrImage.rect(5, 5, 5, 5).empty.should be_true
        Rectangle.new(Point.new(10, 10), Point.new(5, 5)).empty.should be_true
      end

      it "checks rectangle equality" do
        r1 = CrImage.rect(0, 0, 10, 10)
        r2 = CrImage.rect(0, 0, 10, 10)
        r3 = CrImage.rect(1, 1, 10, 10)
        r1.eq(r2).should be_true
        r1.eq(r3).should be_false
      end

      it "empty rectangles are equal" do
        r1 = CrImage.rect(5, 5, 5, 5)
        r2 = CrImage.rect(10, 10, 10, 10)
        r1.eq(r2).should be_true
      end

      it "checks if rectangles overlap" do
        r1 = CrImage.rect(0, 0, 10, 10)
        r2 = CrImage.rect(5, 5, 15, 15)
        r3 = CrImage.rect(20, 20, 30, 30)
        r1.overlaps(r2).should be_true
        r1.overlaps(r3).should be_false
      end

      it "checks if rectangle is in another" do
        r1 = CrImage.rect(2, 2, 8, 8)
        r2 = CrImage.rect(0, 0, 10, 10)
        r3 = CrImage.rect(5, 5, 15, 15)
        r1.in(r2).should be_true
        r1.in(r3).should be_false
      end

      it "empty rectangle is in any rectangle" do
        r1 = CrImage.rect(5, 5, 5, 5)
        r2 = CrImage.rect(0, 0, 10, 10)
        r1.in(r2).should be_true
      end

      it "canonicalizes rectangle" do
        r = Rectangle.new(Point.new(10, 10), Point.new(0, 0))
        result = r.canon
        result.min.x.should eq(0)
        result.min.y.should eq(0)
        result.max.x.should eq(10)
        result.max.y.should eq(10)
      end

      it "implements at method" do
        r = CrImage.rect(0, 0, 10, 10)
        color = r.at(5, 5)
        color.should eq(Color::OPAQUE)
      end

      it "at returns transparent outside bounds" do
        r = CrImage.rect(0, 0, 10, 10)
        color = r.at(15, 15)
        color.should eq(Color::TRANSPARENT)
      end

      it "returns bounds" do
        r = CrImage.rect(0, 0, 10, 10)
        r.bounds.should eq(r)
      end

      it "clones rectangle" do
        r1 = CrImage.rect(0, 0, 10, 10)
        r2 = r1.clone
        r2.should eq(r1)
      end

      it "converts to string" do
        r = CrImage.rect(0, 0, 10, 10)
        r.to_s.should contain("(0,0)")
        r.to_s.should contain("(10,10)")
      end

      it "creates zero rectangle" do
        r = Rectangle.zero
        r.min.should eq(Point.zero)
        r.max.should eq(Point.zero)
        r.empty.should be_true
      end
    end

    describe "rect helper" do
      it "creates well-formed rectangle" do
        r = CrImage.rect(0, 0, 10, 10)
        r.min.x.should eq(0)
        r.min.y.should eq(0)
        r.max.x.should eq(10)
        r.max.y.should eq(10)
      end

      it "swaps coordinates if needed" do
        r = CrImage.rect(10, 10, 0, 0)
        r.min.x.should eq(0)
        r.min.y.should eq(0)
        r.max.x.should eq(10)
        r.max.y.should eq(10)
      end
    end
  end
end
