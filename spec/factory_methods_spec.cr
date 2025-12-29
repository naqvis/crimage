require "./spec_helper"

describe CrImage do
  describe ".checkerboard" do
    it "creates checkerboard pattern" do
      img = CrImage.checkerboard(20, 20, cell_size: 5)

      img.bounds.width.should eq(20)
      img.bounds.height.should eq(20)

      # First cell should be color1 (light gray)
      c1 = img.at(0, 0).as(CrImage::Color::RGBA)
      c1.r.should eq(204)

      # Second cell should be color2 (white)
      c2 = img.at(5, 0).as(CrImage::Color::RGBA)
      c2.r.should eq(255)
    end

    it "uses custom colors" do
      img = CrImage.checkerboard(20, 20, cell_size: 10,
        color1: CrImage::Color::RED,
        color2: CrImage::Color::BLUE)

      c1 = img.at(0, 0).as(CrImage::Color::RGBA)
      c1.r.should eq(255)
      c1.b.should eq(0)

      c2 = img.at(10, 0).as(CrImage::Color::RGBA)
      c2.r.should eq(0)
      c2.b.should eq(255)
    end
  end

  describe ".gradient" do
    it "creates horizontal gradient" do
      img = CrImage.gradient(100, 50, CrImage::Color::BLACK, CrImage::Color::WHITE, :horizontal)

      img.bounds.width.should eq(100)

      # Left should be dark
      left = img.at(0, 25).as(CrImage::Color::RGBA)
      left.r.should be < 50

      # Right should be light
      right = img.at(99, 25).as(CrImage::Color::RGBA)
      right.r.should be > 200
    end

    it "creates vertical gradient" do
      img = CrImage.gradient(50, 100, CrImage::Color::RED, CrImage::Color::BLUE, :vertical)

      # Top should be red
      top = img.at(25, 0).as(CrImage::Color::RGBA)
      top.r.should be > 200

      # Bottom should be blue
      bottom = img.at(25, 99).as(CrImage::Color::RGBA)
      bottom.b.should be > 200
    end

    it "creates diagonal gradient" do
      img = CrImage.gradient(100, 100, CrImage::Color::GREEN, CrImage::Color::WHITE, :diagonal)

      img.bounds.width.should eq(100)
    end
  end

  describe ".rect" do
    it "creates rectangle from coordinates" do
      r = CrImage.rect(10, 20, 100, 200)

      r.min.x.should eq(10)
      r.min.y.should eq(20)
      r.max.x.should eq(100)
      r.max.y.should eq(200)
      r.width.should eq(90)
      r.height.should eq(180)
    end
  end

  describe ".point" do
    it "creates point from coordinates" do
      p = CrImage.point(50, 100)
      p.x.should eq(50)
      p.y.should eq(100)
    end

    it "creates point from tuple" do
      p = CrImage.point({25, 75})
      p.x.should eq(25)
      p.y.should eq(75)
    end
  end
end
