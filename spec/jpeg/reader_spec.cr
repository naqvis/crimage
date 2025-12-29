require "../spec_helper"

describe CrImage::JPEG::Reader do
  describe ".read" do
    it "reads a baseline RGB JPEG image" do
      img = CrImage::JPEG.read("spec/testdata/video-001.jpeg")
      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads a grayscale JPEG image" do
      img = CrImage::JPEG.read("spec/testdata/video-005.gray.jpeg")
      img.should_not be_nil
      img.should be_a(CrImage::Gray)
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "raises FormatError for invalid JPEG" do
      expect_raises(CrImage::JPEG::FormatError) do
        CrImage::JPEG.read("spec/testdata/video-001.png")
      end
    end
  end

  describe ".read_config" do
    it "reads config from baseline RGB JPEG without decoding pixels" do
      config = CrImage::JPEG.read_config("spec/testdata/video-001.jpeg")
      config.should_not be_nil
      config.width.should be > 0
      config.height.should be > 0
      config.color_model.should eq(CrImage::Color.rgba_model)
    end

    it "reads config from grayscale JPEG" do
      config = CrImage::JPEG.read_config("spec/testdata/video-005.gray.jpeg")
      config.should_not be_nil
      config.width.should be > 0
      config.height.should be > 0
      config.color_model.should eq(CrImage::Color.gray_model)
    end

    it "reads config from IO stream" do
      File.open("spec/testdata/video-001.jpeg") do |file|
        config = CrImage::JPEG.read_config(file)
        config.should_not be_nil
        config.width.should be > 0
        config.height.should be > 0
        config.color_model.should eq(CrImage::Color.rgba_model)
      end
    end

    it "raises FormatError for invalid JPEG" do
      expect_raises(CrImage::JPEG::FormatError) do
        CrImage::JPEG.read_config("spec/testdata/video-001.png")
      end
    end

    it "reads config from progressive JPEG" do
      config = CrImage::JPEG.read_config("spec/testdata/test-gradient-progressive.jpeg")
      config.should_not be_nil
      config.width.should eq(320)
      config.height.should eq(240)
      config.color_model.should eq(CrImage::Color.rgba_model)
    end
  end
end
