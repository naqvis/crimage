require "../spec_helper"

describe CrImage::Transform do
  describe "edge detection" do
    it "detects edges with Sobel operator" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      img.draw_rect(25, 25, 50, 50, fill: CrImage::Color::BLACK)

      edges = img.sobel
      edges.should be_a(CrImage::Gray)
      edges.bounds.width.should eq(100)
      edges.bounds.height.should eq(100)

      # Edges should be detected at boundaries
      # Center of black square should have low edge values
      center_pixel = edges.at(50, 50).as(CrImage::Color::Gray)
      center_pixel.y.should be < 50

      # Edge of square should have high edge values
      edge_pixel = edges.at(25, 25).as(CrImage::Color::Gray)
      edge_pixel.y.should be > 100
    end

    it "detects edges with Prewitt operator" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)

      edges = img.prewitt
      edges.should be_a(CrImage::Gray)
      edges.bounds.width.should eq(50)
      edges.bounds.height.should eq(50)
    end

    it "detects edges with Roberts operator" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_line(10, 10, 40, 40, color: CrImage::Color::BLACK, thickness: 3)

      edges = img.roberts
      edges.should be_a(CrImage::Gray)
    end

    it "detects edges with Scharr operator" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_rect(10, 10, 30, 30, fill: CrImage::Color::BLACK)

      edges = img.detect_edges(CrImage::Transform::EdgeOperator::Scharr)
      edges.should be_a(CrImage::Gray)
    end

    it "creates binary edge map with threshold" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      img.draw_rect(25, 25, 50, 50, fill: CrImage::Color::BLACK)

      binary = img.sobel(threshold: 50)
      binary.should be_a(CrImage::Gray)

      # Binary output should only have 0 or 255 values
      has_intermediate = false
      10.times do |y|
        10.times do |x|
          pixel = binary.at(x + 40, y + 40).as(CrImage::Color::Gray)
          if pixel.y != 0 && pixel.y != 255
            has_intermediate = true
          end
        end
      end
      has_intermediate.should be_false
    end

    it "validates threshold parameter" do
      img = CrImage.rgba(50, 50)
      expect_raises(ArgumentError) do
        img.sobel(threshold: -1)
      end
      expect_raises(ArgumentError) do
        img.sobel(threshold: 256)
      end
    end

    it "handles edge cases" do
      # Empty image
      img = CrImage.rgba(10, 10, CrImage::Color::WHITE)
      edges = img.sobel
      edges.should be_a(CrImage::Gray)

      # Single color image should have no edges
      all_low = true
      10.times do |y|
        10.times do |x|
          pixel = edges.at(x, y).as(CrImage::Color::Gray)
          all_low = false if pixel.y > 10
        end
      end
      all_low.should be_true
    end
  end
end
