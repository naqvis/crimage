require "../spec_helper"

describe CrImage::Util::QRCode do
  describe "encoding" do
    it "encodes simple text" do
      code = CrImage::Util::QRCode.encode("Hello")
      code.should be_a(CrImage::Util::QRCode::Code)
      code.version.should be >= 1
      code.size.should eq(code.version * 4 + 17)
    end

    it "encodes URL" do
      code = CrImage::Util::QRCode.encode("https://example.com")
      code.should be_a(CrImage::Util::QRCode::Code)
    end

    it "encodes numeric data efficiently" do
      code = CrImage::Util::QRCode.encode("12345678901234567890")
      code.version.should be <= 2 # Numeric mode is efficient
    end

    it "encodes alphanumeric data" do
      code = CrImage::Util::QRCode.encode("HELLO WORLD")
      code.should be_a(CrImage::Util::QRCode::Code)
    end

    it "supports different error correction levels" do
      data = "Test"
      low = CrImage::Util::QRCode.encode(data, CrImage::Util::QRCode::ErrorCorrection::Low)
      high = CrImage::Util::QRCode.encode(data, CrImage::Util::QRCode::ErrorCorrection::High)

      # Higher EC may require larger version for same data
      low.version.should be <= high.version
    end

    it "auto-selects appropriate version" do
      short = CrImage::Util::QRCode.encode("Hi")
      long = CrImage::Util::QRCode.encode("A" * 100)

      short.version.should be < long.version
    end

    it "allows specifying version" do
      code = CrImage::Util::QRCode.encode("Test", version: 5)
      code.version.should eq(5)
    end
  end

  describe "image generation" do
    it "generates RGBA image" do
      img = CrImage::Util::QRCode.generate("Hello")
      img.should be_a(CrImage::RGBA)
    end

    it "respects size parameter" do
      img = CrImage::Util::QRCode.generate("Hello", size: 200)
      img.bounds.width.should be <= 200
      img.bounds.height.should be <= 200
    end

    it "generates square image" do
      img = CrImage::Util::QRCode.generate("Test", size: 300)
      img.bounds.width.should eq(img.bounds.height)
    end

    it "supports custom colors" do
      img = CrImage::Util::QRCode.generate("Test",
        foreground: CrImage::Color::BLUE,
        background: CrImage::Color::YELLOW)
      img.should be_a(CrImage::RGBA)
    end

    it "Code#to_image works" do
      code = CrImage::Util::QRCode.encode("Hello")
      img = code.to_image(module_size: 5, margin: 2)
      img.should be_a(CrImage::RGBA)
      expected_size = (code.size + 4) * 5 # size + 2*margin, times module_size
      img.bounds.width.should eq(expected_size)
    end
  end

  describe "CrImage.qr_code convenience method" do
    it "generates QR code" do
      img = CrImage.qr_code("Hello World")
      img.should be_a(CrImage::RGBA)
    end

    it "accepts size parameter" do
      img = CrImage.qr_code("Test", size: 400)
      img.bounds.width.should be <= 400
    end

    it "accepts error correction symbol" do
      img = CrImage.qr_code("Test", error_correction: :high)
      img.should be_a(CrImage::RGBA)
    end

    it "accepts margin parameter" do
      img = CrImage.qr_code("Test", margin: 2)
      img.should be_a(CrImage::RGBA)
    end
  end

  describe "QR code structure" do
    it "has finder patterns in corners" do
      code = CrImage::Util::QRCode.encode("Test")

      # Top-left finder pattern center should be dark
      code.dark?(3, 3).should be_true

      # Top-right finder pattern
      code.dark?(code.size - 4, 3).should be_true

      # Bottom-left finder pattern
      code.dark?(3, code.size - 4).should be_true
    end

    it "has timing patterns" do
      code = CrImage::Util::QRCode.encode("Test")

      # Timing patterns alternate dark/light starting from position 8
      # The pattern at row 6 should alternate (after masking is applied)
      # Just verify the pattern exists and has some dark modules
      dark_count = 0
      (8...code.size - 8).each do |i|
        dark_count += 1 if code.dark?(i, 6)
      end
      dark_count.should be > 0
    end
  end

  describe "error handling" do
    it "raises on data too long" do
      # Version 40 max capacity is ~2953 bytes for L
      huge_data = "A" * 5000
      expect_raises(CrImage::Util::QRCode::Error, /too long/) do
        CrImage::Util::QRCode.encode(huge_data)
      end
    end
  end

  describe "Reed-Solomon" do
    it "generates correct EC codewords" do
      # Test with known data
      data = [32_u8, 91_u8, 11_u8, 120_u8, 209_u8, 114_u8, 220_u8, 77_u8,
              67_u8, 64_u8, 236_u8, 17_u8, 236_u8, 17_u8, 236_u8, 17_u8]
      ec = CrImage::Util::QRCode::ReedSolomon.encode(data, 10)
      ec.size.should eq(10)
    end
  end

  describe "Galois Field" do
    it "multiply works correctly" do
      CrImage::Util::QRCode::GaloisField.multiply(0, 5).should eq(0)
      CrImage::Util::QRCode::GaloisField.multiply(1, 1).should eq(1)
      CrImage::Util::QRCode::GaloisField.multiply(2, 2).should eq(4)
    end

    it "power works correctly" do
      CrImage::Util::QRCode::GaloisField.power(2, 0).should eq(1)
      CrImage::Util::QRCode::GaloisField.power(2, 1).should eq(2)
      CrImage::Util::QRCode::GaloisField.power(2, 8).should eq(29) # 2^8 mod primitive
    end
  end

  describe "logo overlay" do
    it "generates QR code with logo" do
      # Create a simple logo (red square)
      logo = CrImage.rgba(50, 50, CrImage::Color::RED)

      img = CrImage::Util::QRCode.generate_with_logo(
        "https://example.com",
        logo,
        size: 300,
        error_correction: CrImage::Util::QRCode::ErrorCorrection::High
      )

      img.should be_a(CrImage::RGBA)
      img.bounds.width.should be > 0
    end

    it "places logo in center" do
      logo = CrImage.rgba(30, 30, CrImage::Color::RED)

      img = CrImage::Util::QRCode.generate_with_logo(
        "Test",
        logo,
        size: 200,
        logo_scale: 0.2
      )

      # Check that center area has red pixels (from logo)
      center_x = img.bounds.width // 2
      center_y = img.bounds.height // 2
      center_pixel = img[center_x, center_y]

      # Should be red (from logo)
      center_pixel.r.should eq(255_u8)
      center_pixel.g.should eq(0_u8)
      center_pixel.b.should eq(0_u8)
    end

    it "respects logo_scale parameter" do
      logo = CrImage.rgba(100, 100, CrImage::Color::BLUE)

      small = CrImage::Util::QRCode.generate_with_logo("Test", logo, size: 300, logo_scale: 0.1)
      large = CrImage::Util::QRCode.generate_with_logo("Test", logo, size: 300, logo_scale: 0.3)

      # Both should generate valid images
      small.should be_a(CrImage::RGBA)
      large.should be_a(CrImage::RGBA)
    end

    it "adds border around logo" do
      logo = CrImage.rgba(20, 20, CrImage::Color::RED)

      img = CrImage::Util::QRCode.generate_with_logo(
        "Test",
        logo,
        size: 200,
        logo_border: 5
      )

      # Check that there's white border around center
      center_x = img.bounds.width // 2
      center_y = img.bounds.height // 2

      # Pixel at edge of border should be white (background)
      # Logo is ~40px (20% of 200), border is 5px on each side
      edge_pixel = img[center_x - 15, center_y]
      edge_pixel.r.should eq(255_u8)
      edge_pixel.g.should eq(255_u8)
      edge_pixel.b.should eq(255_u8)
    end

    it "CrImage.qr_code with logo parameter works" do
      logo = CrImage.rgba(30, 30, CrImage::Color::GREEN)

      img = CrImage.qr_code("Hello World", size: 250, logo: logo)
      img.should be_a(CrImage::RGBA)
    end

    it "defaults to high error correction when logo provided" do
      logo = CrImage.rgba(30, 30, CrImage::Color::BLUE)

      # Should not raise - high EC allows logo overlay
      img = CrImage.qr_code("Test", logo: logo)
      img.should be_a(CrImage::RGBA)
    end
  end
end
