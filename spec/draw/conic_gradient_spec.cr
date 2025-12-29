require "../spec_helper"

describe CrImage::Draw do
  describe "ConicGradient" do
    it "creates a conic gradient" do
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(100, 100), stops)

      gradient.center.x.should eq(100)
      gradient.center.y.should eq(100)
      gradient.stops.size.should eq(2)
      gradient.start_angle.should eq(0.0)
    end

    it "creates with custom start angle" do
      stops = [CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED)]
      gradient = CrImage::Draw::ConicGradient.new(
        CrImage.point(100, 100),
        stops,
        start_angle: -Math::PI / 2
      )

      gradient.start_angle.should eq(-Math::PI / 2)
    end

    it "interpolates colors by position" do
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(100, 100), stops)

      # At t=0, should be red
      c0 = gradient.color_at(0.0)
      r, g, b, _ = c0.rgba
      (r >> 8).should be > 200
      (b >> 8).should be < 50

      # At t=1, should be blue
      c1 = gradient.color_at(1.0)
      r, g, b, _ = c1.rgba
      (r >> 8).should be < 50
      (b >> 8).should be > 200

      # At t=0.5, should be purple-ish (mix)
      c_mid = gradient.color_at(0.5)
      r, g, b, _ = c_mid.rgba
      (r >> 8).should be > 100
      (b >> 8).should be > 100
    end
  end

  describe "fill_conic_gradient" do
    it "fills rectangle with angular gradient" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(100, 100), stops)

      CrImage::Draw.fill_conic_gradient(img, img.bounds, gradient)

      # Right side (angle ~0) should be reddish
      r, g, b, _ = img.at(180, 100).rgba
      (r >> 8).should be > 150

      # Left side (angle ~π) should be more blue
      r, g, b, _ = img.at(20, 100).rgba
      (b >> 8).should be > 100
    end

    it "respects start_angle" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      # Start from top (-π/2)
      gradient = CrImage::Draw::ConicGradient.new(
        CrImage.point(100, 100),
        stops,
        start_angle: -Math::PI / 2
      )

      CrImage::Draw.fill_conic_gradient(img, img.bounds, gradient)

      # Top (angle = -π/2 = start) should be red
      r, g, b, _ = img.at(100, 20).rgba
      (r >> 8).should be > 150
    end
  end

  describe "fill_conic_ring" do
    it "fills a ring with angular gradient" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
        CrImage::Draw::ColorStop.new(0.5, CrImage::Color::YELLOW),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
      ]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(100, 100), stops)

      CrImage::Draw.fill_conic_ring(img, CrImage.point(100, 100), 30, 60, gradient)

      # Center should still be white (hole)
      r, g, b, _ = img.at(100, 100).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)

      # Ring area should have gradient colors
      # Right side at radius 45 should have some color
      r, g, b, _ = img.at(145, 100).rgba
      # Should not be white
      ((r >> 8) == 255 && (g >> 8) == 255 && (b >> 8) == 255).should be_false
    end

    it "respects angle range for partial ring" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(100, 100), stops)

      # Only fill right half (0 to π)
      CrImage::Draw.fill_conic_ring(img, CrImage.point(100, 100), 30, 60, gradient,
        start_angle: -Math::PI / 2, end_angle: Math::PI / 2)

      # Right side should have color
      r, g, b, _ = img.at(145, 100).rgba
      ((r >> 8) == 255 && (g >> 8) == 255 && (b >> 8) == 255).should be_false

      # Left side should be white (outside angle range)
      r, g, b, _ = img.at(55, 100).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "handles invalid radii" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      stops = [CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED)]
      gradient = CrImage::Draw::ConicGradient.new(CrImage.point(50, 50), stops)

      # Should not crash with invalid radii
      CrImage::Draw.fill_conic_ring(img, CrImage.point(50, 50), 50, 40, gradient) # inner >= outer
      CrImage::Draw.fill_conic_ring(img, CrImage.point(50, 50), 10, 0, gradient)  # outer <= 0

      # Image should still be white
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should eq(255)
    end
  end
end
