require "../spec_helper"

describe CrImage::JPEG::Writer do
  describe "write" do
    it "encodes a simple grayscale image" do
      # Create a simple 8x8 grayscale image
      rect = CrImage.rect(0, 0, 8, 8)
      img = CrImage::Gray.new(rect)

      # Fill with gradient
      8.times do |y|
        8.times do |x|
          img.pix[y * 8 + x] = ((x + y) * 16).to_u8
        end
      end

      # Write to IO
      io = IO::Memory.new
      CrImage::JPEG.write(io, img, 75)

      # Verify we got some data
      io.rewind
      data = io.to_slice
      data.size.should be > 100

      # Verify JPEG magic bytes (SOI marker)
      data[0].should eq(0xFF)
      data[1].should eq(0xD8)
    end

    it "encodes a simple RGB image" do
      # Create a simple 16x16 RGB image
      rect = CrImage.rect(0, 0, 16, 16)
      img = CrImage::RGBA.new(rect)

      # Fill with colors
      16.times do |y|
        16.times do |x|
          img.pix[y * 16 * 4 + x * 4] = (x * 16).to_u8     # R
          img.pix[y * 16 * 4 + x * 4 + 1] = (y * 16).to_u8 # G
          img.pix[y * 16 * 4 + x * 4 + 2] = 128_u8         # B
          img.pix[y * 16 * 4 + x * 4 + 3] = 255_u8         # A
        end
      end

      # Write to IO
      io = IO::Memory.new
      CrImage::JPEG.write(io, img, 75)

      # Verify we got some data
      io.rewind
      data = io.to_slice
      data.size.should be > 200

      # Verify JPEG magic bytes
      data[0].should eq(0xFF)
      data[1].should eq(0xD8)

      # Verify EOI marker at end
      data[data.size - 2].should eq(0xFF)
      data[data.size - 1].should eq(0xD9)
    end

    it "validates quality parameter" do
      rect = CrImage.rect(0, 0, 8, 8)
      img = CrImage::Gray.new(rect)
      io = IO::Memory.new

      # Test invalid quality values
      expect_raises(CrImage::JPEG::FormatError, /Quality must be between 1 and 100/) do
        CrImage::JPEG.write(io, img, 0)
      end

      expect_raises(CrImage::JPEG::FormatError, /Quality must be between 1 and 100/) do
        CrImage::JPEG.write(io, img, 101)
      end
    end

    it "writes to file" do
      rect = CrImage.rect(0, 0, 8, 8)
      img = CrImage::Gray.new(rect)

      path = File.tempname("test_jpeg_write", ".jpg")
      CrImage::JPEG.write(path, img, 75)

      # Verify file exists and has content
      File.exists?(path).should be_true
      File.size(path).should be > 100

      # Clean up
      File.delete(path)
    end

    it "round-trip test: encode then decode grayscale" do
      # Create a simple grayscale image
      rect = CrImage.rect(0, 0, 16, 16)
      original = CrImage::Gray.new(rect)

      # Fill with pattern
      16.times do |y|
        16.times do |x|
          original.pix[y * 16 + x] = ((x + y) * 8).to_u8
        end
      end

      # Encode
      io = IO::Memory.new
      CrImage::JPEG.write(io, original, 90)

      # Decode
      io.rewind
      decoded = CrImage::JPEG.read(io)

      # Verify dimensions
      decoded.bounds.width.should eq(16)
      decoded.bounds.height.should eq(16)
    end
  end
end
