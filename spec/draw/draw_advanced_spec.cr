require "../spec_helper"

module CrImage
  describe "Advanced Draw Tests" do
    it "draws with NRGBA source" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = NRGBA.new(rect(0, 0, 10, 10))
      src.set(5, 5, Color::NRGBA.new(255, 0, 0, 128))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::SRC)

      # Should have drawn the pixel
      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should be > 0
    end

    it "draws Gray source to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = Gray.new(rect(0, 0, 10, 10))
      src.set(5, 5, Color::Gray.new(128))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::OVER)

      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should eq(128)
      color.g.should eq(128)
      color.b.should eq(128)
    end

    it "draws CMYK source to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = CMYK.new(rect(0, 0, 10, 10))
      src.set(5, 5, Color::CMYK.new(0, 255, 255, 0))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::OVER)

      color = dst.at(5, 5).as(Color::RGBA)
      # Should be red
      color.r.should be > 200
    end

    it "draws YCbCr source to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio444)

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::OVER)

      # Should complete without error
      dst.should_not be_nil
    end

    it "draws with mask" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = Uniform.new(Color::RGBA.new(255, 0, 0, 255))
      mask = Alpha.new(rect(0, 0, 10, 10))

      # Set mask to 50% alpha
      mask.set(5, 5, Color::Alpha.new(128))

      Draw.draw_mask(dst, dst.bounds, src, Point.zero, mask, Point.zero, Draw::Op::OVER)

      # Should have semi-transparent red
      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should be > 0
      color.r.should be < 255
    end

    it "draws glyph with mask" do
      dst = RGBA.new(rect(0, 0, 20, 20))
      src = Uniform.new(Color::RGBA.new(0, 0, 0, 255))
      mask = Alpha.new(rect(0, 0, 10, 10))

      # Create a simple glyph pattern
      5.times do |i|
        mask.set(i, 5, Color::Alpha.new(255))
      end

      Draw.draw_mask(dst, rect(5, 5, 15, 15), src, Point.zero, mask, Point.zero, Draw::Op::OVER)

      # Should have drawn black pixels
      color = dst.at(5, 10).as(Color::RGBA)
      color.r.should be < 50
    end

    it "handles overlapping source and destination" do
      img = RGBA.new(rect(0, 0, 20, 20))
      img.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

      # Copy from one part to another (overlapping)
      Draw.draw(img, rect(10, 10, 15, 15), img, Point.new(5, 5), Draw::Op::SRC)

      # Should have copied the pixel
      color = img.at(10, 10).as(Color::RGBA)
      color.r.should eq(255)
    end

    it "clips drawing to destination bounds" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = Uniform.new(Color::RGBA.new(255, 0, 0, 255))

      # Try to draw outside bounds
      Draw.draw(dst, rect(-5, -5, 15, 15), src, Point.zero, Draw::Op::SRC)

      # Should only draw within bounds
      dst.at(0, 0).as(Color::RGBA).r.should eq(255)
    end

    it "draws with Uniform source" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = Uniform.new(Color::RGBA.new(128, 128, 128, 255))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::SRC)

      # All pixels should be gray
      dst.at(5, 5).as(Color::RGBA).r.should eq(128)
    end

    it "draws with semi-transparent Uniform source" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      dst.set(5, 5, Color::RGBA.new(255, 255, 255, 255))

      src = Uniform.new(Color::RGBA.new(0, 0, 0, 128))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::OVER)

      # Should blend
      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should be > 0
      color.r.should be < 255
    end

    it "handles empty rectangle" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = Uniform.new(Color::RGBA.new(255, 0, 0, 255))

      # Empty rectangle should do nothing
      Draw.draw(dst, rect(5, 5, 5, 5), src, Point.zero, Draw::Op::SRC)

      # Destination should be unchanged
      dst.at(5, 5).as(Color::RGBA).r.should eq(0)
    end

    it "draws to Paletted destination" do
      palette = Color::Palette.new([
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ])
      dst = Paletted.new(rect(0, 0, 10, 10), palette)
      src = Uniform.new(Color::RGBA.new(255, 255, 255, 255))

      Draw.draw(dst, dst.bounds, src, Point.zero, Draw::Op::SRC)

      # Should have drawn white
      idx = dst.color_index_at(5, 5)
      idx.should eq(1)
    end
  end

  describe "Rectangle Drawing" do
    it "draws simple filled rectangle" do
      img = CrImage.rgba(50, 50)
      style = Draw::RectStyle.new(fill_color: Color::RED)

      Draw.rectangle(img, rect(10, 10, 30, 30), style)

      # Center should be red
      color = img.at(20, 20).as(Color::RGBA)
      color.r.should eq(255)
      color.g.should eq(0)
    end

    it "draws rectangle outline" do
      img = CrImage.rgba(50, 50)
      style = Draw::RectStyle.new(outline_color: Color::BLUE)

      Draw.rectangle(img, rect(10, 10, 30, 30), style)

      # Edge should be blue
      color = img.at(10, 10).as(Color::RGBA)
      color.b.should eq(255)

      # Center should be transparent
      center = img.at(20, 20).as(Color::RGBA)
      center.a.should eq(0)
    end

    it "draws rounded rectangle" do
      img = CrImage.rgba(50, 50)
      style = Draw::RectStyle.new(fill_color: Color::GREEN, corner_radius: 5)

      Draw.rectangle(img, rect(10, 10, 40, 40), style)

      # Center should be green
      color = img.at(25, 25).as(Color::RGBA)
      color.g.should eq(255)

      # Corner should be transparent (rounded off)
      corner = img.at(10, 10).as(Color::RGBA)
      corner.a.should eq(0)
    end

    it "draws rounded rectangle outline" do
      img = CrImage.rgba(50, 50)
      style = Draw::RectStyle.new(outline_color: Color::RED, corner_radius: 5)

      Draw.rectangle(img, rect(10, 10, 40, 40), style)

      # Middle of top edge should be red
      color = img.at(25, 10).as(Color::RGBA)
      color.r.should eq(255)
    end
  end

  describe "Dashed Line Drawing" do
    it "draws dashed line" do
      img = CrImage.rgba(100, 20)
      style = Draw::DashedLineStyle.new(Color::RED, dash_length: 5, gap_length: 3)

      Draw.dashed_line(img, Point.new(0, 10), Point.new(99, 10), style)

      # Some pixels should be red (dashes)
      has_red = false
      has_gap = false
      100.times do |x|
        color = img.at(x, 10).as(Color::RGBA)
        if color.r == 255
          has_red = true
        elsif color.a == 0
          has_gap = true
        end
      end

      has_red.should be_true
      has_gap.should be_true
    end

    it "creates dotted line preset" do
      style = Draw::DashedLineStyle.dotted(Color::BLUE)
      style.dash_length.should eq(1)
      style.gap_length.should eq(2)
    end

    it "creates dashed line preset" do
      style = Draw::DashedLineStyle.dashed(Color::BLUE)
      style.dash_length.should eq(5)
      style.gap_length.should eq(3)
    end
  end

  describe "Arc Drawing" do
    it "draws arc" do
      img = CrImage.rgba(100, 100)
      style = Draw::ArcStyle.new(Color::RED)

      # Draw quarter circle (0 to PI/2)
      Draw.arc(img, Point.new(50, 50), 30, 0.0, ::Math::PI / 2, style)

      # Should have some red pixels
      has_red = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.r == 255
            has_red = true
            break
          end
        end
        break if has_red
      end

      has_red.should be_true
    end

    it "draws pie slice" do
      img = CrImage.rgba(100, 100)
      style = Draw::ArcStyle.new(Color::GREEN, fill: true)

      # Draw quarter pie
      Draw.pie(img, Point.new(50, 50), 30, 0.0, ::Math::PI / 2, style)

      # Center-right area should be green (in the pie)
      color = img.at(65, 55).as(Color::RGBA)
      color.g.should eq(255)
    end

    it "draws pie outline only" do
      img = CrImage.rgba(100, 100)
      style = Draw::ArcStyle.new(Color::BLUE, fill: false)

      Draw.pie(img, Point.new(50, 50), 30, 0.0, ::Math::PI / 2, style)

      # Should have blue outline
      has_blue = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.b == 255
            has_blue = true
            break
          end
        end
        break if has_blue
      end

      has_blue.should be_true
    end
  end

  describe "Thick Circle Drawing" do
    it "draws thick circle outline" do
      img = CrImage.rgba(100, 100)
      style = Draw::CircleStyle.new(Color::RED, fill: false, thickness: 5)

      Draw.circle(img, Point.new(50, 50), 30, style)

      # Should have red pixels at the circle edge
      color = img.at(80, 50).as(Color::RGBA)
      color.r.should eq(255)

      # Center should be transparent (not filled)
      center = img.at(50, 50).as(Color::RGBA)
      center.a.should eq(0)
    end

    it "draws thick circle with builder pattern" do
      img = CrImage.rgba(100, 100)
      style = Draw::CircleStyle.new(Color::BLUE).with_thickness(3)

      Draw.circle(img, Point.new(50, 50), 25, style)

      # Should have blue pixels
      has_blue = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.b == 255
            has_blue = true
            break
          end
        end
        break if has_blue
      end

      has_blue.should be_true
    end
  end

  describe "Regular Polygon Drawing" do
    it "draws equilateral triangle" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(outline_color: Color::RED)

      Draw.triangle(img, Point.new(50, 50), 30, style)

      # Should have red pixels
      has_red = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.r == 255
            has_red = true
            break
          end
        end
        break if has_red
      end

      has_red.should be_true
    end

    it "draws filled hexagon" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(fill_color: Color::GREEN)

      Draw.hexagon(img, Point.new(50, 50), 30, style)

      # Center should be green
      color = img.at(50, 50).as(Color::RGBA)
      color.g.should eq(255)
    end

    it "draws pentagon with outline and fill" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(outline_color: Color::BLUE, fill_color: Color::RED)

      Draw.pentagon(img, Point.new(50, 50), 25, style)

      # Center should be red (fill)
      center = img.at(50, 50).as(Color::RGBA)
      center.r.should eq(255)
    end

    it "draws regular polygon with custom sides" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(outline_color: Color::WHITE)

      # Draw octagon
      Draw.regular_polygon(img, Point.new(50, 50), 30, 8, style)

      # Should have white pixels
      has_white = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.r == 255 && color.g == 255 && color.b == 255
            has_white = true
            break
          end
        end
        break if has_white
      end

      has_white.should be_true
    end

    it "raises error for invalid sides" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(outline_color: Color::RED)

      expect_raises(ArgumentError) do
        Draw.regular_polygon(img, Point.new(50, 50), 30, 2, style)
      end
    end

    it "raises error for negative radius" do
      img = CrImage.rgba(100, 100)
      style = Draw::PolygonStyle.new(outline_color: Color::RED)

      expect_raises(ArgumentError) do
        Draw.regular_polygon(img, Point.new(50, 50), -10, 5, style)
      end
    end
  end

  describe "Bezier Curve Drawing" do
    it "draws quadratic bezier curve" do
      img = CrImage.rgba(100, 100)
      style = Draw::BezierStyle.new(Color::RED)

      Draw.quadratic_bezier(
        img,
        Point.new(10, 50), # start
        Point.new(50, 10), # control
        Point.new(90, 50), # end
        style
      )

      # Should have red pixels
      has_red = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.r == 255
            has_red = true
            break
          end
        end
        break if has_red
      end

      has_red.should be_true
    end

    it "draws cubic bezier curve" do
      img = CrImage.rgba(100, 100)
      style = Draw::BezierStyle.new(Color::BLUE, thickness: 2)

      Draw.cubic_bezier(
        img,
        Point.new(10, 50), # start
        Point.new(30, 10), # control 1
        Point.new(70, 90), # control 2
        Point.new(90, 50), # end
        style
      )

      # Should have blue pixels
      has_blue = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.b == 255
            has_blue = true
            break
          end
        end
        break if has_blue
      end

      has_blue.should be_true
    end

    it "draws spline through points" do
      img = CrImage.rgba(100, 100)
      style = Draw::BezierStyle.new(Color::GREEN)

      points = [
        Point.new(10, 50),
        Point.new(30, 20),
        Point.new(50, 80),
        Point.new(70, 30),
        Point.new(90, 50),
      ]

      Draw.spline(img, points, style)

      # Should have green pixels
      has_green = false
      100.times do |y|
        100.times do |x|
          color = img.at(x, y).as(Color::RGBA)
          if color.g == 255
            has_green = true
            break
          end
        end
        break if has_green
      end

      has_green.should be_true
    end

    it "handles spline with only 2 points" do
      img = CrImage.rgba(100, 100)
      style = Draw::BezierStyle.new(Color::RED)

      points = [Point.new(10, 10), Point.new(90, 90)]
      Draw.spline(img, points, style)

      # Should draw a straight line
      color = img.at(50, 50).as(Color::RGBA)
      color.r.should eq(255)
    end

    it "uses BezierStyle builder pattern" do
      style = Draw::BezierStyle.new(Color::RED)
        .with_thickness(3)
        .with_anti_alias(true)
        .with_segments(100)

      style.thickness.should eq(3)
      style.anti_alias.should be_true
      style.segments.should eq(100)
    end
  end

  describe "Drawing methods with Point overloads" do
    describe "#draw_line" do
      it "draws line using Point objects" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        p1 = Point.new(10, 10)
        p2 = Point.new(90, 90)
        
        img.draw_line(p1, p2, color: CrImage::Color::RED, thickness: 2)
        
        pixel = img.at(50, 50)
        r, g, b, a = pixel.rgba
        (r >> 8).should eq 255
        (g >> 8).should eq 0
        (b >> 8).should eq 0
        (a >> 8).should eq 255
      end

      it "produces same result for Point, tuple, and coordinate formats" do
        img1 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        img2 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        img3 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        
        color = CrImage::Color::RGBA.new(128_u8, 64_u8, 192_u8, 255_u8)
        
        img1.draw_line(Point.new(20, 30), Point.new(80, 70), color: color, thickness: 3)
        img2.draw_line(20, 30, 80, 70, color: color, thickness: 3)
        img3.draw_line({20, 30}, {80, 70}, color: color, thickness: 3)
        
        img1.at(50, 50).should eq img2.at(50, 50)
        img2.at(50, 50).should eq img3.at(50, 50)
      end
    end

    describe "#draw_circle" do
      it "draws circle using Point object" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        center = Point.new(50, 50)
        
        img.draw_circle(center, 20, color: CrImage::Color::RED, fill: true)
        
        pixel = img.at(50, 50)
        r, g, b, _ = pixel.rgba
        (r >> 8).should eq 255
        (g >> 8).should eq 0
        (b >> 8).should eq 0
      end

      it "produces same result for Point and coordinate formats" do
        img1 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        img2 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        
        color = CrImage::Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8)
        
        img1.draw_circle(Point.new(50, 50), 25, color: color, fill: true)
        img2.draw_circle(50, 50, 25, color: color, fill: true)
        
        img1.at(50, 50).should eq img2.at(50, 50)
      end
    end

    describe "#draw_ellipse" do
      it "draws ellipse using Point object" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        center = Point.new(50, 50)
        
        img.draw_ellipse(center, 30, 20, color: CrImage::Color::GREEN, fill: true)
        
        pixel = img.at(50, 50)
        r, g, b, _ = pixel.rgba
        (r >> 8).should eq 0
        (g >> 8).should eq 255
        (b >> 8).should eq 0
      end

      it "produces same result for Point and coordinate formats" do
        img1 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        img2 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        
        color = CrImage::Color::RGBA.new(200_u8, 100_u8, 50_u8, 255_u8)
        
        img1.draw_ellipse(Point.new(50, 50), 35, 25, color: color, fill: true)
        img2.draw_ellipse(50, 50, 35, 25, color: color, fill: true)
        
        img1.at(50, 50).should eq img2.at(50, 50)
      end
    end

    describe "#draw_rect" do
      it "draws rectangle using Point object" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        top_left = Point.new(20, 20)
        
        img.draw_rect(top_left, 40, 30, fill: CrImage::Color::RED)
        
        pixel = img.at(40, 35)
        r, g, b, _ = pixel.rgba
        (r >> 8).should eq 255
        (g >> 8).should eq 0
        (b >> 8).should eq 0
      end

      it "produces same result for Point and coordinate formats" do
        img1 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        img2 = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        
        color = CrImage::Color::RGBA.new(150_u8, 200_u8, 100_u8, 255_u8)
        
        img1.draw_rect(Point.new(10, 15), 50, 40, fill: color)
        img2.draw_rect(10, 15, 50, 40, fill: color)
        
        img1.at(35, 35).should eq img2.at(35, 35)
      end

      it "draws rectangle with stroke using Point object" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
        top_left = Point.new(20, 20)
        
        img.draw_rect(top_left, 40, 30, stroke: CrImage::Color::BLACK, fill: CrImage::Color::YELLOW)
        
        pixel_edge = img.at(20, 20)
        r, g, b, _ = pixel_edge.rgba
        (r >> 8).should eq 0
        (g >> 8).should eq 0
        (b >> 8).should eq 0
        
        pixel_center = img.at(40, 35)
        r, g, b, _ = pixel_center.rgba
        (r >> 8).should eq 255
        (g >> 8).should eq 255
        (b >> 8).should eq 0
      end
    end

    describe "real-world use case: polyline with Point objects" do
      it "allows drawing line segments from collected Points" do
        img = CrImage.rgba(200, 200, CrImage::Color::WHITE)
        
        points = [
          Point.new(10, 10),
          Point.new(50, 100),
          Point.new(100, 50),
          Point.new(150, 150),
          Point.new(190, 10),
        ]
        
        (0...points.size - 1).each do |i|
          img.draw_line(points[i], points[i + 1], color: CrImage::Color::BLUE, thickness: 2)
        end
        
        pixel1 = img.at(30, 55)
        r, g, b, _ = pixel1.rgba
        b8 = (b >> 8)
        b8.should be > 200
      end
    end
  end
end
