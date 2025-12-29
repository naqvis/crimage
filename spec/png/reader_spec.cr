require "../spec_helper"

module CrImage::PNG
  describe "PNG Reader Tests" do
    it "reads a basic PNG image" do
      img = PNG.read("spec/testdata/video-001.png")
      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads PNG config without decoding pixels" do
      config = PNG.read_config("spec/testdata/video-001.png")
      config.should_not be_nil
      config.width.should be > 0
      config.height.should be > 0
    end

    it "reads grayscale PNG" do
      img = PNG.read("spec/testdata/png/benchGray.png")
      img.should be_a(CrImage::Gray)
    end

    it "reads RGBA PNG" do
      img = PNG.read("spec/testdata/png/benchNRGBA-gradient.png")
      # PNG reader may return RGBA or NRGBA depending on the image content
      img.should be_a(CrImage::RGBA | CrImage::NRGBA)
    end

    it "reads paletted PNG" do
      img = PNG.read("spec/testdata/png/benchPaletted.png")
      img.should be_a(CrImage::Paletted)
    end

    it "reads interlaced PNG" do
      img = PNG.read("spec/testdata/png/benchRGB-interlace.png")
      img.should_not be_nil
      img.bounds.width.should be > 0
    end

    it "handles invalid CRC" do
      expect_raises(FormatError, /checksum/) do
        PNG.read("spec/testdata/png/invalid-crc32.png")
      end
    end

    it "handles truncated PNG" do
      expect_raises(Exception) do
        PNG.read("spec/testdata/png/invalid-trunc.png")
      end
    end

    it "handles invalid zlib data" do
      expect_raises(Exception) do
        PNG.read("spec/testdata/png/invalid-zlib.png")
      end
    end

    it "handles missing IEND chunk" do
      expect_raises(FormatError) do
        PNG.read("spec/testdata/png/invalid-noend.png")
      end
    end

    it "reads PNG from IO stream" do
      File.open("spec/testdata/video-001.png") do |file|
        img = PNG.read(file)
        img.should_not be_nil
      end
    end

    it "reads config from IO stream" do
      File.open("spec/testdata/video-001.png") do |file|
        config = PNG.read_config(file)
        config.should_not be_nil
      end
    end

    it "validates PNG header" do
      io = IO::Memory.new("INVALID".to_slice)
      expect_raises(FormatError) do
        PNG.read(io)
      end
    end

    it "handles empty IO" do
      io = IO::Memory.new
      expect_raises(FormatError) do
        PNG.read(io)
      end
    end
  end

  describe "PNG Paeth Filter Tests" do
    it "calculates paeth predictor correctly" do
      # Test cases from PNG spec
      PNG.paeth(0_u8, 0_u8, 0_u8).should eq(0_u8)
      # paeth(a=10, b=20, c=15):
      # pa = |b - c| = |20 - 15| = 5
      # pb = |a - c| = |10 - 15| = 5
      # pc = |pa + pb| = |5 + (-5)| = 0
      # pa <= pb && pa <= pc: 5 <= 5 && 5 <= 0 = false
      # pb <= pc: 5 <= 0 = false
      # returns c = 15
      PNG.paeth(10_u8, 20_u8, 15_u8).should eq(15_u8)
      # paeth(a=100, b=50, c=75):
      # pa = |b - c| = |50 - 75| = 25
      # pb = |a - c| = |100 - 75| = 25
      # pc = |pa + pb| = |(-25) + 25| = 0
      # pa <= pb && pa <= pc: 25 <= 25 && 25 <= 0 = false
      # pb <= pc: 25 <= 0 = false
      # returns c = 75
      PNG.paeth(100_u8, 50_u8, 75_u8).should eq(75_u8)
    end

    it "applies paeth filter to row" do
      cdat = Bytes[10, 20, 30, 40, 50, 60]
      pdat = Bytes[5, 10, 15, 20, 25, 30]
      bytes_per_pixel = 3

      PNG.filter_paeth(cdat, pdat, bytes_per_pixel)

      # Values should be modified
      cdat.should_not eq(Bytes[10, 20, 30, 40, 50, 60])
    end
  end
end
