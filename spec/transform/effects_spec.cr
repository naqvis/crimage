require "../spec_helper"

describe CrImage::Transform do
  describe "visual effects" do
    describe "sepia" do
      it "applies sepia tone to image" do
        img = CrImage.rgba(50, 50)
        50.times do |y|
          50.times do |x|
            img.set(x, y, CrImage::Color.rgba(100, 150, 200, 255))
          end
        end

        sepia = img.sepia
        sepia.should be_a(CrImage::RGBA)
        sepia.bounds.width.should eq(50)
        sepia.bounds.height.should eq(50)

        # Sepia should have warm brownish tones
        pixel = sepia.at(25, 25).as(CrImage::Color::RGBA)
        # Red channel should be higher than blue in sepia
        pixel.r.should be > pixel.b
      end

      it "preserves alpha channel" do
        img = CrImage.rgba(10, 10)
        img.fill(CrImage::Color.rgba(100, 100, 100, 128))

        sepia = img.sepia
        pixel = sepia.at(5, 5).as(CrImage::Color::RGBA)
        pixel.a.should eq(128)
      end
    end

    describe "emboss" do
      it "applies emboss effect" do
        img = CrImage.rgba(50, 50, CrImage::Color::WHITE)
        img.draw_circle(25, 25, 15, color: CrImage::Color::BLACK, fill: true)

        embossed = img.emboss
        embossed.should be_a(CrImage::RGBA)
        embossed.bounds.width.should eq(50)
        embossed.bounds.height.should eq(50)

        # Emboss creates grayscale output
        pixel = embossed.at(25, 25).as(CrImage::Color::RGBA)
        pixel.r.should eq(pixel.g)
        pixel.g.should eq(pixel.b)
      end

      it "accepts custom angle and depth" do
        img = CrImage.rgba(30, 30, CrImage::Color::WHITE)
        img.draw_rect(10, 10, 10, 10, fill: CrImage::Color::BLACK)

        embossed = img.emboss(angle: 135.0, depth: 2.0)
        embossed.should be_a(CrImage::RGBA)
      end

      it "validates depth parameter" do
        img = CrImage.rgba(10, 10)
        expect_raises(ArgumentError) do
          img.emboss(depth: 0.3)
        end
        expect_raises(ArgumentError) do
          img.emboss(depth: 3.0)
        end
      end
    end

    describe "vignette" do
      it "applies vignette effect" do
        img = CrImage.rgba(100, 100, CrImage::Color::WHITE)

        vignetted = img.vignette
        vignetted.should be_a(CrImage::RGBA)

        # Center should be brighter than edges
        center = vignetted.at(50, 50).as(CrImage::Color::RGBA)
        edge = vignetted.at(5, 5).as(CrImage::Color::RGBA)
        center.r.should be > edge.r
      end

      it "accepts custom strength and radius" do
        img = CrImage.rgba(50, 50, CrImage::Color::WHITE)

        vignetted = img.vignette(strength: 0.8, radius: 0.5)
        vignetted.should be_a(CrImage::RGBA)
      end

      it "validates parameters" do
        img = CrImage.rgba(10, 10)
        expect_raises(ArgumentError) do
          img.vignette(strength: -0.1)
        end
        expect_raises(ArgumentError) do
          img.vignette(strength: 1.5)
        end
        expect_raises(ArgumentError) do
          img.vignette(radius: 0.05)
        end
      end
    end

    describe "temperature" do
      it "warms image with positive adjustment" do
        img = CrImage.rgba(50, 50)
        img.fill(CrImage::Color.rgba(128, 128, 128, 255))

        warmer = img.temperature(30)
        warmer.should be_a(CrImage::RGBA)

        pixel = warmer.at(25, 25).as(CrImage::Color::RGBA)
        # Red should increase, blue unchanged
        pixel.r.should be > 128
        pixel.b.should eq(128)
      end

      it "cools image with negative adjustment" do
        img = CrImage.rgba(50, 50)
        img.fill(CrImage::Color.rgba(128, 128, 128, 255))

        cooler = img.temperature(-30)
        cooler.should be_a(CrImage::RGBA)

        pixel = cooler.at(25, 25).as(CrImage::Color::RGBA)
        # Blue should increase, red unchanged
        pixel.b.should be > 128
        pixel.r.should eq(128)
      end

      it "validates temperature parameter" do
        img = CrImage.rgba(10, 10)
        expect_raises(ArgumentError) do
          img.temperature(-101)
        end
        expect_raises(ArgumentError) do
          img.temperature(101)
        end
      end
    end
  end
end
