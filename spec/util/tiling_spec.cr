require "../spec_helper"

describe CrImage::Util::Tiling do
  describe ".tile" do
    it "tiles image in grid" do
      img = CrImage.rgba(50, 40, CrImage::Color::RED)
      tiled = CrImage::Util::Tiling.tile(img, 3, 2)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(150) # 50 * 3
      height.should eq(80) # 40 * 2
    end

    it "preserves image content in each tile" do
      img = CrImage.rgba(10, 10, CrImage::Color::BLUE)
      tiled = CrImage::Util::Tiling.tile(img, 2, 2)

      # Check each quadrant is blue
      pixel1 = tiled.at(5, 5)   # Top-left tile
      pixel2 = tiled.at(15, 5)  # Top-right tile
      pixel3 = tiled.at(5, 15)  # Bottom-left tile
      pixel4 = tiled.at(15, 15) # Bottom-right tile

      [pixel1, pixel2, pixel3, pixel4].each do |pixel|
        r, g, b, _ = pixel.rgba
        (r >> 8).should be < 10
        (g >> 8).should be < 10
        (b >> 8).should eq(255)
      end
    end

    it "works with single tile" do
      img = CrImage.rgba(30, 30, CrImage::Color::GREEN)
      tiled = CrImage::Util::Tiling.tile(img, 1, 1)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(30)
      height.should eq(30)
    end

    it "raises on invalid dimensions" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "cols must be positive") do
        CrImage::Util::Tiling.tile(img, 0, 1)
      end
      expect_raises(ArgumentError, "rows must be positive") do
        CrImage::Util::Tiling.tile(img, 1, 0)
      end
    end
  end

  describe ".make_seamless" do
    it "creates seamless image" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      seamless = CrImage::Util::Tiling.make_seamless(img, blend_width: 10)

      bounds = seamless.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(100)
      height.should eq(100)
    end

    it "uses auto blend width when not specified" do
      img = CrImage.rgba(80, 80, CrImage::Color::BLUE)
      seamless = CrImage::Util::Tiling.make_seamless(img)

      bounds = seamless.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(80)
    end

    it "raises on invalid blend width" do
      img = CrImage.rgba(20, 20)
      expect_raises(ArgumentError, "blend_width too large") do
        CrImage::Util::Tiling.make_seamless(img, blend_width: 15)
      end
    end
  end

  describe ".tile_to_size" do
    it "tiles to fill target dimensions" do
      img = CrImage.rgba(50, 50, CrImage::Color::GREEN)
      tiled = CrImage::Util::Tiling.tile_to_size(img, 120, 120)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(120)
      height.should eq(120)
    end

    it "crops excess tiles" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      tiled = CrImage::Util::Tiling.tile_to_size(img, 75, 75)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(75)
      height.should eq(75)
    end

    it "handles exact multiples" do
      img = CrImage.rgba(25, 25, CrImage::Color::BLUE)
      tiled = CrImage::Util::Tiling.tile_to_size(img, 100, 100)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(100)
      height.should eq(100)
    end

    it "raises on invalid dimensions" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError) do
        CrImage::Util::Tiling.tile_to_size(img, 0, 100)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::Tiling.tile_to_size(img, 100, -1)
      end
    end
  end

  describe "Image convenience methods" do
    it "works with tile" do
      img = CrImage.rgba(20, 20, CrImage::Color::RED)
      tiled = img.tile(2, 2)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(40)
    end

    it "works with make_seamless" do
      img = CrImage.rgba(50, 50, CrImage::Color::GREEN)
      seamless = img.make_seamless(5)

      bounds = seamless.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(50)
    end

    it "works with tile_to_size" do
      img = CrImage.rgba(30, 30, CrImage::Color::BLUE)
      tiled = img.tile_to_size(100, 100)

      bounds = tiled.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(100)
    end
  end
end
