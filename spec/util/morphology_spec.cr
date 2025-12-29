require "../spec_helper"

describe CrImage::Util::Morphology do
  describe "erosion" do
    it "erodes bright regions" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)

      eroded = img.erode(3)
      eroded.should be_a(CrImage::Gray)
      eroded.bounds.width.should eq(50)
      eroded.bounds.height.should eq(50)
    end

    it "removes small bright spots" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLACK)
      # Add small white spot
      img.draw_circle(25, 25, 2, color: CrImage::Color::WHITE, fill: true)

      eroded = img.erode(5)
      # Small spot should be removed
      center = eroded.at(25, 25).as(CrImage::Color::Gray)
      center.y.should be < 50
    end

    it "validates kernel size" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        img.erode(0)
      end
      expect_raises(ArgumentError) do
        img.erode(4) # Must be odd
      end
    end
  end

  describe "dilation" do
    it "dilates bright regions" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLACK)
      img.draw_circle(25, 25, 10, color: CrImage::Color::WHITE, fill: true)

      dilated = img.dilate(3)
      dilated.should be_a(CrImage::Gray)
    end

    it "fills small gaps" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      # Add small black spot
      img.draw_circle(25, 25, 2, color: CrImage::Color::BLACK, fill: true)

      dilated = img.dilate(5)
      # Gap should be filled
      center = dilated.at(25, 25).as(CrImage::Color::Gray)
      center.y.should be > 200
    end
  end

  describe "opening" do
    it "removes noise while preserving shape" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLACK)
      img.draw_circle(25, 25, 15, color: CrImage::Color::WHITE, fill: true)
      # Add noise
      img.draw_circle(10, 10, 1, color: CrImage::Color::WHITE, fill: true)

      opened = img.morphology_open(3)
      opened.should be_a(CrImage::Gray)
    end
  end

  describe "closing" do
    it "fills gaps while preserving shape" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)
      # Add gap
      img.draw_circle(25, 25, 2, color: CrImage::Color::WHITE, fill: true)

      closed = img.morphology_close(3)
      closed.should be_a(CrImage::Gray)
    end
  end

  describe "gradient" do
    it "highlights edges" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
      img.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)

      gradient = img.morphology_gradient(3)
      gradient.should be_a(CrImage::Gray)

      # Edges should have high values
      edge_pixel = gradient.at(25, 10).as(CrImage::Color::Gray)
      edge_pixel.y.should be > 50
    end
  end

  describe "structuring elements" do
    it "works with rectangle shape" do
      img = CrImage.rgba(30, 30, CrImage::Color::WHITE)
      img.draw_rect(10, 10, 10, 10, fill: CrImage::Color::BLACK)

      eroded = img.erode(3, CrImage::Util::StructuringElement::Rectangle)
      eroded.should be_a(CrImage::Gray)
    end

    it "works with cross shape" do
      img = CrImage.rgba(30, 30, CrImage::Color::WHITE)
      img.draw_rect(10, 10, 10, 10, fill: CrImage::Color::BLACK)

      eroded = img.erode(3, CrImage::Util::StructuringElement::Cross)
      eroded.should be_a(CrImage::Gray)
    end

    it "works with ellipse shape" do
      img = CrImage.rgba(30, 30, CrImage::Color::WHITE)
      img.draw_circle(15, 15, 10, color: CrImage::Color::BLACK, fill: true)

      eroded = img.erode(3, CrImage::Util::StructuringElement::Ellipse)
      eroded.should be_a(CrImage::Gray)
    end
  end
end
