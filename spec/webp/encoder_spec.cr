require "../spec_helper"

module CrImage::WEBP
  # Helper to generate test images
  def self.generate_test_image_nrgba(width : Int32, height : Int32, brightness : Float64, has_alpha : Bool) : CrImage::NRGBA
    img = CrImage::NRGBA.new(CrImage::Rectangle.new(CrImage::Point.new(0, 0), CrImage::Point.new(width, height)))

    height.times do |y|
      width.times do |x|
        # Calculate pixel value with brightness factor
        # This allows overflow/wrapping
        n = ((x ^ y).to_f64 * brightness).to_i32.to_u8!
        a = has_alpha ? n : 255_u8

        # creates RGBA (premultiplied) then converts to NRGBA
        # We need to simulate this conversion
        rgba_r, rgba_g, rgba_b = if y < height // 2
                                   if x < width // 2
                                     {n, 0_u8, 0_u8}
                                   else
                                     {0_u8, n, 0_u8}
                                   end
                                 else
                                   if x < width // 2
                                     {0_u8, 0_u8, n}
                                   else
                                     {n, n, 0_u8}
                                   end
                                 end

        # Convert from RGBA (premultiplied) to NRGBA (non-premultiplied)
        nrgba_r, nrgba_g, nrgba_b = if a == 0
                                      {0_u8, 0_u8, 0_u8}
                                    else
                                      {
                                        ((rgba_r.to_u16 * 255) // a.to_u16).to_u8,
                                        ((rgba_g.to_u16 * 255) // a.to_u16).to_u8,
                                        ((rgba_b.to_u16 * 255) // a.to_u16).to_u8,
                                      }
                                    end

        c = CrImage::Color::NRGBA.new(nrgba_r, nrgba_g, nrgba_b, a)
        img.set_nrgba(x, y, c)
      end
    end

    img
  end

  describe Encoder do
    describe ".write to file path" do
      it "encodes image to file" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
        img.set_nrgba(1, 0, CrImage::Color::NRGBA.new(0_u8, 255_u8, 0_u8, 255_u8))
        img.set_nrgba(0, 1, CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8))
        img.set_nrgba(1, 1, CrImage::Color::NRGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

        path = File.tempname("webp_test", ".webp")
        begin
          Encoder.write(path, img)

          File.exists?(path).should be_true
          File.size(path).should be > 0

          # Verify RIFF header
          File.open(path, "rb") do |file|
            header = Bytes.new(4)
            file.read_fully(header)
            String.new(header).should eq("RIFF")
          end
        ensure
          File.delete(path) if File.exists?(path)
        end
      end

      it "raises error for nil image" do
        path = File.tempname("webp_test", ".webp")
        expect_raises(ArgumentError, "Image cannot be nil") do
          Encoder.write(path, nil)
        end
      end

      it "raises error for invalid dimensions (zero width)" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(0, 1)))
        path = File.tempname("webp_test", ".webp")

        expect_raises(ArgumentError, /must have at least 1 pixel/) do
          Encoder.write(path, img)
        end
      end

      it "raises error for invalid dimensions (too large)" do
        # Create image with dimensions exceeding 16384
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(16385, 1)))
        path = File.tempname("webp_test", ".webp")

        expect_raises(ArgumentError, /must be between 1 and 16384 pixels/) do
          Encoder.write(path, img)
        end
      end
    end

    describe ".write to IO stream" do
      it "encodes 8x8 test image with valid structure (no extended format)" do
        img = CrImage::WEBP.generate_test_image_nrgba(8, 8, 64.0, true)

        io = IO::Memory.new
        options = Options.new(use_extended_format: false)
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Verify RIFF header
        String.new(data[0, 4]).should eq("RIFF")
        String.new(data[8, 4]).should eq("WEBP")
        String.new(data[12, 4]).should eq("VP8L")

        # Verify VP8L magic byte
        data[20].should eq(0x2f)

        # Verify dimensions (7 = 8-1, encoded in 14 bits)
        # Width-1 in bits 8-21 of VP8L header
        # Height-1 in bits 22-35 of VP8L header
        # Alpha flag in bit 36
        # The header bytes should match
        data[21].should eq(0x07) # First 8 bits of width-1
        data[22].should eq(0xc0) # Last 6 bits of width-1 + first 2 bits of height-1
        data[23].should eq(0x01) # Next 8 bits of height-1
        data[24].should eq(0x10) # Last 4 bits of height-1 + alpha flag + version

        # Verify transform headers match (subtract green + predictor)
        data[25].should eq(0x8d) # Transform bits
        data[26].should eq(0x52) # More transform bits

        # Verify the file can be decoded
        io.rewind
        decoded = CrImage::WEBP.read(io)
        decoded.bounds.width.should eq(8)
        decoded.bounds.height.should eq(8)

        # Verify file size is reasonable (should be close to expected)
        # Allow some variation due to different Huffman encoding
        data.size.should be_close(216, 10)
      end

      it "encodes image to IO stream" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
        img.set_nrgba(1, 0, CrImage::Color::NRGBA.new(0_u8, 255_u8, 0_u8, 255_u8))
        img.set_nrgba(0, 1, CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8))
        img.set_nrgba(1, 1, CrImage::Color::NRGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

        io = IO::Memory.new
        Encoder.write(io, img)

        io.rewind
        data = io.to_slice

        data.size.should be > 0

        # Verify RIFF header
        String.new(data[0, 4]).should eq("RIFF")

        # Verify WEBP form type
        String.new(data[8, 4]).should eq("WEBP")
      end

      it "encodes with extended format enabled" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Should contain VP8X chunk
        String.new(data[12, 4]).should eq("VP8X")
      end

      it "encodes with extended format disabled" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        options = Options.new(use_extended_format: false)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Should contain VP8L chunk directly (no VP8X)
        String.new(data[12, 4]).should eq("VP8L")
      end

      it "raises error for nil image" do
        io = IO::Memory.new
        expect_raises(ArgumentError, "Image cannot be nil") do
          Encoder.write(io, nil)
        end
      end

      it "raises error for invalid dimensions" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(0, 1)))
        io = IO::Memory.new

        expect_raises(ArgumentError, /must have at least 1 pixel/) do
          Encoder.write(io, img)
        end
      end
    end

    describe "image conversion" do
      it "converts RGBA image to NRGBA" do
        rgba = CrImage::RGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        rgba.set_rgba(0, 0, CrImage::Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
        rgba.set_rgba(1, 0, CrImage::Color::RGBA.new(0_u8, 255_u8, 0_u8, 255_u8))

        io = IO::Memory.new
        Encoder.write(io, rgba)

        io.rewind
        data = io.to_slice
        data.size.should be > 0
        String.new(data[0, 4]).should eq("RIFF")
      end

      it "converts Gray image to NRGBA" do
        gray = CrImage::Gray.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        gray.set_gray(0, 0, CrImage::Color::Gray.new(128_u8))
        gray.set_gray(1, 0, CrImage::Color::Gray.new(255_u8))

        io = IO::Memory.new
        Encoder.write(io, gray)

        io.rewind
        data = io.to_slice
        data.size.should be > 0
        String.new(data[0, 4]).should eq("RIFF")
      end
    end

    describe "VP8X chunk" do
      it "sets alpha flag when image has transparency" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 128_u8)) # Semi-transparent

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Find VP8X chunk and check flags
        # VP8X starts at byte 12
        String.new(data[12, 4]).should eq("VP8X")

        # Flags are at byte 20 (after fourcc + size)
        flags = data[20]
        (flags & 0x10).should eq(0x10) # Alpha flag should be set
      end

      it "does not set alpha flag when image is opaque" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        # Set all pixels to fully opaque (alpha = 255)
        2.times do |y|
          2.times do |x|
            img.set_nrgba(x, y, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
          end
        end

        # Verify image is actually opaque
        img.opaque?.should be_true

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Find VP8X chunk and check flags
        String.new(data[12, 4]).should eq("VP8X")

        # Flags are at byte 20
        flags = data[20]
        (flags & 0x10).should eq(0x00) # Alpha flag should not be set
      end

      it "encodes correct canvas dimensions" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(100, 50)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Canvas width is at bytes 24-26 (width - 1)
        width = data[24].to_u32 | (data[25].to_u32 << 8) | (data[26].to_u32 << 16)
        width.should eq(99) # 100 - 1

        # Canvas height is at bytes 27-29 (height - 1)
        height = data[27].to_u32 | (data[28].to_u32 << 8) | (data[29].to_u32 << 16)
        height.should eq(49) # 50 - 1
      end
    end

    describe "VP8L chunk" do
      it "contains valid VP8L bitstream" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        io = IO::Memory.new
        Encoder.write(io, img)

        io.rewind
        data = io.to_slice

        # VP8L chunk starts at byte 12 (no VP8X)
        String.new(data[12, 4]).should eq("VP8L")

        # Get VP8L chunk size
        chunk_size = data[16].to_u32 | (data[17].to_u32 << 8) | (data[18].to_u32 << 16) | (data[19].to_u32 << 24)
        chunk_size.should be > 0

        # First byte of VP8L data should be magic byte 0x2f
        data[20].should eq(0x2f)
      end
    end

    describe "round-trip encoding and decoding" do
      it "encodes and decodes a simple image" do
        # Create original image
        original = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(4, 4)))
        4.times do |y|
          4.times do |x|
            original.set_nrgba(x, y, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))
          end
        end

        # Encode to memory
        io = IO::Memory.new
        Encoder.write(io, original)

        # Decode back
        io.rewind
        decoded = CrImage::WEBP.read(io)

        # Verify dimensions
        decoded.bounds.width.should eq(4)
        decoded.bounds.height.should eq(4)

        # Verify pixel colors (allowing for lossless compression artifacts)
        color = decoded.at(0, 0)
        r, g, b, a = color.rgba
        (r >> 8).should eq(255)
        (g >> 8).should eq(0)
        (b >> 8).should eq(0)
        (a >> 8).should eq(255)
      end

      it "encodes and decodes image with transparency" do
        original = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        original.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 128_u8))
        original.set_nrgba(1, 0, CrImage::Color::NRGBA.new(0_u8, 255_u8, 0_u8, 255_u8))
        original.set_nrgba(0, 1, CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8))
        original.set_nrgba(1, 1, CrImage::Color::NRGBA.new(255_u8, 255_u8, 255_u8, 0_u8))

        io = IO::Memory.new
        Encoder.write(io, original)

        io.rewind
        decoded = CrImage::WEBP.read(io)

        decoded.bounds.width.should eq(2)
        decoded.bounds.height.should eq(2)

        # Check semi-transparent pixel
        color = decoded.at(0, 0)
        _, _, _, a = color.rgba
        (a >> 8).should be_close(128, 5) # Allow small tolerance
      end

      it "encodes and decodes with extended format" do
        original = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(3, 3)))
        3.times do |y|
          3.times do |x|
            original.set_nrgba(x, y, CrImage::Color::NRGBA.new(100_u8, 150_u8, 200_u8, 255_u8))
          end
        end

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, original, options)

        io.rewind
        decoded = CrImage::WEBP.read(io)

        decoded.bounds.width.should eq(3)
        decoded.bounds.height.should eq(3)
      end

      it "round-trips to file" do
        original = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        original.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        path = File.tempname("webp_roundtrip", ".webp")
        begin
          Encoder.write(path, original)
          decoded = CrImage::WEBP.read(path)

          decoded.bounds.width.should eq(2)
          decoded.bounds.height.should eq(2)
        ensure
          File.delete(path) if File.exists?(path)
        end
      end
    end

    describe "RIFF container structure" do
      it "has correct RIFF size" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        io = IO::Memory.new
        Encoder.write(io, img)

        io.rewind
        data = io.to_slice

        # RIFF size is at bytes 4-7
        riff_size = data[4].to_u32 | (data[5].to_u32 << 8) | (data[6].to_u32 << 16) | (data[7].to_u32 << 24)

        # Total file size should be RIFF header (8 bytes) + RIFF size
        data.size.should eq(8 + riff_size)
      end

      it "has correct chunk structure without VP8X" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        options = Options.new(use_extended_format: false)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Structure: RIFF (4) + size (4) + WEBP (4) + VP8L (4) + size (4) + data
        String.new(data[0, 4]).should eq("RIFF")
        String.new(data[8, 4]).should eq("WEBP")
        String.new(data[12, 4]).should eq("VP8L")
      end

      it "has correct chunk structure with VP8X" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        options = Options.new(use_extended_format: true)
        io = IO::Memory.new
        Encoder.write(io, img, options)

        io.rewind
        data = io.to_slice

        # Structure: RIFF (4) + size (4) + WEBP (4) + VP8X (4) + size (4) + data (10) + VP8L (4) + size (4) + data
        String.new(data[0, 4]).should eq("RIFF")
        String.new(data[8, 4]).should eq("WEBP")
        String.new(data[12, 4]).should eq("VP8X")

        # VP8X chunk size should be 10
        vp8x_size = data[16].to_u32 | (data[17].to_u32 << 8) | (data[18].to_u32 << 16) | (data[19].to_u32 << 24)
        vp8x_size.should eq(10)

        # VP8L should follow VP8X (12 + 4 + 4 + 10 = 30)
        String.new(data[30, 4]).should eq("VP8L")
      end
    end
  end
end
