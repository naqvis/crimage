require "../spec_helper"

describe CrImage::Util::Stacking do
  describe ".stack_horizontal" do
    it "stacks images horizontally" do
      img1 = CrImage.rgba(50, 100, CrImage::Color::RED)
      img2 = CrImage.rgba(60, 100, CrImage::Color::GREEN)
      img3 = CrImage.rgba(40, 100, CrImage::Color::BLUE)

      stacked = CrImage::Util::Stacking.stack_horizontal([img1, img2, img3])

      bounds = stacked.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(150) # 50 + 60 + 40
      height.should eq(100)
    end

    it "adds spacing between images" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(50, 50)

      stacked = CrImage::Util::Stacking.stack_horizontal([img1, img2], spacing: 10)

      bounds = stacked.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(110) # 50 + 10 + 50
    end

    it "aligns images vertically" do
      img1 = CrImage.rgba(50, 100, CrImage::Color::RED)
      img2 = CrImage.rgba(50, 50, CrImage::Color::GREEN)

      # Center alignment (default)
      stacked = CrImage::Util::Stacking.stack_horizontal([img1, img2])
      bounds = stacked.bounds
      height = bounds.max.y - bounds.min.y
      height.should eq(100)

      # Top alignment
      stacked_top = CrImage::Util::Stacking.stack_horizontal([img1, img2],
        alignment: CrImage::Util::VerticalAlignment::Top)
      bounds = stacked_top.bounds
      height = bounds.max.y - bounds.min.y
      height.should eq(100)
    end

    it "raises on empty array" do
      expect_raises(ArgumentError, "images array cannot be empty") do
        CrImage::Util::Stacking.stack_horizontal([] of CrImage::Image)
      end
    end

    it "raises on negative spacing" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "spacing must be non-negative") do
        CrImage::Util::Stacking.stack_horizontal([img], spacing: -1)
      end
    end
  end

  describe ".stack_vertical" do
    it "stacks images vertically" do
      img1 = CrImage.rgba(100, 50, CrImage::Color::RED)
      img2 = CrImage.rgba(100, 60, CrImage::Color::GREEN)
      img3 = CrImage.rgba(100, 40, CrImage::Color::BLUE)

      stacked = CrImage::Util::Stacking.stack_vertical([img1, img2, img3])

      bounds = stacked.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(100)
      height.should eq(150) # 50 + 60 + 40
    end

    it "adds spacing between images" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(50, 50)

      stacked = CrImage::Util::Stacking.stack_vertical([img1, img2], spacing: 10)

      bounds = stacked.bounds
      height = bounds.max.y - bounds.min.y

      height.should eq(110) # 50 + 10 + 50
    end

    it "raises on empty array" do
      expect_raises(ArgumentError) do
        CrImage::Util::Stacking.stack_vertical([] of CrImage::Image)
      end
    end
  end

  describe ".compare_images" do
    it "creates before/after comparison" do
      before = CrImage.rgba(100, 100, CrImage::Color::RED)
      after = CrImage.rgba(100, 100, CrImage::Color::GREEN)

      comparison = CrImage::Util::Stacking.compare_images(before, after)

      bounds = comparison.bounds
      width = bounds.max.x - bounds.min.x

      width.should be > 200 # Two images plus spacing
    end

    it "adds divider line" do
      before = CrImage.rgba(100, 100, CrImage::Color::RED)
      after = CrImage.rgba(100, 100, CrImage::Color::GREEN)

      comparison = CrImage::Util::Stacking.compare_images(before, after, divider: true)

      bounds = comparison.bounds
      width = bounds.max.x - bounds.min.x

      width.should be > 200
    end

    it "raises on invalid divider width" do
      before = CrImage.rgba(10, 10)
      after = CrImage.rgba(10, 10)

      expect_raises(ArgumentError) do
        CrImage::Util::Stacking.compare_images(before, after, divider: true, divider_width: 0)
      end
    end
  end

  describe ".create_grid" do
    it "creates grid layout" do
      images = (0...6).map { CrImage.rgba(50, 50) }.to_a

      grid = CrImage::Util::Stacking.create_grid(images, cols: 3)

      bounds = grid.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      # 3 cols * 50 + 2 spacings * 10
      width.should eq(170)
      # 2 rows * 50 + 1 spacing * 10
      height.should eq(110)
    end

    it "handles incomplete last row" do
      images = (0...5).map { CrImage.rgba(40, 40) }.to_a

      grid = CrImage::Util::Stacking.create_grid(images, cols: 3, spacing: 5)

      bounds = grid.bounds
      width = bounds.max.x - bounds.min.x

      # 3 cols * 40 + 2 spacings * 5
      width.should eq(130)
    end

    it "raises on empty array" do
      expect_raises(ArgumentError) do
        CrImage::Util::Stacking.create_grid([] of CrImage::Image, cols: 2)
      end
    end

    it "raises on invalid cols" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        CrImage::Util::Stacking.create_grid([img], cols: 0)
      end
    end
  end

  describe "CrImage convenience methods" do
    it "works with stack_horizontal" do
      img1 = CrImage.rgba(30, 30)
      img2 = CrImage.rgba(30, 30)

      stacked = CrImage.stack_horizontal([img1, img2])

      bounds = stacked.bounds
      width = bounds.max.x - bounds.min.x

      width.should be >= 60
    end

    it "works with stack_vertical" do
      img1 = CrImage.rgba(30, 30)
      img2 = CrImage.rgba(30, 30)

      stacked = CrImage.stack_vertical([img1, img2])

      bounds = stacked.bounds
      height = bounds.max.y - bounds.min.y

      height.should be >= 60
    end

    it "works with compare_images" do
      before = CrImage.rgba(50, 50)
      after = CrImage.rgba(50, 50)

      comparison = CrImage.compare_images(before, after)

      bounds = comparison.bounds
      width = bounds.max.x - bounds.min.x

      width.should be > 100
    end

    it "works with create_grid" do
      images = (0...4).map { CrImage.rgba(25, 25) }.to_a

      grid = CrImage.create_grid(images, cols: 2)

      bounds = grid.bounds
      width = bounds.max.x - bounds.min.x

      width.should be >= 50
    end
  end
end
