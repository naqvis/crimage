require "../spec_helper"

describe CrImage::TIFF do
  describe "Reader" do
    it "reads uncompressed TIFF" do
      img = CrImage::TIFF.read("spec/testdata/tiff/video-001-uncompressed.tiff")

      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads deflate compressed TIFF" do
      img = CrImage::TIFF.read("spec/testdata/tiff/bw-deflate.tiff")

      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads grayscale TIFF" do
      img = CrImage::TIFF.read("spec/testdata/tiff/video-001-gray.tiff")

      img.should_not be_nil
      img.should be_a(CrImage::Gray)
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads paletted TIFF" do
      img = CrImage::TIFF.read("spec/testdata/tiff/video-001-paletted.tiff")

      img.should_not be_nil
      img.should be_a(CrImage::Paletted)
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end

    it "reads TIFF config without decoding full image" do
      config = CrImage::TIFF.read_config("spec/testdata/tiff/video-001.tiff")

      config.width.should be > 0
      config.height.should be > 0
      config.color_model.should_not be_nil
    end

    it "reads TIFF using generic CrImage API" do
      img = CrImage.read("spec/testdata/tiff/video-001.tiff")

      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end
  end

  describe "Writer" do
    it "writes a simple TIFF image" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))

      # Fill with red
      (0...10).each do |y|
        (0...10).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img)

      io.pos.should be > 0
    end

    it "writes and reads back a TIFF image" do
      # Create a test image
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 4, 4))
      (0...4).each do |y|
        (0...4).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new((x * 64).to_u8, (y * 64).to_u8, 128_u8, 255_u8))
        end
      end

      # Write to memory
      io = IO::Memory.new
      CrImage::TIFF.write(io, img)

      # Read back
      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.bounds.should eq(img.bounds)

      # Verify a few pixels
      img2.at(0, 0).rgba.should eq(img.at(0, 0).rgba)
      img2.at(3, 3).rgba.should eq(img.at(3, 3).rgba)
    end

    it "writes grayscale TIFF" do
      img = CrImage::Gray.new(CrImage.rect(0, 0, 8, 8))
      (0...8).each do |y|
        (0...8).each do |x|
          img.set_gray(x, y, CrImage::Color::Gray.new((x * y * 4).to_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.should be_a(CrImage::Gray)
      img2.bounds.should eq(img.bounds)
    end

    it "writes with deflate compression" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      (0...10).each do |y|
        (0...10).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img, CrImage::TIFF::CompressionType::Deflate)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.bounds.should eq(img.bounds)
      img2.at(5, 5).rgba.should eq(img.at(5, 5).rgba)
    end

    it "writes with LZW compression" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      (0...10).each do |y|
        (0...10).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new(100_u8, 150_u8, 200_u8, 255_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img, CrImage::TIFF::CompressionType::LZW)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.bounds.should eq(img.bounds)
      img2.at(5, 5).rgba.should eq(img.at(5, 5).rgba)
    end

    it "writes large RGBA image with LZW compression" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 50, 50))

      # Create a pattern that compresses well
      (0...50).each do |y|
        (0...50).each do |x|
          if (x + y) % 20 < 10
            img.set(x, y, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
          else
            img.set(x, y, CrImage::Color::RGBA.new(0_u8, 0_u8, 255_u8, 255_u8))
          end
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img, CrImage::TIFF::CompressionType::LZW)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.bounds.should eq(img.bounds)

      # Verify all pixels match
      (0...50).each do |y|
        (0...50).each do |x|
          img2.at(x, y).rgba.should eq(img.at(x, y).rgba)
        end
      end
    end

    it "writes grayscale with LZW compression" do
      img = CrImage::Gray.new(CrImage.rect(0, 0, 20, 20))
      (0...20).each do |y|
        (0...20).each do |x|
          img.set_gray(x, y, CrImage::Color::Gray.new((x * 12).to_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img, CrImage::TIFF::CompressionType::LZW)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.should be_a(CrImage::Gray)
      img2.bounds.should eq(img.bounds)

      (0...20).each do |y|
        (0...20).each do |x|
          img2.at(x, y).rgba.should eq(img.at(x, y).rgba)
        end
      end
    end

    it "writes paletted image with LZW compression" do
      palette = CrImage::Color::Palette.new([
        CrImage::Color::RGBA.new(255, 0, 0, 255),
        CrImage::Color::RGBA.new(0, 255, 0, 255),
        CrImage::Color::RGBA.new(0, 0, 255, 255),
        CrImage::Color::RGBA.new(255, 255, 0, 255),
      ].map(&.as(CrImage::Color::Color)))

      img = CrImage::Paletted.new(CrImage.rect(0, 0, 16, 16), palette)
      (0...16).each do |y|
        (0...16).each do |x|
          img.set_color_index(x, y, ((x + y) % 4).to_u8)
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, img, CrImage::TIFF::CompressionType::LZW)

      io.rewind
      img2 = CrImage::TIFF.read(io)

      img2.should be_a(CrImage::Paletted)
      img2.bounds.should eq(img.bounds)

      (0...16).each do |y|
        (0...16).each do |x|
          img2.at(x, y).rgba.should eq(img.at(x, y).rgba)
        end
      end
    end

    it "writes to file and reads back" do
      img = CrImage::RGBA.new(CrImage.rect(0, 0, 16, 16))

      # Create a gradient
      (0...16).each do |y|
        (0...16).each do |x|
          img.set(x, y, CrImage::Color::RGBA.new((x * 16).to_u8, (y * 16).to_u8, 128_u8, 255_u8))
        end
      end

      # Write to temp file
      temp_file = "spec/testdata/tiff/test_output.tiff"
      CrImage::TIFF.write(temp_file, img)

      # Read back
      img2 = CrImage::TIFF.read(temp_file)

      img2.bounds.should eq(img.bounds)
      img2.at(0, 0).rgba.should eq(img.at(0, 0).rgba)
      img2.at(15, 15).rgba.should eq(img.at(15, 15).rgba)

      # Cleanup
      File.delete(temp_file) if File.exists?(temp_file)
    end
  end

  describe "Round-trip tests" do
    it "preserves image data through write and read cycle for RGBA" do
      original = CrImage::RGBA.new(CrImage.rect(0, 0, 8, 8))

      # Fill with pattern
      (0...8).each do |y|
        (0...8).each do |x|
          r = [((x + y) * 32), 255].min.to_u8
          g = [(x * 32), 255].min.to_u8
          b = [(y * 32), 255].min.to_u8
          original.set(x, y, CrImage::Color::RGBA.new(r, g, b, 255_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, original)
      io.rewind

      restored = CrImage::TIFF.read(io)

      # Check all pixels
      (0...8).each do |y|
        (0...8).each do |x|
          restored.at(x, y).rgba.should eq(original.at(x, y).rgba)
        end
      end
    end

    it "preserves grayscale data through write and read cycle" do
      original = CrImage::Gray.new(CrImage.rect(0, 0, 8, 8))

      (0...8).each do |y|
        (0...8).each do |x|
          original.set_gray(x, y, CrImage::Color::Gray.new(((x + y) * 16).to_u8))
        end
      end

      io = IO::Memory.new
      CrImage::TIFF.write(io, original)
      io.rewind

      restored = CrImage::TIFF.read(io).as(CrImage::Gray)

      (0...8).each do |y|
        (0...8).each do |x|
          restored.at(x, y).rgba.should eq(original.at(x, y).rgba)
        end
      end
    end
  end

  describe "Format detection" do
    it "detects TIFF format in supported formats list" do
      CrImage.supported_formats.should contain("tiff")
    end

    it "reads TIFF through generic API" do
      img = CrImage.read("spec/testdata/tiff/video-001.tiff")
      img.should_not be_nil
    end

    it "reads TIFF config through generic API" do
      config = CrImage.read_config("spec/testdata/tiff/video-001.tiff")
      config.width.should be > 0
      config.height.should be > 0
    end
  end
end
