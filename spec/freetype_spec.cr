require "./spec_helper"

describe FreeType::TrueType do
  describe "Font parsing" do
    it "should parse a valid TrueType font" do
      # Create a minimal valid TrueType font header
      data = Bytes.new(1024, 0_u8)

      # TrueType signature
      data[0] = 0x00_u8
      data[1] = 0x01_u8
      data[2] = 0x00_u8
      data[3] = 0x00_u8

      # Number of tables
      data[4] = 0x00_u8
      data[5] = 0x03_u8 # 3 tables

      # Search range, entry selector, range shift
      data[6] = 0x00_u8
      data[7] = 0x30_u8
      data[8] = 0x00_u8
      data[9] = 0x01_u8
      data[10] = 0x00_u8
      data[11] = 0x00_u8

      # Table 1: head
      offset = 12
      data[offset] = 'h'.ord.to_u8
      data[offset + 1] = 'e'.ord.to_u8
      data[offset + 2] = 'a'.ord.to_u8
      data[offset + 3] = 'd'.ord.to_u8
      # Checksum
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x00_u8
      data[offset + 6] = 0x00_u8
      data[offset + 7] = 0x00_u8
      # Offset
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x01_u8
      data[offset + 11] = 0x00_u8 # Offset 256
      # Length
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x00_u8
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x36_u8 # 54 bytes

      # Table 2: maxp
      offset = 28
      data[offset] = 'm'.ord.to_u8
      data[offset + 1] = 'a'.ord.to_u8
      data[offset + 2] = 'x'.ord.to_u8
      data[offset + 3] = 'p'.ord.to_u8
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x02_u8
      data[offset + 11] = 0x00_u8 # Offset 512
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x00_u8
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x20_u8 # 32 bytes

      # Table 3: loca
      offset = 44
      data[offset] = 'l'.ord.to_u8
      data[offset + 1] = 'o'.ord.to_u8
      data[offset + 2] = 'c'.ord.to_u8
      data[offset + 3] = 'a'.ord.to_u8
      data[offset + 8] = 0x00_u8
      data[offset + 9] = 0x00_u8
      data[offset + 10] = 0x03_u8
      data[offset + 11] = 0x00_u8 # Offset 768
      data[offset + 12] = 0x00_u8
      data[offset + 13] = 0x00_u8
      data[offset + 14] = 0x00_u8
      data[offset + 15] = 0x10_u8 # 16 bytes

      # head table data at offset 256
      offset = 256
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8 # version
      # Units per EM at offset 18
      data[offset + 18] = 0x08_u8
      data[offset + 19] = 0x00_u8 # 2048 units per EM
      # Index to loc format at offset 50
      data[offset + 50] = 0x00_u8
      data[offset + 51] = 0x00_u8 # Short format

      # maxp table data at offset 512
      offset = 512
      data[offset] = 0x00_u8
      data[offset + 1] = 0x01_u8
      data[offset + 2] = 0x00_u8
      data[offset + 3] = 0x00_u8 # version
      # Num glyphs at offset 4
      data[offset + 4] = 0x00_u8
      data[offset + 5] = 0x0A_u8 # 10 glyphs

      font = FreeType::TrueType::Font.new(data)
      font.should_not be_nil
    end
  end

  describe "Rasterizer" do
    it "should create a rasterizer" do
      rasterizer = FreeType::Raster::Rasterizer.new
      rasterizer.should_not be_nil
      rasterizer.use_non_zero_winding.should eq(false)
      rasterizer.dx.should eq(0)
      rasterizer.dy.should eq(0)
    end

    it "should handle start and add1" do
      rasterizer = FreeType::Raster::Rasterizer.new

      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[64],
        CrImage::Math::Fixed::Int26_6[64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[128],
        CrImage::Math::Fixed::Int26_6[128]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)
    end

    it "should rasterize to an alpha image" do
      rasterizer = FreeType::Raster::Rasterizer.new
      rasterizer.reset(100, 100) # Reset before use
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 100, 100))

      # Draw a simple square
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[10 * 64]
      )
      p3 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[50 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )
      p4 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[10 * 64],
        CrImage::Math::Fixed::Int26_6[50 * 64]
      )

      rasterizer.start(p1)
      rasterizer.add1(p2)
      rasterizer.add1(p3)
      rasterizer.add1(p4)
      rasterizer.add1(p1)

      painter = FreeType::Raster::AlphaSrcPainter.new(image)
      rasterizer.rasterize(painter, 100, 100)

      # Check that some pixels were painted
      has_painted = false
      image.pix.each do |pixel|
        if pixel > 0
          has_painted = true
          break
        end
      end
      has_painted.should eq(true)
    end
  end

  describe "Fixed point math" do
    it "should handle Int26_6 operations" do
      a = CrImage::Math::Fixed::Int26_6[64]  # 1.0
      b = CrImage::Math::Fixed::Int26_6[128] # 2.0

      (a + b).should eq(CrImage::Math::Fixed::Int26_6[192])
      (b - a).should eq(CrImage::Math::Fixed::Int26_6[64])
      a.floor.should eq(1)
      b.floor.should eq(2)
    end

    it "should handle Point26_6 operations" do
      p1 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[64],
        CrImage::Math::Fixed::Int26_6[128]
      )
      p2 = CrImage::Math::Fixed::Point26_6.new(
        CrImage::Math::Fixed::Int26_6[32],
        CrImage::Math::Fixed::Int26_6[64]
      )

      p3 = p1 + p2
      p3.x.should eq(CrImage::Math::Fixed::Int26_6[96])
      p3.y.should eq(CrImage::Math::Fixed::Int26_6[192])
    end
  end

  describe "Painters" do
    it "should paint to Alpha image" do
      image = CrImage::Alpha.new(CrImage.rect(0, 0, 10, 10))
      painter = FreeType::Raster::AlphaSrcPainter.new(image)

      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 2, x1: 8, alpha: 0xffff_u32),
      ]

      painter.paint(spans, true)

      # Check that pixels were painted
      offset = 5 * image.stride + 2
      image.pix[offset].should be > 0
    end

    it "should paint to RGBA image" do
      image = CrImage::RGBA.new(CrImage.rect(0, 0, 10, 10))
      painter = FreeType::Raster::RGBAPainter.new(image, CrImage::Draw::Op::SRC)
      painter.color = CrImage::Color::RGBA.new(255, 0, 0, 255)

      spans = [
        FreeType::Raster::Span.new(y: 5, x0: 2, x1: 8, alpha: 0xffff_u32),
      ]

      painter.paint(spans, true)

      # Check that pixels were painted red
      offset = 5 * image.stride + 2 * 4
      image.pix[offset].should be > 0 # Red channel
    end
  end
end
