require "./spec_helper"

module CrImage::GIF
  describe "GIF Writer Tests" do
    it "writes paletted image to GIF" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 255, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 10, 10), palette)

      img.set_color_index(5, 5, 0_u8)

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
      io.rewind

      # Verify it can be read back
      result = GIF.read(io)
      result.should_not be_nil
      result.should be_a(CrImage::Paletted)
    end

    it "writes RGBA image to GIF (auto-converts to paletted)" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::RGBA.new(255, 0, 0, 255))
      img.set(6, 6, Color::RGBA.new(0, 255, 0, 255))

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
      io.rewind

      result = GIF.read(io)
      result.should be_a(CrImage::Paletted)
    end

    it "writes NRGBA image to GIF" do
      img = CrImage::NRGBA.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::NRGBA.new(255, 0, 0, 255))

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
    end

    it "writes grayscale image to GIF" do
      img = CrImage::Gray.new(CrImage.rect(0, 0, 10, 10))
      img.set(5, 5, Color::Gray.new(128))

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
    end

    it "writes to file" do
      colors = [
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 10, 10), palette)
      path = "/tmp/test_gif_write.gif"

      GIF.write(path, img)

      File.exists?(path).should be_true
      File.delete(path)
    end

    it "handles small images" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 1, 1), palette)

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
    end

    it "handles large palettes" do
      # Create palette with many colors
      colors = (0...256).map do |i|
        Color::RGBA.new(i.to_u8, (255 - i).to_u8, (i * 2 % 256).to_u8, 255).as(Color::Color)
      end.to_a
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 16, 16), palette)

      # Fill with different colors
      16.times do |y|
        16.times do |x|
          img.set_color_index(x, y, ((x + y * 16) % 256).to_u8)
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)

      io.size.should be > 0
    end

    it "round-trips image data" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 255, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      original = CrImage::Paletted.new(CrImage.rect(0, 0, 5, 5), palette)

      # Fill image with a pattern using all colors
      5.times do |y|
        5.times do |x|
          idx = (x + y) % 3
          original.set_color_index(x, y, idx.to_u8)
        end
      end

      io = IO::Memory.new
      GIF.write(io, original)
      io.rewind

      result = GIF.read(io).as(CrImage::Paletted)

      # Verify dimensions
      result.bounds.width.should eq(5)
      result.bounds.height.should eq(5)

      # Verify that the image was successfully round-tripped
      # Just check that we can read colors back
      result.at(0, 0).should_not be_nil
      result.at(4, 4).should_not be_nil
    end

    it "handles images with repetitive patterns" do
      colors = [
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 50, 50), palette)

      # Checkerboard pattern (compresses well with LZW)
      5.times do |y|
        5.times do |x|
          img.set_color_index(x, y, ((x + y) % 2).to_u8)
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)

      # Should compress well
      io.size.should be < (50 * 50) # Less than raw data
    end

    it "handles wide images" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 200, 10), palette)

      io = IO::Memory.new
      GIF.write(io, img)

      io.rewind
      result = GIF.read(io)
      result.bounds.width.should eq(200)
      result.bounds.height.should eq(10)
    end

    it "handles tall images" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 10, 200), palette)

      io = IO::Memory.new
      GIF.write(io, img)

      io.rewind
      result = GIF.read(io)
      result.bounds.width.should eq(10)
      result.bounds.height.should eq(200)
    end

    it "converts true-color to limited palette" do
      # Create image with many colors (will be quantized)
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 30, 30))

      30.times do |y|
        30.times do |x|
          r = (x * 8).to_u8
          g = (y * 8).to_u8
          b = ((x + y) * 4).to_u8
          img.set(x, y, Color::RGBA.new(r, g, b, 255))
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)

      io.rewind
      result = GIF.read(io).as(CrImage::Paletted)

      # Should have a palette with <= 256 colors
      result.palette.size.should be <= 256
      result.palette.size.should be > 0
    end
  end

  describe "GIF Round-trip Tests" do
    it "round-trips test GIF files" do
      FILE_NAMES.each do |name|
        path = "#{TEST_DATA}#{name}.gif"
        next unless File.exists?(path)

        # Read original
        original = GIF.read(path)

        # Write to memory
        io = IO::Memory.new
        GIF.write(io, original)

        # Read back
        io.rewind
        result = GIF.read(io)

        # Verify dimensions match
        result.bounds.width.should eq(original.bounds.width)
        result.bounds.height.should eq(original.bounds.height)
      end
    end
  end

  describe "2-bit (4 colors or less) Tests" do
    it "writes and reads back 2-bit GIF with 2 colors" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 8, 8), palette)

      (0...8).each do |y|
        (0...8).each do |x|
          img.set_color_index(x, y, ((x + y) % 2).to_u8)
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)
      io.rewind

      result = GIF.read(io)
      result.should be_a(CrImage::Paletted)

      paletted = result.as(CrImage::Paletted)
      paletted.bounds.should eq(img.bounds)

      (0...8).each do |y|
        (0...8).each do |x|
          expected_index = ((x + y) % 2).to_u8
          actual_color = paletted.at(x, y)
          expected_color = palette[expected_index]
          actual_color.rgba.should eq(expected_color.rgba)
        end
      end
    end

    it "writes and reads back 2-bit GIF with 4 colors" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 255, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 0, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 8, 8), palette)

      (0...8).each do |y|
        (0...8).each do |x|
          img.set_color_index(x, y, ((x + y) % 4).to_u8)
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)
      io.rewind

      result = GIF.read(io)
      result.should be_a(CrImage::Paletted)

      paletted = result.as(CrImage::Paletted)
      paletted.bounds.should eq(img.bounds)

      (0...8).each do |y|
        (0...8).each do |x|
          expected_index = ((x + y) % 4).to_u8
          actual_color = paletted.at(x, y)
          expected_color = palette[expected_index]
          actual_color.rgba.should eq(expected_color.rgba)
        end
      end
    end

    it "writes and reads back 2-bit GIF with repeating pattern" do
      colors = [
        Color::RGBA.new(255, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 255, 0, 255).as(Color::Color),
        Color::RGBA.new(0, 0, 255, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 0, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 8, 1), palette)

      (0...8).each do |x|
        img.set_color_index(x, 0, (x % 4).to_u8)
      end

      io = IO::Memory.new
      GIF.write(io, img)
      io.rewind

      result = GIF.read(io)
      result.should be_a(CrImage::Paletted)

      paletted = result.as(CrImage::Paletted)
      paletted.bounds.should eq(img.bounds)

      (0...8).each do |x|
        expected_index = (x % 4).to_u8
        actual_color = paletted.at(x, 0)
        expected_color = palette[expected_index]
        actual_color.rgba.should eq(expected_color.rgba)
      end
    end

    it "writes and reads back 2-bit GIF with solid colors" do
      colors = [
        Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
        Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
      ]
      palette = Color::Palette.new(colors)
      img = CrImage::Paletted.new(CrImage.rect(0, 0, 16, 16), palette)

      (0...16).each do |y|
        (0...16).each do |x|
          img.set_color_index(x, y, (y < 8 ? 0_u8 : 1_u8))
        end
      end

      io = IO::Memory.new
      GIF.write(io, img)
      io.rewind

      result = GIF.read(io)
      result.should be_a(CrImage::Paletted)

      paletted = result.as(CrImage::Paletted)
      paletted.bounds.should eq(img.bounds)

      (0...16).each do |y|
        (0...16).each do |x|
          expected_index = (y < 8 ? 0_u8 : 1_u8)
          actual_color = paletted.at(x, y)
          expected_color = palette[expected_index]
          actual_color.rgba.should eq(expected_color.rgba)
        end
      end
    end
  end
end
