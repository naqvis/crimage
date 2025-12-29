require "../spec_helper"

describe CrImage::Draw::Path do
  describe "#move_to" do
    it "adds a move command" do
      path = CrImage::Draw::Path.new.move_to(100, 200)
      path.commands.size.should eq(1)
      path.commands[0].should be_a(CrImage::Draw::MoveToCommand)
    end
  end

  describe "#line_to" do
    it "adds a line command" do
      path = CrImage::Draw::Path.new.move_to(0, 0).line_to(100, 100)
      path.commands.size.should eq(2)
      path.commands[1].should be_a(CrImage::Draw::LineToCommand)
    end
  end

  describe "#quadratic_to" do
    it "adds a quadratic bezier command" do
      path = CrImage::Draw::Path.new.move_to(0, 0).quadratic_to(50, 0, 100, 100)
      path.commands.size.should eq(2)
      path.commands[1].should be_a(CrImage::Draw::QuadraticToCommand)
    end
  end

  describe "#bezier_to" do
    it "adds a cubic bezier command" do
      path = CrImage::Draw::Path.new.move_to(0, 0).bezier_to(25, 0, 75, 100, 100, 100)
      path.commands.size.should eq(2)
      path.commands[1].should be_a(CrImage::Draw::CubicToCommand)
    end
  end

  describe "#close" do
    it "adds a close command" do
      path = CrImage::Draw::Path.new.move_to(0, 0).line_to(100, 0).line_to(100, 100).close
      path.commands.size.should eq(4)
      path.commands[3].should be_a(CrImage::Draw::CloseCommand)
    end
  end

  describe "#flatten" do
    it "converts path to array of points" do
      path = CrImage::Draw::Path.new
        .move_to(0, 0)
        .line_to(100, 0)
        .line_to(100, 100)
        .close

      points = path.flatten
      points.size.should eq(4)
      points[0].should eq(CrImage::Point.new(0, 0))
      points[1].should eq(CrImage::Point.new(100, 0))
      points[2].should eq(CrImage::Point.new(100, 100))
      points[3].should eq(CrImage::Point.new(0, 0))
    end

    it "flattens bezier curves to line segments" do
      path = CrImage::Draw::Path.new(segments_per_curve: 10)
        .move_to(0, 0)
        .bezier_to(50, 0, 50, 100, 100, 100)

      points = path.flatten
      # 1 move + 10 bezier segments = 11 points
      points.size.should eq(11)
      points[0].should eq(CrImage::Point.new(0, 0))
      points.last.should eq(CrImage::Point.new(100, 100))
    end
  end

  describe "#empty?" do
    it "returns true for empty path" do
      CrImage::Draw::Path.new.empty?.should be_true
    end

    it "returns false for non-empty path" do
      CrImage::Draw::Path.new.move_to(0, 0).empty?.should be_false
    end
  end
end

