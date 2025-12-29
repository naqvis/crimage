require "./spec_helper"

module CrImage::GIF
  describe "GIF Reader Tests" do
    it "reads a basic GIF image" do
      img = GIF.read("#{TEST_DATA}video-001.gif")
      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
      img.should be_a(CrImage::Paletted)
    end

    it "reads GIF config without decoding pixels" do
      config = GIF.read_config("#{TEST_DATA}video-001.gif")
      config.should_not be_nil
      config.width.should be > 0
      config.height.should be > 0
      config.color_model.should be_a(CrImage::Color::Palette)
    end

    it "reads interlaced GIF" do
      img = GIF.read("#{TEST_DATA}video-001.interlaced.gif")
      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads grayscale GIF" do
      img = GIF.read("#{TEST_DATA}video-005.gray.gif")
      img.should be_a(CrImage::Paletted)
      img.bounds.width.should be > 0
    end

    it "reads 5bpp GIF" do
      img = GIF.read("#{TEST_DATA}video-001.5bpp.gif")
      img.should be_a(CrImage::Paletted)
      img.bounds.width.should be > 0
    end

    it "reads triangle GIF" do
      img = GIF.read("#{TEST_DATA}triangle-001.gif")
      img.should be_a(CrImage::Paletted)
      img.bounds.width.should be > 0
    end

    it "reads GIF from IO stream" do
      File.open("#{TEST_DATA}video-001.gif") do |file|
        img = GIF.read(file)
        img.should_not be_nil
        img.should be_a(CrImage::Paletted)
      end
    end

    it "reads config from IO stream" do
      File.open("#{TEST_DATA}video-001.gif") do |file|
        config = GIF.read_config(file)
        config.should_not be_nil
        config.color_model.should be_a(CrImage::Color::Palette)
      end
    end

    it "validates GIF header" do
      io = IO::Memory.new("INVALID".to_slice)
      expect_raises(FormatError) do
        GIF.read(io)
      end
    end

    it "handles empty IO" do
      io = IO::Memory.new
      expect_raises(Exception) do
        GIF.read(io)
      end
    end

    it "handles truncated GIF" do
      # Create a truncated GIF (just header)
      io = IO::Memory.new("GIF89a".to_slice)
      expect_raises(Exception) do
        GIF.read(io)
      end
    end

    it "reads all test GIF files" do
      FILE_NAMES.each do |name|
        path = "#{TEST_DATA}#{name}.gif"
        if File.exists?(path)
          img = GIF.read(path)
          img.should_not be_nil
          img.should be_a(CrImage::Paletted)
          img.bounds.width.should be > 0
          img.bounds.height.should be > 0
        end
      end
    end

    it "verifies palette is loaded correctly" do
      img = GIF.read("#{TEST_DATA}video-001.gif")
      paletted = img.as(CrImage::Paletted)

      # GIF should have a palette
      paletted.palette.size.should be > 0
      paletted.palette.size.should be <= 256
    end

    it "handles images with different bit depths" do
      # 5bpp should work (will use 8-bit internally)
      img = GIF.read("#{TEST_DATA}video-001.5bpp.gif")
      img.should be_a(CrImage::Paletted)
    end

    it "preserves image dimensions" do
      img = GIF.read("#{TEST_DATA}video-001.gif")
      config = GIF.read_config("#{TEST_DATA}video-001.gif")

      img.bounds.width.should eq(config.width)
      img.bounds.height.should eq(config.height)
    end
  end

  describe "GIF Format Detection" do
    it "detects GIF format through CrImage.read" do
      img = CrImage.read("#{TEST_DATA}video-001.gif")
      img.should_not be_nil
      img.should be_a(CrImage::Paletted)
    end

    it "detects GIF format through CrImage.read_config" do
      config = CrImage.read_config("#{TEST_DATA}video-001.gif")
      config.should_not be_nil
      config.color_model.should be_a(CrImage::Color::Palette)
    end

    it "is registered in supported formats" do
      formats = CrImage.supported_formats
      formats.should contain("gif")
    end
  end
end
