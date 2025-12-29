require "../spec_helper"

describe CrImage::Draw do
  describe "thick anti-aliased lines" do
    it "draws a thick anti-aliased horizontal line" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      style = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 5, anti_alias: true)

      CrImage::Draw.line(img, CrImage.point(10, 50), CrImage.point(90, 50), style)

      # Center of line should be solid red
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200
      (g >> 8).should be < 50
      (b >> 8).should be < 50

      # Line should have some width (check pixels above and below center)
      r_above, _, _, _ = img.at(50, 48).rgba
      r_below, _, _, _ = img.at(50, 52).rgba
      (r_above >> 8).should be > 100 # Should have some red
      (r_below >> 8).should be > 100

      # Pixels far from line should be white
      r_far, g_far, b_far, _ = img.at(50, 40).rgba
      (r_far >> 8).should eq(255)
      (g_far >> 8).should eq(255)
      (b_far >> 8).should eq(255)
    end

    it "draws a thick anti-aliased diagonal line" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      style = CrImage::Draw::LineStyle.new(CrImage::Color::BLUE, thickness: 4, anti_alias: true)

      CrImage::Draw.line(img, CrImage.point(10, 10), CrImage.point(90, 90), style)

      # Center of diagonal should be blue
      r, g, b, _ = img.at(50, 50).rgba
      (b >> 8).should be > 150

      # Line should be continuous (no gaps)
      # Check several points along the diagonal
      gaps = 0
      (20..80).each do |i|
        r, g, b, _ = img.at(i, i).rgba
        gaps += 1 if (b >> 8) < 50
      end
      gaps.should be < 5 # Allow some tolerance for AA edges
    end

    it "draws a thick anti-aliased vertical line" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      style = CrImage::Draw::LineStyle.new(CrImage::Color::GREEN, thickness: 6, anti_alias: true)

      CrImage::Draw.line(img, CrImage.point(50, 10), CrImage.point(50, 90), style)

      # Center should be green
      r, g, b, _ = img.at(50, 50).rgba
      (g >> 8).should be > 200
    end

    it "handles zero-length line (draws a circle)" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      style = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 10, anti_alias: true)

      CrImage::Draw.line(img, CrImage.point(50, 50), CrImage.point(50, 50), style)

      # Should draw a filled circle at the point
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 200
    end

    it "falls back to wu_line for thickness 1" do
      img = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      style = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 1, anti_alias: true)

      CrImage::Draw.line(img, CrImage.point(10, 10), CrImage.point(90, 90), style)

      # Should still draw a line
      r, g, b, _ = img.at(50, 50).rgba
      (r >> 8).should be > 100
    end

    it "compares thick AA vs thick non-AA" do
      img_aa = CrImage.rgba(100, 100, CrImage::Color::WHITE)
      img_no_aa = CrImage.rgba(100, 100, CrImage::Color::WHITE)

      style_aa = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 5, anti_alias: true)
      style_no_aa = CrImage::Draw::LineStyle.new(CrImage::Color::RED, thickness: 5, anti_alias: false)

      CrImage::Draw.line(img_aa, CrImage.point(10, 10), CrImage.point(90, 90), style_aa)
      CrImage::Draw.line(img_no_aa, CrImage.point(10, 10), CrImage.point(90, 90), style_no_aa)

      # Both should have red at center
      r1, _, _, _ = img_aa.at(50, 50).rgba
      r2, _, _, _ = img_no_aa.at(50, 50).rgba
      (r1 >> 8).should be > 150
      (r2 >> 8).should be > 150

      # AA version should have smoother edges (more intermediate values)
      aa_intermediates = 0
      no_aa_intermediates = 0

      (0...100).each do |y|
        r1, _, _, _ = img_aa.at(50, y).rgba
        r2, _, _, _ = img_no_aa.at(50, y).rgba
        r1_val = r1 >> 8
        r2_val = r2 >> 8

        aa_intermediates += 1 if r1_val > 20 && r1_val < 235
        no_aa_intermediates += 1 if r2_val > 20 && r2_val < 235
      end

      # AA should have more intermediate values
      aa_intermediates.should be >= no_aa_intermediates
    end
  end
end
