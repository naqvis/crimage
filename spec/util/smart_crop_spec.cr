require "../spec_helper"

describe CrImage::Util::SmartCrop do
  describe ".crop" do
    it "crops image to target dimensions" do
      img = CrImage.rgba(800, 600, CrImage::Color::WHITE)
      cropped = CrImage::Util::SmartCrop.crop(img, 400, 300)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(400)
      height.should eq(300)
    end

    it "returns original if target is larger" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      cropped = CrImage::Util::SmartCrop.crop(img, 200, 200)
      cropped.should eq(img)
    end

    it "works with entropy strategy" do
      img = CrImage.rgba(400, 400, CrImage::Color::WHITE)
      img.draw_circle(100, 100, 50, color: CrImage::Color::RED, fill: true)

      cropped = CrImage::Util::SmartCrop.crop(img, 200, 200, CrImage::Util::CropStrategy::Entropy)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(200)
      height.should eq(200)
    end

    it "works with edge strategy" do
      img = CrImage.rgba(400, 400, CrImage::Color::WHITE)
      cropped = CrImage::Util::SmartCrop.crop(img, 200, 200, CrImage::Util::CropStrategy::Edge)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(200)
    end

    it "works with center weighted strategy" do
      img = CrImage.rgba(400, 400, CrImage::Color::WHITE)
      cropped = CrImage::Util::SmartCrop.crop(img, 200, 200, CrImage::Util::CropStrategy::CenterWeighted)

      bounds = cropped.bounds
      height = bounds.max.y - bounds.min.y

      height.should eq(200)
    end

    it "works with attention strategy" do
      img = CrImage.rgba(400, 400, CrImage::Color::WHITE)
      cropped = CrImage::Util::SmartCrop.crop(img, 200, 200, CrImage::Util::CropStrategy::Attention)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(200)
    end

    it "raises on invalid dimensions" do
      img = CrImage.rgba(100, 100)
      expect_raises(ArgumentError) do
        CrImage::Util::SmartCrop.crop(img, 0, 100)
      end
      expect_raises(ArgumentError) do
        CrImage::Util::SmartCrop.crop(img, 100, -1)
      end
    end
  end

  describe "Image#smart_crop" do
    it "works as instance method" do
      img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
      cropped = img.smart_crop(200, 150)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x
      height = bounds.max.y - bounds.min.y

      width.should eq(200)
      height.should eq(150)
    end

    it "accepts strategy parameter" do
      img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
      cropped = img.smart_crop(200, 150, CrImage::Util::CropStrategy::Edge)

      bounds = cropped.bounds
      width = bounds.max.x - bounds.min.x

      width.should eq(200)
    end
  end
end
