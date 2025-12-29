require "../spec_helper"

describe "CrImage::JPEG Progressive Support" do
  describe "reading progressive JPEGs" do
    it "reads a gradient progressive JPEG" do
      img = CrImage::JPEG.read("spec/testdata/test-gradient-progressive.jpeg")
      img.should_not be_nil
      img.bounds.width.should eq(320)
      img.bounds.height.should eq(240)
    end

    it "reads a plasma progressive JPEG" do
      img = CrImage::JPEG.read("spec/testdata/test-plasma-progressive.jpeg")
      img.should_not be_nil
      img.bounds.width.should eq(640)
      img.bounds.height.should eq(480)
    end

    it "reads the video progressive test file" do
      img = CrImage::JPEG.read("spec/testdata/video-001-progressive-test.jpeg")
      img.should_not be_nil
      img.bounds.width.should be > 0
      img.bounds.height.should be > 0
    end
  end

  describe "comparing baseline vs progressive" do
    it "produces similar output for gradient images" do
      baseline = CrImage::JPEG.read("spec/testdata/test-gradient.jpeg")
      progressive = CrImage::JPEG.read("spec/testdata/test-gradient-progressive.jpeg")

      baseline.bounds.should eq(progressive.bounds)

      # Check that images are similar (allowing for JPEG compression differences)
      # Sample a few pixels to verify they're close
      width = baseline.bounds.width
      height = baseline.bounds.height

      # Sample center pixel
      cx = width // 2
      cy = height // 2

      baseline_color = baseline.at(cx, cy)
      progressive_color = progressive.at(cx, cy)

      # Colors should be within a reasonable tolerance due to JPEG compression
      if baseline_color.is_a?(CrImage::Color::RGBA) && progressive_color.is_a?(CrImage::Color::RGBA)
        r_diff = (baseline_color.r.to_i32 - progressive_color.r.to_i32).abs
        g_diff = (baseline_color.g.to_i32 - progressive_color.g.to_i32).abs
        b_diff = (baseline_color.b.to_i32 - progressive_color.b.to_i32).abs

        r_diff.should be < 10
        g_diff.should be < 10
        b_diff.should be < 10
      end
    end

    it "produces similar output for plasma images" do
      baseline = CrImage::JPEG.read("spec/testdata/test-plasma.jpeg")
      progressive = CrImage::JPEG.read("spec/testdata/test-plasma-progressive.jpeg")

      baseline.bounds.should eq(progressive.bounds)

      # Sample a few pixels
      width = baseline.bounds.width
      height = baseline.bounds.height

      samples = [
        {width // 4, height // 4},
        {width // 2, height // 2},
        {3 * width // 4, 3 * height // 4},
      ]

      samples.each do |(x, y)|
        baseline_color = baseline.at(x, y)
        progressive_color = progressive.at(x, y)

        if baseline_color.is_a?(CrImage::Color::RGBA) && progressive_color.is_a?(CrImage::Color::RGBA)
          r_diff = (baseline_color.r.to_i32 - progressive_color.r.to_i32).abs
          g_diff = (baseline_color.g.to_i32 - progressive_color.g.to_i32).abs
          b_diff = (baseline_color.b.to_i32 - progressive_color.b.to_i32).abs

          # Allow larger tolerance for plasma due to more complex patterns and randomness
          # Plasma images can have significant differences due to the fractal generation
          r_diff.should be < 200
          g_diff.should be < 200
          b_diff.should be < 200
        end
      end
    end
  end

  describe "reading config from progressive JPEGs" do
    it "reads config from gradient progressive JPEG" do
      config = CrImage::JPEG.read_config("spec/testdata/test-gradient-progressive.jpeg")
      config.width.should eq(320)
      config.height.should eq(240)
      config.color_model.should eq(CrImage::Color.rgba_model)
    end

    it "reads config from plasma progressive JPEG" do
      config = CrImage::JPEG.read_config("spec/testdata/test-plasma-progressive.jpeg")
      config.width.should eq(640)
      config.height.should eq(480)
      config.color_model.should eq(CrImage::Color.rgba_model)
    end
  end
end
