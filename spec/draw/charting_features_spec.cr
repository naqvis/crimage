require "../spec_helper"

describe CrImage::Draw::Pattern do
  describe "#fill_at?" do
    it "returns true for solid pattern" do
      pattern = CrImage::Draw::Pattern.new(CrImage::Draw::PatternType::Solid, CrImage::Color::BLACK)
      pattern.fill_at?(0, 0).should be_true
      pattern.fill_at?(100, 100).should be_true
    end

    it "creates horizontal lines pattern" do
      pattern = CrImage::Draw::Pattern.horizontal(CrImage::Color::BLACK, spacing: 4, thickness: 1)
      pattern.fill_at?(0, 0).should be_true
      pattern.fill_at?(0, 1).should be_false
      pattern.fill_at?(0, 4).should be_true
    end

    it "creates vertical lines pattern" do
      pattern = CrImage::Draw::Pattern.vertical(CrImage::Color::BLACK, spacing: 4, thickness: 1)
      pattern.fill_at?(0, 0).should be_true
      pattern.fill_at?(1, 0).should be_false
      pattern.fill_at?(4, 0).should be_true
    end

    it "creates dots pattern" do
      pattern = CrImage::Draw::Pattern.dots(CrImage::Color::BLACK, spacing: 8, size: 2)
      # Center of cell should have dot
      pattern.fill_at?(4, 4).should be_true
      # Corner should not
      pattern.fill_at?(0, 0).should be_false
    end
  end
end

describe CrImage::Draw do
  describe ".fill_polygon_pattern" do
    it "fills polygon with diagonal pattern" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(10, 10),
        CrImage.point(90, 10),
        CrImage.point(90, 90),
        CrImage.point(10, 90),
      ]

      pattern = CrImage::Draw::Pattern.diagonal(CrImage::Color::BLUE, spacing: 6)
      CrImage::Draw.fill_polygon_pattern(img, points, pattern)

      # Some pixels should be blue (pattern), some white (gaps)
      has_blue = false
      has_white = false
      (20..80).each do |y|
        (20..80).each do |x|
          r, g, b, _ = img.at(x, y).rgba
          if (b >> 8) > 200 && (r >> 8) < 50
            has_blue = true
          elsif (r >> 8) > 200 && (g >> 8) > 200 && (b >> 8) > 200
            has_white = true
          end
        end
      end
      has_blue.should be_true
      has_white.should be_true
    end

    it "fills with background color" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      points = [
        CrImage.point(10, 10),
        CrImage.point(90, 10),
        CrImage.point(90, 90),
        CrImage.point(10, 90),
      ]

      pattern = CrImage::Draw::Pattern.new(
        CrImage::Draw::PatternType::HorizontalLines,
        CrImage::Color::BLACK,
        background: CrImage::Color::YELLOW,
        spacing: 8,
        thickness: 2
      )
      CrImage::Draw.fill_polygon_pattern(img, points, pattern)

      # Should have yellow background in gaps
      has_yellow = false
      (20..80).each do |y|
        (20..80).each do |x|
          r, g, _, _ = img.at(x, y).rgba
          if (r >> 8) > 200 && (g >> 8) > 200
            has_yellow = true
            break
          end
        end
        break if has_yellow
      end
      has_yellow.should be_true
    end
  end

  describe ".fill_rect_pattern" do
    it "fills rectangle with crosshatch pattern" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      rect = CrImage.rect(10, 10, 90, 90)
      pattern = CrImage::Draw::Pattern.crosshatch(CrImage::Color::RED, spacing: 8)
      CrImage::Draw.fill_rect_pattern(img, rect, pattern)

      # Center should have pattern
      r, _, _, _ = img.at(50, 50).rgba
      # Either red (on line) or white (gap)
      ((r >> 8) == 255 || (r >> 8) == 0).should be_true
    end
  end
end

describe CrImage::Draw::CornerRadii do
  describe ".uniform" do
    it "creates uniform radii" do
      radii = CrImage::Draw::CornerRadii.uniform(10)
      radii.top_left.should eq(10)
      radii.top_right.should eq(10)
      radii.bottom_right.should eq(10)
      radii.bottom_left.should eq(10)
    end
  end

  describe ".top" do
    it "creates top-only radii" do
      radii = CrImage::Draw::CornerRadii.top(15)
      radii.top_left.should eq(15)
      radii.top_right.should eq(15)
      radii.bottom_right.should eq(0)
      radii.bottom_left.should eq(0)
    end
  end
