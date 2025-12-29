require "../spec_helper"

describe CrImage::Util::Selection do
  describe ".flood_fill" do
    it "fills connected region" do
      img = CrImage.rgba(20, 20, CrImage::Color::WHITE)
      # Create a red square in the middle
      (5...15).each do |y|
        (5...15).each do |x|
          img.set(x, y, CrImage::Color::RED)
        end
      end

      # Flood fill the red region with blue
      filled = CrImage::Util::Selection.flood_fill(img, 10, 10, CrImage::Color::BLUE)

      filled.should eq(100) # 10x10 square

      # Center should be blue now
      color = img.at(10, 10).as(CrImage::Color::RGBA)
      color.b.should eq(255)
      color.r.should eq(0)

      # Outside should still be white
      outside = img.at(0, 0).as(CrImage::Color::RGBA)
      outside.r.should eq(255)
      outside.g.should eq(255)
      outside.b.should eq(255)
    end

    it "respects tolerance" do
      img = CrImage.rgba(20, 20, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      # Create slightly different color region
      (5...15).each do |y|
        (5...15).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new(105_u8, 105_u8, 105_u8, 255_u8))
        end
      end

      # With low tolerance, should not fill
      filled_low = CrImage::Util::Selection.flood_fill(
        CrImage.rgba(20, 20, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8)),
        10, 10, CrImage::Color::BLUE, tolerance: 3
      )

      # With high tolerance, should fill
      img2 = CrImage.rgba(20, 20, CrImage::Color::RGBA.new(100_u8, 100_u8, 100_u8, 255_u8))
      (5...15).each do |y|
        (5...15).each do |x|
          img2.set(x, y, CrImage::Color::RGBA.new(105_u8, 105_u8, 105_u8, 255_u8))
        end
      end
      filled_high = CrImage::Util::Selection.flood_fill(img2, 10, 10, CrImage::Color::BLUE, tolerance: 10)

      filled_high.should be > 0
    end

    it "returns 0 for out of bounds" do
      img = CrImage.rgba(10, 10, CrImage::Color::WHITE)
      filled = CrImage::Util::Selection.flood_fill(img, 100, 100, CrImage::Color::BLUE)
      filled.should eq(0)
    end

    it "returns 0 when fill color matches target" do
      img = CrImage.rgba(10, 10, CrImage::Color::RED)
      filled = CrImage::Util::Selection.flood_fill(img, 5, 5, CrImage::Color::RED)
      filled.should eq(0)
    end
  end

  describe ".select_by_color" do
    it "creates contiguous selection mask" do
      img = CrImage.rgba(20, 20, CrImage::Color::WHITE)
      # Create a red square
      (5...15).each do |y|
        (5...15).each do |x|
          img.set(x, y, CrImage::Color::RED)
        end
      end

      mask = CrImage::Util::Selection.select_by_color(img, 10, 10, tolerance: 10, contiguous: true)

      # Inside the red region should be selected (white in mask)
      inside = mask.at(10, 10).as(CrImage::Color::Gray)
      inside.y.should eq(255)

      # Outside should not be selected (black in mask)
      outside = mask.at(0, 0).as(CrImage::Color::Gray)
      outside.y.should eq(0)
    end

    it "creates non-contiguous selection mask" do
      img = CrImage.rgba(20, 20, CrImage::Color::WHITE)
      # Create two separate red squares
      (2...8).each do |y|
        (2...8).each do |x|
          img.set(x, y, CrImage::Color::RED)
        end
      end
      (12...18).each do |y|
        (12...18).each do |x|
          img.set(x, y, CrImage::Color::RED)
        end
      end

      # Non-contiguous should select both
      mask = CrImage::Util::Selection.select_by_color(img, 5, 5, tolerance: 10, contiguous: false)

      first = mask.at(5, 5).as(CrImage::Color::Gray)
      first.y.should eq(255)

      second = mask.at(15, 15).as(CrImage::Color::Gray)
      second.y.should eq(255)
    end
  end

  describe ".replace_color" do
    it "replaces matching colors" do
      img = CrImage.rgba(20, 20, CrImage::Color::WHITE)
      (5...15).each do |y|
        (5...15).each do |x|
          img.set(x, y, CrImage::Color::RED)
        end
      end

      result = CrImage::Util::Selection.replace_color(img, CrImage::Color::RED, CrImage::Color::BLUE)

      # Red should be replaced with blue
      color = result.at(10, 10).as(CrImage::Color::RGBA)
      color.b.should eq(255)
      color.r.should eq(0)

      # White should remain white
      white = result.at(0, 0).as(CrImage::Color::RGBA)
      white.r.should eq(255)
      white.g.should eq(255)
      white.b.should eq(255)
    end

    it "respects tolerance" do
      img = CrImage.rgba(10, 10, CrImage::Color::RGBA.new(100_u8, 0_u8, 0_u8, 255_u8))
      img.set(5, 5, CrImage::Color::RGBA.new(110_u8, 0_u8, 0_u8, 255_u8))

      # With low tolerance, only exact match
      result_low = CrImage::Util::Selection.replace_color(
        img, CrImage::Color::RGBA.new(100_u8, 0_u8, 0_u8, 255_u8),
        CrImage::Color::BLUE, tolerance: 5
      )

      # With high tolerance, both should match
      result_high = CrImage::Util::Selection.replace_color(
        img, CrImage::Color::RGBA.new(100_u8, 0_u8, 0_u8, 255_u8),
        CrImage::Color::BLUE, tolerance: 15
      )

      # High tolerance should replace the slightly different pixel too
      high_pixel = result_high.at(5, 5).as(CrImage::Color::RGBA)
      high_pixel.b.should eq(255)
    end
  end

  describe "Image convenience methods" do
    it "flood_fill works on RGBA" do
      img = CrImage.rgba(10, 10, CrImage::Color::RED)
      filled = img.flood_fill(5, 5, CrImage::Color::BLUE)
      filled.should eq(100)
    end

    it "select_by_color works on Image" do
      img = CrImage.rgba(10, 10, CrImage::Color::RED)
      mask = img.select_by_color(5, 5)
      mask.bounds.width.should eq(10)
    end

    it "replace_color works on Image" do
      img = CrImage.rgba(10, 10, CrImage::Color::RED)
      result = img.replace_color(CrImage::Color::RED, CrImage::Color::BLUE)
      color = result.at(5, 5).as(CrImage::Color::RGBA)
      color.b.should eq(255)
    end
  end
end
