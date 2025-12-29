require "./spec_helper"

module CrImage::BMP
  describe "BMP Writer Tests" do
    it "writes RGBA image to BMP" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

      io = IO::Memory.new
      BMP.write(io, img)

      io.size.should be > 0
      io.rewind

      # Verify it can be read back
      result = BMP.read(io)
      result.should be_a(CrImage::Image)
    end

    it "writes grayscale image to BMP" do
      img = CrImage::Gray.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::Gray.new(128))

      io = IO::Memory.new
      BMP.write(io, img)

      io.size.should be > 0
    end

    it "writes paletted image to BMP" do
      palette = Color::Palette.new([
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ])
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 10, 10), palette)

      io = IO::Memory.new
      BMP.write(io, img)

      io.size.should be > 0
    end

    it "writes to file" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      path = "/tmp/test_bmp_write.bmp"

      BMP.write(path, img)

      File.exists?(path).should be_true
      File.delete(path)
    end

    it "handles empty image dimensions" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 0, 0))

      io = IO::Memory.new
      # Empty images may be written successfully (0x0 BMP)
      BMP.write(io, img)
      io.size.should be > 0
    end

    it "writes NRGBA image" do
      img = CrImage::NRGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::NRGBA.new(255, 0, 0, 128))

      io = IO::Memory.new
      BMP.write(io, img)

      io.size.should be > 0
    end

    it "round-trips image data" do
      original = CrImage::RGBA.new(CrImage.rect(0, 0, 5, 5))
      original.set(2, 2, Color::RGBA.new(255, 0, 0, 255))
      original.set(3, 3, Color::RGBA.new(0, 255, 0, 255))

      io = IO::Memory.new
      BMP.write(io, original)
      io.rewind

      result = BMP.read(io)
      r, _, _, _ = result.at(2, 2).rgba
      _, g, _, _ = result.at(3, 3).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
    end

    it "handles opaque RGBA correctly" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))

      # Fill with opaque pixels
      10.times do |y|
        10.times do |x|
          img.set(x, y, Color::RGBA.new(128, 128, 128, 255))
        end
      end

      io = IO::Memory.new
      BMP.write(io, img)

      # Should write as 24-bit BMP
      io.size.should be > 0
    end

    it "handles transparent RGBA correctly" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))

      # Add a transparent pixel
      img.set(5, 5, Color::RGBA.new(255, 0, 0, 128))

      io = IO::Memory.new
      BMP.write(io, img)

      # Should write as 32-bit BMP
      io.size.should be > 0
    end
  end
end