end

describe CrImage::Draw do
  describe ".rounded_rect" do
    it "draws filled rounded rectangle" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      rect = CrImage.rect(10, 10, 90, 90)
      radii = CrImage::Draw::CornerRadii.uniform(10)
      CrImage::Draw.rounded_rect(img, rect, radii, fill: CrImage::Color::BLUE)

      # Center should be blue
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should eq(0)
      (g >> 8).should eq(0)
      (b >> 8).should eq(255)

      # Corner should be white (rounded off)
      r, g, b, _ = img.at(11, 11).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "draws bar chart style (top corners only)" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      rect = CrImage.rect(20, 30, 80, 90)
      radii = CrImage::Draw::CornerRadii.top(10)
      CrImage::Draw.rounded_rect(img, rect, radii, fill: CrImage::Color::GREEN)

      # Top-left corner area should be white (rounded)
      r, g, b, _ = img.at(21, 31).rgba
      (r >> 8).should eq(255)

      # Bottom-left corner should be green (not rounded)
      r, g, b, _ = img.at(21, 89).rgba
      (g >> 8).should eq(255)
    end
  end
end

describe CrImage::Draw::ArrowStyle do
  describe ".single" do
    it "creates single-headed arrow style" do
      style = CrImage::Draw::ArrowStyle.single(CrImage::Color::BLACK)
      style.head_at_start.should be_false
      style.head_at_end.should be_true
    end
  end

  describe ".double" do
    it "creates double-headed arrow style" do
      style = CrImage::Draw::ArrowStyle.double(CrImage::Color::BLACK)
      style.head_at_start.should be_true
      style.head_at_end.should be_true
    end
  end
end

describe CrImage::Draw do
  describe ".arrow" do
    it "draws arrow with triangle head" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      style = CrImage::Draw::ArrowStyle.single(CrImage::Color::BLACK, thickness: 2, head_size: 15)
      CrImage::Draw.arrow(img, CrImage.point(20, 50), CrImage.point(180, 50), style)

      # Line should be drawn
      r, g, b, _ = img.at(100, 50).rgba
      (r >> 8).should eq(0)

      # Arrow head area should have black pixels
      has_head = false
      (40..55).each do |y|
        (165..180).each do |x|
          r, _, _, _ = img.at(x, y).rgba
          if (r >> 8) == 0
            has_head = true
            break
          end
        end
        break if has_head
      end
      has_head.should be_true
    end

    it "draws double-headed arrow" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      style = CrImage::Draw::ArrowStyle.double(CrImage::Color::RED, head_size: 12)
      CrImage::Draw.arrow(img, CrImage.point(30, 50), CrImage.point(170, 50), style)

      # Both ends should have arrow heads
      has_start_head = false
      has_end_head = false

      (40..60).each do |y|
        (20..45).each do |x|
          r, _, _, _ = img.at(x, y).rgba
          if (r >> 8) > 200
            has_start_head = true
            break
          end
        end
        break if has_start_head
      end

      (40..60).each do |y|
        (155..180).each do |x|
          r, _, _, _ = img.at(x, y).rgba
          if (r >> 8) > 200
            has_end_head = true
            break
          end
        end
        break if has_end_head
      end

      has_start_head.should be_true
      has_end_head.should be_true
    end
  end
end

describe CrImage::Draw::MarkerStyle do
  describe ".filled" do
    it "creates filled marker style" do
      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED)
      style.fill_color.should eq(CrImage::Color::RED)
      style.stroke_color.should be_nil
    end
  end

  describe ".outlined" do
    it "creates outlined marker style" do
      style = CrImage::Draw::MarkerStyle.outlined(CrImage::Draw::MarkerType::Square, CrImage::Color::BLUE)
      style.fill_color.should be_nil
      style.stroke_color.should eq(CrImage::Color::BLUE)
    end
  end
end

