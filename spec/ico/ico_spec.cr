require "../spec_helper"

describe CrImage::ICO do
  describe "writing and reading" do
    it "writes and reads single icon" do
      img = CrImage.rgba(32, 32)
      32.times do |y|
        32.times do |x|
          img.set(x, y, CrImage::Color.rgba(x * 8, y * 8, 128, 255))
        end
      end

      # Write to memory
      io = IO::Memory.new
      CrImage::ICO.write(io, img)

      # Read back
      io.rewind
      loaded = CrImage::ICO.read(io)

      loaded.bounds.width.should eq(32)
      loaded.bounds.height.should eq(32)
    end

    it "writes and reads multiple sizes" do
      icons = [16, 32, 48].map do |size|
        img = CrImage.rgba(size, size, CrImage::Color::RED)
        img
      end

      io = IO::Memory.new
      CrImage::ICO.write_multi(io, icons)

      io.rewind
      all = CrImage::ICO.read_all(io)

      all.images.size.should eq(3)
      all.entries.size.should eq(3)
    end

    it "preserves transparency" do
      img = CrImage.rgba(32, 32)
      # Create semi-transparent image
      32.times do |y|
        32.times do |x|
          alpha = (x * 255 // 32).to_u8
          img.set(x, y, CrImage::Color.rgba(255, 0, 0, alpha))
        end
      end

      io = IO::Memory.new
      CrImage::ICO.write(io, img)

      io.rewind
      loaded = CrImage::ICO.read(io)

      # Check transparency is preserved
      pixel = loaded.at(0, 16)
      r, g, b, a = pixel.rgba
      (a >> 8).should be < 50 # Should be mostly transparent
    end
  end

  describe "Icon class" do
    it "finds largest icon" do
      icons = [
        CrImage.rgba(16, 16),
        CrImage.rgba(64, 64),
        CrImage.rgba(32, 32),
      ]

      io = IO::Memory.new
      CrImage::ICO.write_multi(io, icons)

      io.rewind
      all = CrImage::ICO.read_all(io)

      largest = all.largest
      largest.bounds.width.should eq(64)
      largest.bounds.height.should eq(64)
    end

    it "finds smallest icon" do
      icons = [
        CrImage.rgba(32, 32),
        CrImage.rgba(16, 16),
        CrImage.rgba(48, 48),
      ]

      io = IO::Memory.new
      CrImage::ICO.write_multi(io, icons)

      io.rewind
      all = CrImage::ICO.read_all(io)

      smallest = all.smallest
      smallest.bounds.width.should eq(16)
      smallest.bounds.height.should eq(16)
    end

    it "finds closest size" do
      icons = [
        CrImage.rgba(16, 16),
        CrImage.rgba(32, 32),
        CrImage.rgba(64, 64),
      ]

      io = IO::Memory.new
      CrImage::ICO.write_multi(io, icons)

      io.rewind
      all = CrImage::ICO.read_all(io)

      # Find closest to 40x40 (should be 32x32)
      closest = all.find_size(40, 40)
      closest.should_not be_nil
      if closest
        closest.bounds.width.should eq(32)
      end
    end
  end

  describe "read_config" do
    it "reads configuration without loading full image" do
      img = CrImage.rgba(48, 48, CrImage::Color::GREEN)

      io = IO::Memory.new
      CrImage::ICO.write(io, img)

      io.rewind
      config = CrImage::ICO.read_config(io)

      config.width.should eq(48)
      config.height.should eq(48)
    end
  end

  describe "validation" do
    it "requires at least one image" do
      io = IO::Memory.new
      expect_raises(ArgumentError, /at least one/i) do
        CrImage::ICO.write_multi(io, [] of CrImage::Image)
      end
    end

    it "limits to 256 images" do
      icons = Array.new(257) { CrImage.rgba(16, 16) }
      io = IO::Memory.new
      expect_raises(ArgumentError, /maximum 256/i) do
        CrImage::ICO.write_multi(io, icons)
      end
    end
  end

  describe "format detection" do
    it "is detected by CrImage.read" do
      img = CrImage.rgba(32, 32, CrImage::Color::BLUE)

      io = IO::Memory.new
      CrImage::ICO.write(io, img)

      io.rewind
      loaded = CrImage.read(io)

      loaded.bounds.width.should eq(32)
      loaded.bounds.height.should eq(32)
    end
  end

  describe "standard icon sizes" do
    it "handles all standard sizes" do
      [16, 32, 48, 64, 128, 256].each do |size|
        img = CrImage.rgba(size, size)

        io = IO::Memory.new
        CrImage::ICO.write(io, img)

        io.rewind
        loaded = CrImage::ICO.read(io)

        loaded.bounds.width.should eq(size)
        loaded.bounds.height.should eq(size)
      end
    end
  end
end
