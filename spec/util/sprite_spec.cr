require "../spec_helper"

describe CrImage::Util::SpriteGenerator do
  describe ".generate" do
    it "raises on empty array" do
      expect_raises(ArgumentError, "images array cannot be empty") do
        CrImage::Util::SpriteGenerator.generate([] of CrImage::Image)
      end
    end

    it "raises on negative spacing" do
      img = CrImage.rgba(10, 10)
      expect_raises(ArgumentError, "spacing must be non-negative") do
        CrImage::Util::SpriteGenerator.generate([img], spacing: -1)
      end
    end

    it "generates horizontal sprite sheet" do
      img1 = CrImage.rgba(20, 30, CrImage::Color::RED)
      img2 = CrImage.rgba(30, 20, CrImage::Color::GREEN)
      img3 = CrImage.rgba(25, 25, CrImage::Color::BLUE)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2, img3],
        CrImage::Util::SpriteLayout::Horizontal
      )

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(75)  # 20 + 30 + 25
      height.should eq(30) # max height
      sheet.sprites.size.should eq(3)
    end

    it "generates horizontal sprite sheet with spacing" do
      img1 = CrImage.rgba(20, 20)
      img2 = CrImage.rgba(20, 20)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2],
        CrImage::Util::SpriteLayout::Horizontal,
        spacing: 10
      )

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(50) # 20 + 10 + 20
    end

    it "generates vertical sprite sheet" do
      img1 = CrImage.rgba(30, 20, CrImage::Color::RED)
      img2 = CrImage.rgba(20, 30, CrImage::Color::GREEN)
      img3 = CrImage.rgba(25, 25, CrImage::Color::BLUE)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2, img3],
        CrImage::Util::SpriteLayout::Vertical
      )

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(30)  # max width
      height.should eq(75) # 20 + 30 + 25
      sheet.sprites.size.should eq(3)
    end

    it "generates vertical sprite sheet with spacing" do
      img1 = CrImage.rgba(20, 20)
      img2 = CrImage.rgba(20, 20)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2],
        CrImage::Util::SpriteLayout::Vertical,
        spacing: 10
      )

      bounds = sheet.image.bounds
      height = bounds.max.y - bounds.min.y

      height.should eq(50) # 20 + 10 + 20
    end

    it "generates grid sprite sheet" do
      images = (0...9).map { CrImage.rgba(20, 20) }.to_a

      sheet = CrImage::Util::SpriteGenerator.generate(
        images,
        CrImage::Util::SpriteLayout::Grid
      )

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(60)  # 3 cols * 20
      height.should eq(60) # 3 rows * 20
      sheet.sprites.size.should eq(9)
    end

    it "generates grid sprite sheet with spacing" do
      images = (0...4).map { CrImage.rgba(20, 20) }.to_a

      sheet = CrImage::Util::SpriteGenerator.generate(
        images,
        CrImage::Util::SpriteLayout::Grid,
        spacing: 5
      )

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(45)  # 2 cols * 20 + 1 spacing * 5
      height.should eq(45) # 2 rows * 20 + 1 spacing * 5
    end

    it "generates packed sprite sheet" do
      img1 = CrImage.rgba(50, 50)
      img2 = CrImage.rgba(30, 30)
      img3 = CrImage.rgba(20, 20)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2, img3],
        CrImage::Util::SpriteLayout::Packed
      )

      sheet.sprites.size.should eq(3)
      sheet.sprites[0].index.should eq(0)
      sheet.sprites[1].index.should eq(1)
      sheet.sprites[2].index.should eq(2)
    end

    it "preserves sprite colors" do
      img1 = CrImage.rgba(10, 10, CrImage::Color::RED)
      img2 = CrImage.rgba(10, 10, CrImage::Color::GREEN)

      sheet = CrImage::Util::SpriteGenerator.generate(
        [img1, img2],
        CrImage::Util::SpriteLayout::Horizontal
      )

      # Check first sprite color
      color1 = sheet.image.at(5, 5)
      r1, g1, b1, _ = color1.rgba
      (r1 >> 8).should eq(255)
      (g1 >> 8).should be < 10
      (b1 >> 8).should be < 10

      # Check second sprite color
      color2 = sheet.image.at(15, 5)
      r2, g2, b2, _ = color2.rgba
      (r2 >> 8).should be < 10
      (g2 >> 8).should eq(255)
      (b2 >> 8).should be < 10
    end

    it "handles single image" do
      img = CrImage.rgba(50, 50, CrImage::Color::BLUE)

      sheet = CrImage::Util::SpriteGenerator.generate([img])

      bounds = sheet.image.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(50)
      height.should eq(50)
      sheet.sprites.size.should eq(1)
    end

    it "works with different image types" do
      rgba = CrImage.rgba(20, 20, CrImage::Color::RED)
      gray = CrImage.gray(20, 20)
      nrgba = CrImage.nrgba(20, 20)

      images = [rgba, gray, nrgba] of CrImage::Image
      sheet = CrImage::Util::SpriteGenerator.generate(images,
        CrImage::Util::SpriteLayout::Horizontal)

      sheet.sprites.size.should eq(3)
    end
  end

  describe "SpriteSheet" do
    it "provides sprite access by index" do
      img1 = CrImage.rgba(20, 20)
      img2 = CrImage.rgba(30, 30)

      sheet = CrImage::Util::SpriteGenerator.generate([img1, img2])

      sprite0 = sheet[0]
      sprite0.width.should eq(20)
      sprite0.height.should eq(20)
      sprite0.x.should eq(0)

      sprite1 = sheet[1]
      sprite1.width.should eq(30)
      sprite1.height.should eq(30)
      sprite1.x.should eq(20)
    end

    it "provides sprite bounds" do
      img = CrImage.rgba(25, 35)
      sheet = CrImage::Util::SpriteGenerator.generate([img])

      bounds = sheet[0].bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(25)
      height.should eq(35)
    end

    it "reports correct size" do
      images = (0...5).map { CrImage.rgba(10, 10) }.to_a
      sheet = CrImage::Util::SpriteGenerator.generate(images)

      sheet.size.should eq(5)
    end
  end

  describe "CrImage.generate_sprite_sheet" do
    it "works as module method" do
      img1 = CrImage.rgba(20, 20)
      img2 = CrImage.rgba(20, 20)

      sheet = CrImage.generate_sprite_sheet([img1, img2])

      sheet.sprites.size.should eq(2)
    end

    it "accepts all parameters" do
      img1 = CrImage.rgba(20, 20)
      img2 = CrImage.rgba(20, 20)

      sheet = CrImage.generate_sprite_sheet([img1, img2],
        CrImage::Util::SpriteLayout::Vertical,
        spacing: 5,
        background: CrImage::Color::WHITE)

      bounds = sheet.image.bounds
      height = bounds.max.y - bounds.min.y

      height.should eq(45) # 20 + 5 + 20
    end
  end
end
