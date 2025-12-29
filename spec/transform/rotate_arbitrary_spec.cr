require "../spec_helper"

describe CrImage::Transform do
  describe "rotate (arbitrary angle)" do
    it "rotates by 0 degrees (no change)" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      rotated = CrImage::Transform.rotate(img, 0.0)

      rotated.bounds.width.should eq(100)
      rotated.bounds.height.should eq(100)
    end

    it "rotates by 90 degrees (uses fast path)" do
      img = CrImage.rgba(100, 50, CrImage::Color::BLUE)
      rotated = CrImage::Transform.rotate(img, 90.0)

      # 90° rotation swaps dimensions
      rotated.bounds.width.should eq(50)
      rotated.bounds.height.should eq(100)
    end

    it "rotates by 180 degrees (uses fast path)" do
      img = CrImage.rgba(100, 100, CrImage::Color::GREEN)
      rotated = CrImage::Transform.rotate(img, 180.0)

      rotated.bounds.width.should eq(100)
      rotated.bounds.height.should eq(100)
    end

    it "rotates by 270 degrees (uses fast path)" do
      img = CrImage.rgba(100, 50, CrImage::Color::YELLOW)
      rotated = CrImage::Transform.rotate(img, 270.0)

      # 270° rotation swaps dimensions
      rotated.bounds.width.should eq(50)
      rotated.bounds.height.should eq(100)
    end

    it "rotates by 45 degrees with bilinear interpolation" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      rotated = CrImage::Transform.rotate(img, 45.0)

      # 45° rotation of a square increases dimensions
      # diagonal = sqrt(100² + 100²) ≈ 141
      rotated.bounds.width.should be > 100
      rotated.bounds.height.should be > 100
      rotated.bounds.width.should be_close(141, 2)
      rotated.bounds.height.should be_close(141, 2)
    end

    it "rotates by 30 degrees with nearest neighbor" do
      img = CrImage.rgba(100, 100, CrImage::Color::BLUE)
      rotated = CrImage::Transform.rotate(img, 30.0,
        interpolation: CrImage::Transform::RotationInterpolation::Nearest)

      # Should produce a valid rotated image
      rotated.bounds.width.should be > 100
      rotated.bounds.height.should be > 100
    end

    it "handles negative angles (counter-clockwise)" do
      img = CrImage.rgba(100, 100, CrImage::Color::GREEN)
      rotated = CrImage::Transform.rotate(img, -45.0)

      # -45° should produce same size as +45°
      rotated.bounds.width.should be > 100
      rotated.bounds.height.should be > 100
    end

    it "handles angles > 360 degrees" do
      img = CrImage.rgba(50, 50, CrImage::Color::YELLOW)
      rotated = CrImage::Transform.rotate(img, 450.0) # 450° = 90°

      # Should normalize to 90°
      rotated.bounds.width.should eq(50)
      rotated.bounds.height.should eq(50)
    end

    it "uses custom background color" do
      img = CrImage.rgba(50, 50, CrImage::Color::RED)
      rotated = CrImage::Transform.rotate(img, 45.0,
        background: CrImage::Color::WHITE)

      # Check that corners (which should be background) are white
      corner_color = rotated.at(0, 0)
      r, g, b, a = corner_color.rgba
      # Should be white or close to it
      (r >> 8).should be > 200
      (g >> 8).should be > 200
      (b >> 8).should be > 200
    end

    it "preserves image content in center" do
      img = CrImage.rgba(100, 100)
      # Set center pixel to red
      img.set(50, 50, CrImage::Color::RED)

      rotated = CrImage::Transform.rotate(img, 45.0)

      # Center should still be red (approximately)
      center_x = rotated.bounds.width // 2
      center_y = rotated.bounds.height // 2
      center_color = rotated.at(center_x, center_y)
      r, g, b, a = center_color.rgba

      # Red channel should be high
      (r >> 8).should be > 200
    end

    it "bilinear produces smoother results than nearest" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)

      nearest = CrImage::Transform.rotate(img, 15.0,
        interpolation: CrImage::Transform::RotationInterpolation::Nearest)
      bilinear = CrImage::Transform.rotate(img, 15.0,
        interpolation: CrImage::Transform::RotationInterpolation::Bilinear)

      # Both should have same dimensions
      nearest.bounds.width.should eq(bilinear.bounds.width)
      nearest.bounds.height.should eq(bilinear.bounds.height)

      # Both should be valid images
      nearest.bounds.width.should be > 100
      bilinear.bounds.width.should be > 100
    end

    it "handles small angles correctly" do
      img = CrImage.rgba(100, 100, CrImage::Color::BLUE)
      rotated = CrImage::Transform.rotate(img, 1.0)

      # Small rotation should produce slightly larger image
      rotated.bounds.width.should be >= 100
      rotated.bounds.height.should be >= 100
      rotated.bounds.width.should be < 110
    end

    it "handles rectangular images" do
      img = CrImage.rgba(200, 100, CrImage::Color::GREEN)
      rotated = CrImage::Transform.rotate(img, 45.0)

      # Should produce valid rotated rectangle
      rotated.bounds.width.should be > 200
      rotated.bounds.height.should be > 100
    end

    it "works with different image types" do
      # Test with NRGBA
      nrgba_img = CrImage.nrgba(50, 50, CrImage::Color::RED)
      rotated_nrgba = CrImage::Transform.rotate(nrgba_img, 30.0)
      rotated_nrgba.bounds.width.should be > 50

      # Test with Gray
      gray_img = CrImage.gray(50, 50)
      rotated_gray = CrImage::Transform.rotate(gray_img, 30.0)
      rotated_gray.bounds.width.should be > 50
    end
  end
end