describe CrImage::Draw do
  describe ".fill_path" do
    it "fills a triangular path" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(50, 10)
        .line_to(90, 90)
        .line_to(10, 90)
        .close

      CrImage::Draw.fill_path(img, path, CrImage::Color::RED)

      # Center of triangle should be red
      r, g, b, _ = img.at(50, 60).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(0)
      (b >> 8).should eq(0)

      # Outside should be white
      r, g, b, _ = img.at(5, 5).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "fills a path with bezier curves" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(10, 50)
        .bezier_to(50, 10, 150, 10, 190, 50)
        .line_to(190, 90)
        .line_to(10, 90)
        .close

      CrImage::Draw.fill_path(img, path, CrImage::Color::BLUE)

      # Inside the shape
      r, g, b, _ = img.at(100, 80).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(0)
      (b >> 8).should eq(255)
    end
  end

  describe ".fill_path_aa" do
    it "fills a path with anti-aliased edges" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(50, 10)
        .line_to(90, 90)
        .line_to(10, 90)
        .close

      CrImage::Draw.fill_path_aa(img, path, CrImage::Color::RED)

      # Center should be filled
      r, g, b, _ = img.at(50, 60).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(0)
      (b >> 8).should eq(0)
    end
  end

  describe ".stroke_path" do
    it "strokes a path outline" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(10, 10)
        .line_to(90, 10)
        .line_to(90, 90)

      style = CrImage::Draw::PathStyle.new(CrImage::Color::BLACK, thickness: 1)
      CrImage::Draw.stroke_path(img, path, style)

      # Points on the path should be black
      r, g, b, _ = img.at(50, 10).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(0)
      (b >> 8).should eq(0)

      r, g, b, _ = img.at(90, 50).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(0)
      (b >> 8).should eq(0)
    end
  end

  describe ".fill_bezier_band" do
    it "fills area between two bezier curves" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      top_curve = {
        CrImage.point(10, 30),
        CrImage.point(60, 20),
        CrImage.point(140, 20),
        CrImage.point(190, 30),
      }

      bottom_curve = {
        CrImage.point(10, 70),
        CrImage.point(60, 80),
        CrImage.point(140, 80),
        CrImage.point(190, 70),
      }

      CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve, CrImage::Color::GREEN)

      # Center of band should be green
      r, g, b, _ = img.at(100, 50).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(255) # GREEN is 0, 255, 0
      (b >> 8).should eq(0)

      # Outside should be white
      r, g, b, _ = img.at(100, 10).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)

      r, g, b, _ = img.at(100, 95).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "fills with anti-aliasing" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      top_curve = {
        CrImage.point(10, 30),
        CrImage.point(60, 20),
        CrImage.point(140, 20),
        CrImage.point(190, 30),
      }

      bottom_curve = {
        CrImage.point(10, 70),
        CrImage.point(60, 80),
        CrImage.point(140, 80),
        CrImage.point(190, 70),
      }

      CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve, CrImage::Color::GREEN,
        segments: 32, anti_alias: true)

      # Center should still be filled
      r, g, b, _ = img.at(100, 50).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(255)
      (b >> 8).should eq(0)
    end

    it "works with float tuple coordinates" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      top_curve = {
        {10.0, 30.0},
        {60.0, 20.0},
        {140.0, 20.0},
        {190.0, 30.0},
      }

      bottom_curve = {
        {10.0, 70.0},
        {60.0, 80.0},
        {140.0, 80.0},
        {190.0, 70.0},
      }

      CrImage::Draw.fill_bezier_band(img, top_curve, bottom_curve, CrImage::Color::BLUE)

      r, g, b, _ = img.at(100, 50).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(0)
      (b >> 8).should eq(255)
    end
  end

  describe ".fill_polygon_aa" do
    it "fills polygon with anti-aliased edges" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(50, 10),
        CrImage.point(90, 90),
        CrImage.point(10, 90),
      ]

      CrImage::Draw.fill_polygon_aa(img, points, CrImage::Color::RED)

      # Center should be filled
      r, g, b, _ = img.at(50, 60).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(0)
      (b >> 8).should eq(0)
    end
  end
end

describe CrImage::Draw::CubicBezier do
  describe "#at" do
    it "returns start point at t=0" do
      bezier = CrImage::Draw::CubicBezier.new(
        {0.0, 0.0}, {25.0, 0.0}, {75.0, 100.0}, {100.0, 100.0}
      )

      point = bezier.at(0.0)
      point[0].should be_close(0.0, 0.001)
      point[1].should be_close(0.0, 0.001)
    end

    it "returns end point at t=1" do
      bezier = CrImage::Draw::CubicBezier.new(
        {0.0, 0.0}, {25.0, 0.0}, {75.0, 100.0}, {100.0, 100.0}
      )

      point = bezier.at(1.0)
      point[0].should be_close(100.0, 0.001)
      point[1].should be_close(100.0, 0.001)
    end

    it "returns midpoint at t=0.5" do
      bezier = CrImage::Draw::CubicBezier.new(
        {0.0, 0.0}, {0.0, 0.0}, {100.0, 100.0}, {100.0, 100.0}
      )

      point = bezier.at(0.5)
      point[0].should be_close(50.0, 0.001)
      point[1].should be_close(50.0, 0.001)
    end
  end

  describe "#flatten" do
    it "returns array of points along curve" do
      bezier = CrImage::Draw::CubicBezier.new(
        {0.0, 0.0}, {25.0, 0.0}, {75.0, 100.0}, {100.0, 100.0}
      )

      points = bezier.flatten(10)
      points.size.should eq(11) # start + 10 segments
      points.first.should eq({0.0, 0.0})
      points.last[0].should be_close(100.0, 0.001)
      points.last[1].should be_close(100.0, 0.001)
    end
  end
end

