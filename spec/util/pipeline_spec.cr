require "../spec_helper"

describe CrImage::Pipeline do
  describe "basic operations" do
    it "creates pipeline from image" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      pipeline = CrImage::Pipeline.new(img)
      result = pipeline.result

      result.bounds.width.should eq(100)
      result.bounds.height.should eq(100)
    end

    it "chains resize operations" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .resize(50, 50)
        .result

      result.bounds.width.should eq(50)
      result.bounds.height.should eq(50)
    end

    it "chains scale operations" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .scale(0.5)
        .result

      result.bounds.width.should eq(50)
      result.bounds.height.should eq(50)
    end

    it "chains crop operations" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .crop(10, 10, 50, 50)
        .result

      result.bounds.width.should eq(50)
      result.bounds.height.should eq(50)
    end

    it "chains rotate operations" do
      img = CrImage.rgba(100, 50, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .rotate(90)
        .result

      result.bounds.width.should eq(50)
      result.bounds.height.should eq(100)
    end

    it "chains flip operations" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .flip_horizontal
        .flip_vertical
        .result

      result.bounds.width.should eq(100)
    end
  end

  describe "color adjustments" do
    it "chains brightness adjustment" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      result = CrImage::Pipeline.new(img)
        .brightness(50)
        .result

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should be > 100
    end

    it "chains contrast adjustment" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      result = CrImage::Pipeline.new(img)
        .contrast(1.5)
        .result

      result.bounds.width.should eq(10)
    end

    it "chains grayscale conversion" do
      img = CrImage.rgba(10, 10, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .grayscale
        .result

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      # Grayscale should have equal R, G, B
      color.r.should eq(color.g)
      color.g.should eq(color.b)
    end

    it "chains invert" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      result = CrImage::Pipeline.new(img)
        .invert
        .result

      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.r.should eq(155)
    end
  end

  describe "filters" do
    it "chains blur" do
      img = CrImage.rgba(20, 20, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .blur(2)
        .result

      result.bounds.width.should eq(20)
    end

    it "chains sharpen" do
      img = CrImage.rgba(20, 20, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .sharpen(1.0)
        .result

      result.bounds.width.should eq(20)
    end
  end

  describe "effects" do
    it "chains border" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .border(10, CrImage::Color::WHITE)
        .result

      result.bounds.width.should eq(70)
      result.bounds.height.should eq(70)
    end

    it "chains round_corners" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .round_corners(10)
        .result

      # Corner should be transparent
      corner = result.at(0, 0).as(CrImage::Color::RGBA)
      corner.a.should eq(0)
    end
  end

  describe "drawing" do
    it "chains draw_rect" do
      img = CrImage.rgba(50, 50)
      result = CrImage::Pipeline.new(img)
        .draw_rect(10, 10, 20, 20, CrImage::Color::RED)
        .result

      color = result.at(20, 20).as(CrImage::Color::RGBA)
      color.r.should eq(255)
    end

    it "chains draw_circle" do
      img = CrImage.rgba(50, 50)
      result = CrImage::Pipeline.new(img)
        .draw_circle(25, 25, 10, CrImage::Color::GREEN)
        .result

      color = result.at(25, 25).as(CrImage::Color::RGBA)
      color.g.should eq(255)
    end

    it "chains draw_line" do
      img = CrImage.rgba(50, 50)
      result = CrImage::Pipeline.new(img)
        .draw_line(0, 25, 49, 25, CrImage::Color::BLUE)
        .result

      color = result.at(25, 25).as(CrImage::Color::RGBA)
      color.b.should eq(255)
    end

    it "chains draw_dashed_line" do
      img = CrImage.rgba(100, 50)
      result = CrImage::Pipeline.new(img)
        .draw_dashed_line(0, 25, 99, 25, CrImage::Color::RED, dash: 5, gap: 3)
        .result

      # Should have some red pixels (dashes)
      has_red = false
      100.times do |x|
        color = result.at(x, 25).as(CrImage::Color::RGBA)
        if color.r == 255
          has_red = true
          break
        end
      end
      has_red.should be_true
    end

    it "chains draw_rounded_rect" do
      img = CrImage.rgba(100, 100)
      result = CrImage::Pipeline.new(img)
        .draw_rounded_rect(10, 10, 50, 50, CrImage::Color::BLUE, corner_radius: 10)
        .result

      # Center should be blue
      color = result.at(35, 35).as(CrImage::Color::RGBA)
      color.b.should eq(255)

      # Corner should be transparent (rounded off)
      corner = result.at(10, 10).as(CrImage::Color::RGBA)
      corner.a.should eq(0)
    end

    it "chains draw_polygon" do
      img = CrImage.rgba(100, 100)
      result = CrImage::Pipeline.new(img)
        .draw_polygon(50, 50, 30, 6, CrImage::Color::GREEN)
        .result

      # Center should be green
      color = result.at(50, 50).as(CrImage::Color::RGBA)
      color.g.should eq(255)
    end

    it "chains draw_bezier" do
      img = CrImage.rgba(100, 50)
      result = CrImage::Pipeline.new(img)
        .draw_bezier(10, 25, 50, 5, 90, 25, CrImage::Color::RED)
        .result

      # Should have some red pixels
      has_red = false
      50.times do |y|
        100.times do |x|
          color = result.at(x, y).as(CrImage::Color::RGBA)
          if color.r == 255
            has_red = true
            break
          end
        end
        break if has_red
      end
      has_red.should be_true
    end
  end

  describe "custom operations" do
    it "applies custom block" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .apply { |i| i.flip_horizontal }
        .result

      result.bounds.width.should eq(50)
    end
  end

  describe "complex chains" do
    it "chains multiple operations" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = CrImage::Pipeline.new(img)
        .resize(50, 50)
        .brightness(20)
        .border(5, CrImage::Color::WHITE)
        .result

      result.bounds.width.should eq(60)
      result.bounds.height.should eq(60)
    end
  end

  describe "Image convenience method" do
    it "creates pipeline from image" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      result = img.pipeline
        .resize(50, 50)
        .result

      result.bounds.width.should eq(50)
    end
  end
end
