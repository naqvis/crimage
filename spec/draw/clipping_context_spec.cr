require "../spec_helper"

describe CrImage do
  describe "ClippedImage" do
    it "restricts set operations to clip bounds" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      clipped = CrImage::ClippedImage.new(img, CrImage.rect(25, 25, 75, 75))

      # Set pixel inside clip region
      clipped.set(50, 50, CrImage::Color::RED)
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200

      # Set pixel outside clip region (should be ignored)
      clipped.set(10, 10, CrImage::Color::BLUE)
      r, g, b, _ = img.at(10, 10).rgba
      (r >> 8).should eq(255) # Still white
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "returns clip bounds as image bounds" do
      img = CrImage.rgba(100, 100)
      clip_rect = CrImage.rect(20, 30, 80, 70)
      clipped = CrImage::ClippedImage.new(img, clip_rect)

      clipped.bounds.should eq(clip_rect)
    end

    it "delegates at() to inner image" do
      img = CrImage.rgba(100, 100, CrImage::Color::RED)
      clipped = CrImage::ClippedImage.new(img, CrImage.rect(25, 25, 75, 75))

      # Can read any pixel (not just clipped region)
      r, _, _, _ = clipped.at(10, 10).rgba
      (r >> 8).should be > 200
    end

    it "delegates color_model to inner image" do
      img = CrImage.rgba(100, 100)
      clipped = CrImage::ClippedImage.new(img, CrImage.rect(25, 25, 75, 75))

      clipped.color_model.should eq(img.color_model)
    end
  end

  describe "with_clip" do
    it "clips drawing operations to specified region" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      img.with_clip(25, 25, 50, 50) do |clipped|
        # Fill the entire clipped region with red
        (0...100).each do |y|
          (0...100).each do |x|
            clipped.set(x, y, CrImage::Color::RED)
          end
        end
      end

      # Inside clip region should be red
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200
      (g >> 8).should be < 50

      # Outside clip region should still be white
      r, g, b, _ = img.at(10, 10).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)

      r, g, b, _ = img.at(80, 80).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
    end

    it "works with rectangle parameter" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      clip_rect = CrImage.rect(10, 10, 40, 40)

      img.with_clip(clip_rect) do |clipped|
        clipped.set(25, 25, CrImage::Color::GREEN)
        clipped.set(5, 5, CrImage::Color::BLUE) # Outside, should be ignored
      end

      # Inside should be green
      _, g, _, _ = img.at(25, 25).rgba
      (g >> 8).should be > 200

      # Outside should still be white
      r, g, b, _ = img.at(5, 5).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end

    it "intersects clip with image bounds" do
      img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

      # Clip region extends beyond image bounds
      img.with_clip(-10, -10, 100, 100) do |clipped|
        clipped.bounds.should eq(CrImage.rect(0, 0, 50, 50))
      end
    end

    it "handles empty clip region" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      block_called = false

      # Clip region outside image bounds
      img.with_clip(200, 200, 50, 50) do |clipped|
        block_called = true
      end

      block_called.should be_false
    end

    it "works with Draw module functions" do
      img = CrImage.rgba(200, 200, CrImage::Color::WHITE)

      img.with_clip(50, 50, 100, 100) do |clipped|
        # Draw a circle that would overflow the clip region
        style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED, fill: true)
        CrImage::Draw.circle(clipped, CrImage.point(50, 50), 80, style)
      end

      # Center of circle (inside clip) should be red
      r, _, _, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200

      # Outside clip region should be white even though circle would extend there
      r, g, b, _ = img.at(10, 10).rgba
      (r >> 8).should eq(255)
      (g >> 8).should eq(255)
      (b >> 8).should eq(255)
    end
  end

  describe "ClipContext" do
    it "checks if point is in clip region" do
      img = CrImage.rgba(100, 100)
      ctx = CrImage::ClipContext.new(img, CrImage.rect(20, 20, 80, 80))

      ctx.in_clip?(50, 50).should be_true
      ctx.in_clip?(10, 10).should be_false
      ctx.in_clip?(20, 20).should be_true  # Min is inclusive
      ctx.in_clip?(80, 80).should be_false # Max is exclusive
    end

    it "clips rectangles to clip region" do
      img = CrImage.rgba(100, 100)
      ctx = CrImage::ClipContext.new(img, CrImage.rect(20, 20, 80, 80))

      # Rectangle fully inside
      result = ctx.clip(CrImage.rect(30, 30, 70, 70))
      result.should eq(CrImage.rect(30, 30, 70, 70))

      # Rectangle partially outside
      result = ctx.clip(CrImage.rect(10, 10, 50, 50))
      result.should eq(CrImage.rect(20, 20, 50, 50))

      # Rectangle fully outside
      result = ctx.clip(CrImage.rect(0, 0, 10, 10))
      result.empty.should be_true
    end
  end
end