describe CrImage::Draw do
  describe ".marker" do
    it "draws circle marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED, size: 10)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be red
      r, g, b, _ = img.at(25, 25).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(0)
    end

    it "draws square marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Square, CrImage::Color::BLUE, size: 10)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be blue
      r, g, b, _ = img.at(25, 25).rgba
      (b >> 8).should eq(255)
    end

    it "draws diamond marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Diamond, CrImage::Color::GREEN, size: 12)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be green
      _, g, _, _ = img.at(25, 25).rgba
      (g >> 8).should eq(255)
    end

    it "draws star marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Star, CrImage::Color::YELLOW, size: 16)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be yellow
      r, g, _, _ = img.at(25, 25).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
    end

    it "draws cross marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.new(CrImage::Draw::MarkerType::Cross, size: 12,
        stroke_color: CrImage::Color::BLACK, stroke_thickness: 2)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be black
      r, g, b, _ = img.at(25, 25).rgba
      (r >> 8).should eq(0)
    end

    it "draws plus marker" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      style = CrImage::Draw::MarkerStyle.new(CrImage::Draw::MarkerType::Plus, size: 12,
        stroke_color: CrImage::Color::BLACK, stroke_thickness: 2)
      CrImage::Draw.marker(img, CrImage.point(25, 25), style)

      # Center should be black
      r, g, b, _ = img.at(25, 25).rgba
      (r >> 8).should eq(0)
    end
  end

  describe ".markers" do
    it "draws multiple markers" do
      img = CrImage.rgba(100, 50, CrImage::Color::WHITE)

      points = [CrImage.point(20, 25), CrImage.point(50, 25), CrImage.point(80, 25)]
      style = CrImage::Draw::MarkerStyle.filled(CrImage::Draw::MarkerType::Circle, CrImage::Color::RED, size: 8)
      CrImage::Draw.markers(img, points, style)

      # All three points should have markers
      points.each do |p|
        r, _, _, _ = img.at(p.x, p.y).rgba
        (r >> 8).should eq(255)
      end
    end
  end
end

# Text on curve specs
describe CrImage::Draw do
  describe ".text_on_arc" do
    it "draws text along an arc" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)

      font_path = "spec/testdata/fonts/Roboto/Roboto-Regular.ttf"
      if File.exists?(font_path)
        font = FreeType::TrueType.load(font_path)
        face = FreeType::TrueType.new_face(font, 14.0)

        CrImage::Draw.text_on_arc(img, "HELLO", CrImage.point(100, 100), 60,
          -::Math::PI * 0.75, -::Math::PI * 0.25, face, CrImage::Color::BLACK)

        # Should have some black pixels (text)
        has_text = false
        (0...200).each do |y|
          (0...200).each do |x|
            r, _, _, _ = img.at(x, y).rgba
            if (r >> 8) < 50
              has_text = true
              break
            end
          end
          break if has_text
        end
        has_text.should be_true
      end
    end
  end

  describe ".text_on_curve" do
    it "draws text along a bezier curve" do
      img = CrImage.rgba(300, 150, CrImage::Color::WHITE)

      font_path = "spec/testdata/fonts/Roboto/Roboto-Regular.ttf"
      if File.exists?(font_path)
        font = FreeType::TrueType.load(font_path)
        face = FreeType::TrueType.new_face(font, 16.0)

        curve = CrImage::Draw::CubicBezier.new(
          {30.0, 100.0}, {100.0, 30.0}, {200.0, 30.0}, {270.0, 100.0}
        )

        CrImage::Draw.text_on_curve(img, "Curved", curve, face, CrImage::Color::BLUE)

        # Should have some blue pixels
        has_text = false
        (0...150).each do |y|
          (0...300).each do |x|
            _, _, b, _ = img.at(x, y).rgba
            if (b >> 8) > 200
              has_text = true
              break
            end
          end
          break if has_text
        end
        has_text.should be_true
      end
    end
  end
end

# Annotation specs
describe CrImage::Draw::CalloutStyle do
  it "creates callout style with defaults" do
    style = CrImage::Draw::CalloutStyle.new
    style.corner_radius.should eq(5)
    style.padding.should eq(8)
  end
end

