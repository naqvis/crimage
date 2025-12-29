require "../spec_helper"

describe CrImage::Draw do
  describe "ring_slice" do
    it "draws a filled ring slice" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      center = CrImage.point(100, 100)
      style = CrImage::Draw::RingStyle.new(CrImage::Color::RED, fill: true)

      CrImage::Draw.ring_slice(img, center, 30, 60, 0.0, Math::PI / 2, style)

      # Check that pixels in the ring slice are red
      # Point at angle 45° (PI/4), radius 45 (between 30 and 60)
      x = (100 + 45 * Math.cos(Math::PI / 4)).to_i
      y = (100 + 45 * Math.sin(Math::PI / 4)).to_i
      r, g, b, _ = img.at(x, y).rgba
      (r >> 8).should be > 200 # Should be red
      (g >> 8).should be < 50
      (b >> 8).should be < 50

      # Check that center is still white (hole)
      r, g, b, _ = img.at(100, 100).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)

      # Check that point outside angle range is white
      # Point at angle 3*PI/4 (135°), radius 45
      x2 = (100 + 45 * Math.cos(3 * Math::PI / 4)).to_i
      y2 = (100 + 45 * Math.sin(3 * Math::PI / 4)).to_i
      r, g, b, _ = img.at(x2, y2).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
    end

    it "draws a full ring (donut)" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      center = CrImage.point(100, 100)
      style = CrImage::Draw::RingStyle.new(CrImage::Color::BLUE, fill: true)

      # Full circle (0 to 2*PI)
      CrImage::Draw.ring_slice(img, center, 20, 50, 0.0, 2 * Math::PI, style)

      # Check ring area is blue
      r, g, b, _ = img.at(135, 100).rgba # Right side, radius 35
      (b >> 8).should be > 200

      # Check hole is white
      r, g, b, _ = img.at(100, 100).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "handles zero inner radius (becomes pie)" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      center = CrImage.point(100, 100)
      style = CrImage::Draw::RingStyle.new(CrImage::Color::GREEN, fill: true)

      CrImage::Draw.ring_slice(img, center, 0, 50, 0.0, Math::PI / 2, style)

      # Center should be filled (no hole)
      r, g, b, _ = img.at(100, 100).rgba
      (g >> 8).should be > 200
    end

    it "returns early for invalid radii" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      center = CrImage.point(50, 50)
      style = CrImage::Draw::RingStyle.new(CrImage::Color::RED, fill: true)

      # outer_radius <= 0
      CrImage::Draw.ring_slice(img, center, 10, 0, 0.0, Math::PI, style)
      # inner_radius >= outer_radius
      CrImage::Draw.ring_slice(img, center, 50, 40, 0.0, Math::PI, style)

      # Image should still be white
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "supports anti-aliasing" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      center = CrImage.point(100, 100)
      style = CrImage::Draw::RingStyle.new(CrImage::Color::RED, fill: true, anti_alias: true)

      CrImage::Draw.ring_slice(img, center, 30, 60, 0.0, Math::PI, style)

      # Just verify it doesn't crash and produces output
      # Edge pixels should have intermediate values due to AA
      img.bounds.width.should eq(200)
    end
  end

  describe "RingStyle" do
    it "creates with defaults" do
      style = CrImage::Draw::RingStyle.new(CrImage::Color::RED)
      style.fill.should be_true
      style.thickness.should eq(1)
      style.anti_alias.should be_false
    end

    it "supports builder pattern" do
      style = CrImage::Draw::RingStyle.new(CrImage::Color::RED)
        .with_fill(false)
        .with_thickness(3)
        .with_anti_alias(true)

      style.fill.should be_false
      style.thickness.should eq(3)
      style.anti_alias.should be_true
    end
  end
end
