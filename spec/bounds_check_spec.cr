require "./spec_helper"

describe CrImage::BoundsCheck do
  describe ".in_bounds?" do
    it "returns true when point is inside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      CrImage::BoundsCheck.in_bounds?(50, 50, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(0, 0, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(99, 99, bounds).should be_true
    end

    it "returns false when point is outside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      CrImage::BoundsCheck.in_bounds?(-1, 50, bounds).should be_false
      CrImage::BoundsCheck.in_bounds?(50, -1, bounds).should be_false
      CrImage::BoundsCheck.in_bounds?(100, 50, bounds).should be_false
      CrImage::BoundsCheck.in_bounds?(50, 100, bounds).should be_false
    end

    it "works with Point" do
      bounds = CrImage.rect(10, 10, 50, 50)
      CrImage::BoundsCheck.in_bounds?(CrImage.point(20, 20), bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(CrImage.point(5, 20), bounds).should be_false
    end
  end

  describe ".clip_rect" do
    it "returns intersection of rectangles" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(50, 50, 150, 150)
      clipped = CrImage::BoundsCheck.clip_rect(rect, bounds)

      clipped.min.x.should eq(50)
      clipped.min.y.should eq(50)
      clipped.max.x.should eq(100)
      clipped.max.y.should eq(100)
    end

    it "returns empty rectangle when no overlap" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(200, 200, 300, 300)
      clipped = CrImage::BoundsCheck.clip_rect(rect, bounds)

      clipped.empty.should be_true
    end

    it "returns original rect when fully inside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(10, 10, 50, 50)
      clipped = CrImage::BoundsCheck.clip_rect(rect, bounds)

      clipped.should eq(rect)
    end
  end

  describe ".clamp" do
    it "clamps value to range" do
      CrImage::BoundsCheck.clamp(50, 0, 100).should eq(50)
      CrImage::BoundsCheck.clamp(-10, 0, 100).should eq(0)
      CrImage::BoundsCheck.clamp(150, 0, 100).should eq(100)
    end

    it "handles edge values" do
      CrImage::BoundsCheck.clamp(0, 0, 100).should eq(0)
      CrImage::BoundsCheck.clamp(100, 0, 100).should eq(100)
    end
  end

  describe ".clamp_point" do
    it "clamps both coordinates to bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      x, y = CrImage::BoundsCheck.clamp_point(50, 50, bounds)
      x.should eq(50)
      y.should eq(50)
    end

    it "clamps x coordinate when out of bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      x, y = CrImage::BoundsCheck.clamp_point(-10, 50, bounds)
      x.should eq(0)
      y.should eq(50)

      x, y = CrImage::BoundsCheck.clamp_point(150, 50, bounds)
      x.should eq(99)
      y.should eq(50)
    end

    it "clamps y coordinate when out of bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      x, y = CrImage::BoundsCheck.clamp_point(50, -10, bounds)
      x.should eq(50)
      y.should eq(0)

      x, y = CrImage::BoundsCheck.clamp_point(50, 150, bounds)
      x.should eq(50)
      y.should eq(99)
    end

    it "clamps both coordinates when both out of bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      x, y = CrImage::BoundsCheck.clamp_point(-10, -10, bounds)
      x.should eq(0)
      y.should eq(0)

      x, y = CrImage::BoundsCheck.clamp_point(150, 150, bounds)
      x.should eq(99)
      y.should eq(99)
    end
  end

  describe ".clamp_u8" do
    it "clamps Int32 to 0-255 range" do
      CrImage::BoundsCheck.clamp_u8(128).should eq(128_u8)
      CrImage::BoundsCheck.clamp_u8(-10).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(300).should eq(255_u8)
    end

    it "clamps Float64 to 0-255 range" do
      CrImage::BoundsCheck.clamp_u8(128.5).should eq(128_u8)
      CrImage::BoundsCheck.clamp_u8(-10.5).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(300.5).should eq(255_u8)
    end

    it "handles edge values" do
      CrImage::BoundsCheck.clamp_u8(0).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(255).should eq(255_u8)
    end
  end

  describe ".clip_line" do
    it "returns line when fully inside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(10, 10, 50, 50, bounds)

      result.should_not be_nil
      result.should eq({10, 10, 50, 50})
    end

    it "returns nil when line is completely outside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(200, 200, 300, 300, bounds)

      result.should be_nil
    end

    it "clips line when partially outside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-10, 50, 110, 50, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should eq(0)
      y0.should eq(50)
      x1.should eq(99)
      y1.should eq(50)
    end

    it "clips diagonal line" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-10, -10, 110, 110, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should be >= 0
      y0.should be >= 0
      x1.should be < 100
      y1.should be < 100
    end
  end

  describe ".overlap" do
    it "returns overlapping region" do
      r1 = CrImage.rect(0, 0, 100, 100)
      r2 = CrImage.rect(50, 50, 150, 150)
      overlap = CrImage::BoundsCheck.overlap(r1, r2)

      overlap.should_not be_nil
      overlap.not_nil!.min.x.should eq(50)
      overlap.not_nil!.min.y.should eq(50)
      overlap.not_nil!.max.x.should eq(100)
      overlap.not_nil!.max.y.should eq(100)
    end

    it "returns nil when no overlap" do
      r1 = CrImage.rect(0, 0, 100, 100)
      r2 = CrImage.rect(200, 200, 300, 300)
      overlap = CrImage::BoundsCheck.overlap(r1, r2)

      overlap.should be_nil
    end
  end

  describe ".validate_rect!" do
    it "does not raise when rectangle is within bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(10, 10, 50, 50)

      # Should not raise
      CrImage::BoundsCheck.validate_rect!(rect, bounds)
    end

    it "raises BoundsError when rectangle is outside bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(200, 200, 300, 300)

      expect_raises(CrImage::BoundsError) do
        CrImage::BoundsCheck.validate_rect!(rect, bounds)
      end
    end
  end
end

describe "edge cases" do
  describe ".clip_line" do
    it "handles vertical line clipping" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(50, -10, 50, 110, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should eq(50)
      x1.should eq(50)
      y0.should eq(0)
      y1.should eq(99)
    end

    it "handles horizontal line clipping" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-10, 50, 110, 50, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      y0.should eq(50)
      y1.should eq(50)
      x0.should eq(0)
      x1.should eq(99)
    end

    it "clips line crossing top boundary" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(50, -20, 60, 50, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      y0.should eq(0)
      y1.should eq(50)
    end

    it "clips line crossing bottom boundary" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(50, 50, 60, 120, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      y0.should eq(50)
      y1.should eq(99)
    end

    it "clips line crossing left boundary" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-20, 50, 50, 60, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should eq(0)
      x1.should eq(50)
    end

    it "clips line crossing right boundary" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(50, 50, 120, 60, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should eq(50)
      x1.should eq(99)
    end

    it "clips line crossing multiple boundaries" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-50, -50, 150, 150, bounds)

      result.should_not be_nil
      x0, y0, x1, y1 = result.not_nil!
      x0.should be >= 0
      y0.should be >= 0
      x1.should be < 100
      y1.should be < 100
    end

    it "returns nil for line completely above bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(10, -50, 50, -20, bounds)
      result.should be_nil
    end

    it "returns nil for line completely below bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(10, 150, 50, 200, bounds)
      result.should be_nil
    end

    it "returns nil for line completely left of bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(-50, 10, -20, 50, bounds)
      result.should be_nil
    end

    it "returns nil for line completely right of bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      result = CrImage::BoundsCheck.clip_line(150, 10, 200, 50, bounds)
      result.should be_nil
    end
  end

  describe ".clamp_point with non-zero origin bounds" do
    it "clamps to bounds with offset origin" do
      bounds = CrImage.rect(50, 50, 150, 150)
      x, y = CrImage::BoundsCheck.clamp_point(25, 25, bounds)
      x.should eq(50)
      y.should eq(50)

      x, y = CrImage::BoundsCheck.clamp_point(200, 200, bounds)
      x.should eq(149)
      y.should eq(149)
    end

    it "keeps point inside offset bounds" do
      bounds = CrImage.rect(50, 50, 150, 150)
      x, y = CrImage::BoundsCheck.clamp_point(100, 100, bounds)
      x.should eq(100)
      y.should eq(100)
    end
  end

  describe ".clip_rect with non-zero origin" do
    it "clips rectangle with offset bounds" do
      bounds = CrImage.rect(50, 50, 150, 150)
      rect = CrImage.rect(25, 25, 175, 175)
      clipped = CrImage::BoundsCheck.clip_rect(rect, bounds)

      clipped.min.x.should eq(50)
      clipped.min.y.should eq(50)
      clipped.max.x.should eq(150)
      clipped.max.y.should eq(150)
    end
  end

  describe ".clamp_u8 with boundary values" do
    it "handles exact boundary values" do
      CrImage::BoundsCheck.clamp_u8(0).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(255).should eq(255_u8)
      CrImage::BoundsCheck.clamp_u8(0.0).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(255.0).should eq(255_u8)
    end

    it "handles values just outside boundaries" do
      CrImage::BoundsCheck.clamp_u8(-1).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(256).should eq(255_u8)
      CrImage::BoundsCheck.clamp_u8(-0.1).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(255.1).should eq(255_u8)
    end

    it "handles extreme values" do
      CrImage::BoundsCheck.clamp_u8(-1000).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(1000).should eq(255_u8)
      CrImage::BoundsCheck.clamp_u8(-1000.0).should eq(0_u8)
      CrImage::BoundsCheck.clamp_u8(1000.0).should eq(255_u8)
    end
  end

  describe ".in_bounds? with boundary coordinates" do
    it "treats min as inclusive" do
      bounds = CrImage.rect(10, 10, 100, 100)
      CrImage::BoundsCheck.in_bounds?(10, 10, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(10, 50, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(50, 10, bounds).should be_true
    end

    it "treats max as exclusive" do
      bounds = CrImage.rect(10, 10, 100, 100)
      CrImage::BoundsCheck.in_bounds?(100, 50, bounds).should be_false
      CrImage::BoundsCheck.in_bounds?(50, 100, bounds).should be_false
      CrImage::BoundsCheck.in_bounds?(100, 100, bounds).should be_false
    end

    it "treats max-1 as inclusive" do
      bounds = CrImage.rect(10, 10, 100, 100)
      CrImage::BoundsCheck.in_bounds?(99, 99, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(99, 50, bounds).should be_true
      CrImage::BoundsCheck.in_bounds?(50, 99, bounds).should be_true
    end
  end

  describe ".overlap with edge cases" do
    it "handles touching rectangles (no overlap)" do
      r1 = CrImage.rect(0, 0, 100, 100)
      r2 = CrImage.rect(100, 0, 200, 100)
      overlap = CrImage::BoundsCheck.overlap(r1, r2)
      overlap.should be_nil
    end

    it "handles identical rectangles" do
      r1 = CrImage.rect(0, 0, 100, 100)
      r2 = CrImage.rect(0, 0, 100, 100)
      overlap = CrImage::BoundsCheck.overlap(r1, r2)

      overlap.should_not be_nil
      overlap.should eq(r1)
    end

    it "handles one rectangle inside another" do
      r1 = CrImage.rect(0, 0, 100, 100)
      r2 = CrImage.rect(25, 25, 75, 75)
      overlap = CrImage::BoundsCheck.overlap(r1, r2)

      overlap.should_not be_nil
      overlap.should eq(r2)
    end
  end

  describe ".clamp with equal min and max" do
    it "returns the value when min equals max" do
      CrImage::BoundsCheck.clamp(50, 50, 50).should eq(50)
      CrImage::BoundsCheck.clamp(40, 50, 50).should eq(50)
      CrImage::BoundsCheck.clamp(60, 50, 50).should eq(50)
    end
  end

  describe ".validate_rect! with edge cases" do
    it "accepts rectangle at exact bounds" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(0, 0, 100, 100)
      CrImage::BoundsCheck.validate_rect!(rect, bounds)
    end

    it "rejects rectangle partially outside" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(50, 50, 150, 150)

      expect_raises(CrImage::BoundsError) do
        CrImage::BoundsCheck.validate_rect!(rect, bounds)
      end
    end

    it "rejects rectangle with one edge outside" do
      bounds = CrImage.rect(0, 0, 100, 100)
      rect = CrImage.rect(0, 0, 101, 100)

      expect_raises(CrImage::BoundsError) do
        CrImage::BoundsCheck.validate_rect!(rect, bounds)
      end
    end
  end
end