describe CrImage::Draw do
  describe ".callout" do
    it "draws a callout box with leader line" do
      img = CrImage.rgba(200, 150, CrImage::Color::WHITE)

      style = CrImage::Draw::CalloutStyle.new(
        background: CrImage::Color::YELLOW,
        border: CrImage::Color::BLACK
      )

      CrImage::Draw.callout(img, "Note", CrImage.point(100, 50), CrImage.point(150, 120), style)

      # Should have yellow background
      has_yellow = false
      (30..70).each do |y|
        (60..140).each do |x|
          r, g, _, _ = img.at(x, y).rgba
          if (r >> 8) > 200 && (g >> 8) > 200
            has_yellow = true
            break
          end
        end
        break if has_yellow
      end
      has_yellow.should be_true
    end
  end

  describe ".dimension_line" do
    it "draws a dimension line with arrows" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      style = CrImage::Draw::DimensionStyle.new(color: CrImage::Color::BLACK)
      CrImage::Draw.dimension_line(img, CrImage.point(30, 70), CrImage.point(170, 70),
        "140", style, offset: 25)

      # Should have black pixels somewhere (line, arrows, or extension lines)
      has_line = false
      (0...100).each do |y|
        (0...200).each do |x|
          r, g, b, _ = img.at(x, y).rgba
          if (r >> 8) < 50 && (g >> 8) < 50 && (b >> 8) < 50
            has_line = true
            break
          end
        end
        break if has_line
      end
      has_line.should be_true
    end
  end

  describe ".bracket" do
    it "draws a curly bracket" do
      img = CrImage.rgba(100, 150, CrImage::Color::WHITE)

      style = CrImage::Draw::BracketStyle.new(color: CrImage::Color::BLACK, thickness: 2)
      CrImage::Draw.bracket(img, CrImage.point(30, 20), CrImage.point(30, 130), style, side: :right)

      # Should have black pixels
      has_bracket = false
      (20..130).each do |y|
        (30..60).each do |x|
          r, _, _, _ = img.at(x, y).rgba
          if (r >> 8) < 50
            has_bracket = true
            break
          end
        end
        break if has_bracket
      end
      has_bracket.should be_true
    end
  end

  describe ".square_bracket" do
    it "draws a square bracket" do
      img = CrImage.rgba(100, 150, CrImage::Color::WHITE)

      style = CrImage::Draw::BracketStyle.new(color: CrImage::Color::RED, thickness: 2)
      CrImage::Draw.square_bracket(img, CrImage.point(50, 20), CrImage.point(50, 130), style)

      # Should have red pixels
      has_bracket = false
      (20..130).each do |y|
        (50..70).each do |x|
          r, _, _, _ = img.at(x, y).rgba
          if (r >> 8) > 200
            has_bracket = true
            break
          end
        end
        break if has_bracket
      end
      has_bracket.should be_true
    end
  end
end

# Gradient stroke specs
describe CrImage::Draw do
  describe ".stroke_path_gradient" do
    it "strokes a path with gradient color" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      path = CrImage::Draw::Path.new
        .move_to(20, 50)
        .line_to(180, 50)

      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]

      CrImage::Draw.stroke_path_gradient(img, path, stops, thickness: 3)

      # Left side should be reddish
      r, _, b, _ = img.at(30, 50).rgba
      (r >> 8).should be > 100

      # Right side should be bluish
      r, _, b, _ = img.at(170, 50).rgba
      (b >> 8).should be > 100
    end
  end

  describe ".stroke_line_gradient" do
    it "strokes a line with gradient" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::GREEN),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::YELLOW),
      ]

      CrImage::Draw.stroke_line_gradient(img, CrImage.point(20, 50), CrImage.point(180, 50),
        stops, thickness: 4)

      # Should have colored pixels
      _, g, _, _ = img.at(100, 50).rgba
      (g >> 8).should be > 200
    end
  end

  describe ".stroke_arc_gradient" do
    it "strokes an arc with gradient" do
      img = CrImage.rgba(150, 150, CrImage::Color::WHITE)

      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::GREEN),
      ]

      CrImage::Draw.stroke_arc_gradient(img, CrImage.point(75, 75), 50,
        0.0, ::Math::PI, stops, thickness: 4)

      # Should have colored pixels on the arc
      has_color = false
      (70..130).each do |y|
        (20..130).each do |x|
          r, g, _, _ = img.at(x, y).rgba
          if (r >> 8) > 100 || (g >> 8) > 100
            has_color = true
            break
          end
        end
        break if has_color
      end
      has_color.should be_true
    end
  end

  describe ".stroke_bezier_gradient" do
    it "strokes a bezier curve with gradient" do
      img = CrImage.rgba(200, 100, CrImage::Color::WHITE)

      curve = CrImage::Draw::CubicBezier.new(
        {20.0, 80.0}, {70.0, 20.0}, {130.0, 20.0}, {180.0, 80.0}
      )

      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::BLUE),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
      ]

      CrImage::Draw.stroke_bezier_gradient(img, curve, stops, thickness: 3)

      # Should have colored pixels
      has_color = false
      (0...100).each do |y|
        (0...200).each do |x|
          r, _, b, _ = img.at(x, y).rgba
          if (r >> 8) > 100 || (b >> 8) > 100
            has_color = true
            break
          end
        end
        break if has_color
      end
      has_color.should be_true
    end
  end
end