describe CrImage::Draw do
  describe ".fill_polygon_gradient" do
    it "fills polygon with linear gradient" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(10, 10),
        CrImage.point(90, 10),
        CrImage.point(90, 90),
        CrImage.point(10, 90),
      ]

      gradient = CrImage::Draw::LinearGradient.new(
        CrImage.point(10, 50),
        CrImage.point(90, 50),
        [
          CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
          CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
        ]
      )

      CrImage::Draw.fill_polygon_gradient(img, points, gradient)

      # Left side should be reddish
      r, _, b, _ = img.at(15, 50).rgba
      (r >> 8).should be > 200
      (b >> 8).should be < 50

      # Right side should be bluish
      r, _, b, _ = img.at(85, 50).rgba
      (r >> 8).should be < 50
      (b >> 8).should be > 200
    end

    it "fills polygon with radial gradient" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(10, 10),
        CrImage.point(90, 10),
        CrImage.point(90, 90),
        CrImage.point(10, 90),
      ]

      gradient = CrImage::Draw::RadialGradient.new(
        CrImage.point(50, 50),
        40,
        [
          CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
          CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
        ]
      )

      CrImage::Draw.fill_polygon_gradient(img, points, gradient)

      # Center should be reddish
      r, _, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200
      (b >> 8).should be < 50
    end
  end

  describe ".fill_path_gradient" do
    it "fills path with gradient" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(10, 10)
        .line_to(90, 10)
        .line_to(90, 90)
        .line_to(10, 90)
        .close

      gradient = CrImage::Draw::LinearGradient.new(
        CrImage.point(10, 50),
        CrImage.point(90, 50),
        [
          CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
          CrImage::Draw::ColorStop.new(1.0, CrImage::Color::YELLOW),
        ]
      )

      CrImage::Draw.fill_path_gradient(img, path, gradient)

      # Should have gradient fill
      _, g, _, _ = img.at(50, 50).rgba
      (g >> 8).should be > 200
    end
  end
end

describe CrImage::Draw::BlendMode do
  describe ".blend_colors" do
    it "blends with multiply mode" do
      white = CrImage::Color::WHITE
      gray = CrImage::Color.rgba(128_u8, 128_u8, 128_u8, 255_u8)

      result = CrImage::Draw.blend_colors(gray, white, CrImage::Draw::BlendMode::Multiply)
      r, g, b, _ = result.rgba

      # Multiply with white should give approximately the source color
      # gray * white = gray (since white = 1.0)
      (r >> 8).should be_close(128, 5)
      (g >> 8).should be_close(128, 5)
      (b >> 8).should be_close(128, 5)
    end

    it "blends with screen mode" do
      black = CrImage::Color::BLACK
      gray = CrImage::Color.rgba(128_u8, 128_u8, 128_u8, 255_u8)

      result = CrImage::Draw.blend_colors(gray, black, CrImage::Draw::BlendMode::Screen)
      r, g, b, _ = result.rgba

      # Screen with black should give approximately the source color
      (r >> 8).should be_close(128, 5)
      (g >> 8).should be_close(128, 5)
      (b >> 8).should be_close(128, 5)
    end

    it "blends with overlay mode" do
      gray = CrImage::Color.rgba(128_u8, 128_u8, 128_u8, 255_u8)

      result = CrImage::Draw.blend_colors(gray, gray, CrImage::Draw::BlendMode::Overlay)
      r, _, _, _ = result.rgba

      # Overlay of gray on gray should be close to gray
      (r >> 8).should be_close(128, 20)
    end

    it "blends with soft_light mode" do
      gray = CrImage::Color.rgba(128_u8, 128_u8, 128_u8, 255_u8)

      result = CrImage::Draw.blend_colors(gray, gray, CrImage::Draw::BlendMode::SoftLight)
      r, _, _, _ = result.rgba

      # Soft light of gray on gray should be close to gray
      (r >> 8).should be_close(128, 20)
    end
  end
end

describe CrImage::Draw do
  describe ".fill_polygon_blended" do
    it "fills polygon with blend mode" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(20, 20),
        CrImage.point(80, 20),
        CrImage.point(80, 80),
        CrImage.point(20, 80),
      ]

      color = CrImage::Color.rgba(255_u8, 0_u8, 0_u8, 128_u8)
      CrImage::Draw.fill_polygon_blended(img, points, color, CrImage::Draw::BlendMode::Multiply)

      # Center should be affected by multiply blend
      r, g, b, _ = img.at(50, 50).rgba
      # Multiply red with white gives red, but with alpha blending
      (r >> 8).should be > 100
    end
  end

  describe ".fill_path_blended" do
    it "fills path with blend mode" do
      img = CrImage.rgba(100, 100, CrImage::Color.rgba(100_u8, 100_u8, 100_u8, 255_u8))

      path = CrImage::Draw::Path.new
        .move_to(20, 20)
        .line_to(80, 20)
        .line_to(80, 80)
        .line_to(20, 80)
        .close

      color = CrImage::Color.rgba(200_u8, 200_u8, 200_u8, 255_u8)
      CrImage::Draw.fill_path_blended(img, path, color, CrImage::Draw::BlendMode::Screen)

      # Screen should lighten
      r, _, _, _ = img.at(50, 50).rgba
      (r >> 8).should be > 100
    end
  end
end
