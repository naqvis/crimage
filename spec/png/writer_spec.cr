require "../spec_helper"

module CrImage::PNG
  describe "PNG Writer Tests" do
    it "writes RGBA image to PNG" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::RGBA.new(255, 0, 0, 255))

      io = IO::Memory.new
      PNG.write(io, img)

      io.size.should be > 0
      io.rewind

      # Verify it can be read back (PNG may convert to NRGBA)
      result = PNG.read(io)
      result.should_not be_nil
    end

    it "writes grayscale image to PNG" do
      img = CrImage::Gray.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::Gray.new(128))

      io = IO::Memory.new
      PNG.write(io, img)

      io.size.should be > 0
    end

    it "writes paletted image to PNG" do
      palette = Color::Palette.new([
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ])
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 10, 10), palette)

      io = IO::Memory.new
      PNG.write(io, img)

      io.size.should be > 0
    end

    it "writes with different compression levels" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))

      io1 = IO::Memory.new
      PNG.write(io1, img, CompressionLevel::NoCompression)

      io2 = IO::Memory.new
      PNG.write(io2, img, CompressionLevel::BestCompression)

      # Best compression should be smaller or equal
      io2.size.should be <= io1.size
    end

    it "writes to file" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      path = "/tmp/test_png_write.png"

      PNG.write(path, img)

      File.exists?(path).should be_true
      File.delete(path)
    end

    it "handles empty image dimensions" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 0, 0))

      io = IO::Memory.new
      # Empty images are written successfully (0x0 PNG)
      PNG.write(io, img)
      io.size.should be > 0
    end

    it "writes NRGBA image" do
      img = CrImage::NRGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::NRGBA.new(255, 0, 0, 128))

      io = IO::Memory.new
      PNG.write(io, img)

      io.size.should be > 0
    end

    it "writes 16-bit images" do
      img = CrImage::RGBA64.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::RGBA64.new(0xffff, 0, 0, 0xffff))

      io = IO::Memory.new
      PNG.write(io, img)

      io.size.should be > 0
    end

    it "round-trips image data" do
      original = CrImage::RGBA.new(CrImage.rect(0, 0, 5, 5))
      original.set(2, 2, Color::RGBA.new(255, 0, 0, 255))
      original.set(3, 3, Color::RGBA.new(0, 255, 0, 255))

      io = IO::Memory.new
      PNG.write(io, original)
      io.rewind

      result = PNG.read(io)
      r, _, _, _ = result.at(2, 2).rgba
      _, g, _, _ = result.at(3, 3).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
    end
  end
end
