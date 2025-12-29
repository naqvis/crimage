require "../spec_helper"

describe CrImage::Transform do
  describe ".grayscale!" do
    it "converts RGBA image to grayscale in-place" do
      img = CrImage.rgba(10, 10)

      # Fill with red
      img.fill(CrImage::Color.rgb(255, 0, 0))

      # Convert to grayscale
      CrImage::Transform.grayscale!(img)

      # Check that all pixels are gray (R=G=B)
      color = img.at(5, 5)
      r, g, b, a = color.rgba
      r.should eq(g)
      g.should eq(b)
      a.should eq(0xffff) # Alpha preserved
    end

    it "preserves alpha channel" do
      img = CrImage.rgba(10, 10)

      # Fill with semi-transparent red
      img.fill(CrImage::Color.rgba(255, 0, 0, 128))

      # Convert to grayscale
      CrImage::Transform.grayscale!(img)

      # Check alpha is preserved
      color = img.at(5, 5)
      _, _, _, a = color.rgba
      (a >> 8).should eq(128)
    end

    it "uses correct luminance formula" do
      img = CrImage.rgba(1, 1)

      # Pure red
      img.set(0, 0, CrImage::Color.rgb(255, 0, 0))
      CrImage::Transform.grayscale!(img)
      r1, _, _, _ = img.at(0, 0).rgba

      # Pure green
      img.set(0, 0, CrImage::Color.rgb(0, 255, 0))
      CrImage::Transform.grayscale!(img)
      r2, _, _, _ = img.at(0, 0).rgba

      # Pure blue
      img.set(0, 0, CrImage::Color.rgb(0, 0, 255))
      CrImage::Transform.grayscale!(img)
      r3, _, _, _ = img.at(0, 0).rgba

      # Green should contribute most to luminance
      r2.should be > r1
      r2.should be > r3
    end

    it "raises error for non-RGBA images" do
      img = CrImage.gray(10, 10)

      expect_raises(ArgumentError, /RGBA/) do
        CrImage::Transform.grayscale!(img)
      end
    end

    it "handles entire image" do
      img = CrImage.rgba(20, 20)

      # Fill with different colors
      10.times do |y|
        20.times do |x|
          img.set(x, y, CrImage::Color.rgb(x * 10, y * 10, 128))
        end
      end

      # Convert to grayscale
      CrImage::Transform.grayscale!(img)

      # Verify all pixels are grayscale
      20.times do |y|
        20.times do |x|
          r, g, b, _ = img.at(x, y).rgba
          r.should eq(g)
          g.should eq(b)
        end
      end
    end

    it "modifies original image" do
      img = CrImage.rgba(5, 5)
      img.fill(CrImage::Color.rgb(255, 0, 0))

      # Get original color
      r_before, _, _, _ = img.at(2, 2).rgba

      # Convert to grayscale
      CrImage::Transform.grayscale!(img)

      # Color should be different
      r_after, g_after, b_after, _ = img.at(2, 2).rgba
      r_after.should_not eq(r_before)
      r_after.should eq(g_after)
      g_after.should eq(b_after)
    end

    it "works with method chaining" do
      img = CrImage.rgba(10, 10)
      img.fill(CrImage::Color.rgb(200, 100, 50))

      # Chain operations
      result = img.grayscale!.brightness!(20)

      result.should be(img) # Returns self

      # Verify it's grayscale
      r, g, b, _ = img.at(5, 5).rgba
      r.should eq(g)
      g.should eq(b)
    end
  end
end
