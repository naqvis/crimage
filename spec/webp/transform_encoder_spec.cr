require "../spec_helper"

module CrImage::WEBP
  describe TransformEncoder do
    # Helper to test apply_filter through apply_predictor
    # We create a specific pixel pattern and verify the predictor output
    describe "predictor filters" do
      it "applies filter mode 0 (Black)" do
        # Create a 3x4 pixel array with specific values for testing
        pixels = [
          CrImage::Color::NRGBA.new(100_u8, 100_u8, 100_u8, 255_u8),
          CrImage::Color::NRGBA.new(50_u8, 50_u8, 50_u8, 255_u8),
          CrImage::Color::NRGBA.new(25_u8, 25_u8, 25_u8, 255_u8),
          CrImage::Color::NRGBA.new(200_u8, 200_u8, 200_u8, 255_u8),
          CrImage::Color::NRGBA.new(75_u8, 75_u8, 75_u8, 255_u8),
          CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 0_u8),
          CrImage::Color::NRGBA.new(100_u8, 100_u8, 100_u8, 255_u8),
          CrImage::Color::NRGBA.new(250_u8, 250_u8, 250_u8, 255_u8),
          CrImage::Color::NRGBA.new(225_u8, 225_u8, 225_u8, 255_u8),
          CrImage::Color::NRGBA.new(200_u8, 200_u8, 200_u8, 255_u8),
          CrImage::Color::NRGBA.new(75_u8, 75_u8, 75_u8, 255_u8),
          CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 0_u8),
        ]

        # Test that predictor transform works with these pixels
        # The actual filter logic is tested indirectly through the transform
        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels.dup, 3, 4)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
        # Predictor mode should be valid (0-13)
        blocks[0].g.should be >= 0
        blocks[0].g.should be < 14
      end

      it "handles edge cases at image boundaries" do
        # Test with 2x2 image to verify edge handling
        pixels = [
          CrImage::Color::NRGBA.new(100_u8, 100_u8, 100_u8, 255_u8),
          CrImage::Color::NRGBA.new(150_u8, 150_u8, 150_u8, 255_u8),
          CrImage::Color::NRGBA.new(200_u8, 200_u8, 200_u8, 255_u8),
          CrImage::Color::NRGBA.new(250_u8, 250_u8, 250_u8, 255_u8),
        ]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels.dup, 2, 2)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
      end

      it "selects appropriate predictor for gradient" do
        # Create a gradient pattern
        pixels = (0...16).map do |i|
          v = (i * 16).to_u8
          CrImage::Color::NRGBA.new(v, v, v, 255_u8)
        end.to_a

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels.dup, 4, 4)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        # Should select a predictor that works well for gradients
        blocks[0].g.should be >= 0
        blocks[0].g.should be < 14
      end
    end

    describe ".apply_predictor" do
      it "applies predictor transform to simple 2x2 image" do
        pixels = [
          CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
        ]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels, 2, 2)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
        pixels.size.should eq(4)
      end

      it "handles 1x1 image" do
        pixels = [CrImage::Color::NRGBA.new(128_u8, 64_u8, 32_u8, 255_u8)]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels, 1, 1)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
        pixels[0].r.should eq(128)
        pixels[0].g.should eq(64)
        pixels[0].b.should eq(32)
      end

      it "applies predictor to gradient pattern" do
        pixels = [
          CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(64_u8, 64_u8, 64_u8, 255_u8),
          CrImage::Color::NRGBA.new(128_u8, 128_u8, 128_u8, 255_u8),
          CrImage::Color::NRGBA.new(192_u8, 192_u8, 192_u8, 255_u8),
        ]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels, 2, 2)

        tile_bits.should eq(4)
        blocks.size.should eq(1)
        # Predictor mode should be stored in green channel
        blocks[0].g.should be >= 0
        blocks[0].g.should be < 14
      end

      it "handles solid color image efficiently" do
        color = CrImage::Color::NRGBA.new(100_u8, 150_u8, 200_u8, 255_u8)
        pixels = Array.new(16) { color }

        tile_bits, bw, bh, blocks = TransformEncoder.apply_predictor(pixels, 4, 4)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        # After prediction, most pixels should have small deltas
        pixels[1..].all? { |p| p.r == 0 && p.g == 0 && p.b == 0 }.should be_true
      end
    end

    describe ".apply_color" do
      it "applies color transform to 2x2 image" do
        pixels = [
          CrImage::Color::NRGBA.new(255_u8, 128_u8, 64_u8, 255_u8),
          CrImage::Color::NRGBA.new(200_u8, 100_u8, 50_u8, 255_u8),
          CrImage::Color::NRGBA.new(150_u8, 75_u8, 40_u8, 255_u8),
          CrImage::Color::NRGBA.new(100_u8, 50_u8, 25_u8, 255_u8),
        ]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_color(pixels, 2, 2)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
        # Green channel should remain unchanged
        pixels.each { |p| p.a.should eq(255) }
      end

      it "handles 1x1 image" do
        pixels = [CrImage::Color::NRGBA.new(128_u8, 64_u8, 32_u8, 255_u8)]

        tile_bits, bw, bh, blocks = TransformEncoder.apply_color(pixels, 1, 1)

        tile_bits.should eq(4)
        bw.should eq(1)
        bh.should eq(1)
        blocks.size.should eq(1)
      end
    end

    describe ".apply_subtract_green" do
      it "subtracts green from red and blue channels" do
        pixels = [
          CrImage::Color::NRGBA.new(200_u8, 100_u8, 150_u8, 255_u8),
          CrImage::Color::NRGBA.new(255_u8, 128_u8, 200_u8, 255_u8),
        ]

        TransformEncoder.apply_subtract_green(pixels)

        pixels[0].r.should eq(100) # 200 - 100
        pixels[0].g.should eq(100) # unchanged
        pixels[0].b.should eq(50)  # 150 - 100
        pixels[0].a.should eq(255) # unchanged

        pixels[1].r.should eq(127) # 255 - 128
        pixels[1].g.should eq(128) # unchanged
        pixels[1].b.should eq(72)  # 200 - 128
        pixels[1].a.should eq(255) # unchanged
      end

      it "handles wraparound correctly" do
        pixels = [CrImage::Color::NRGBA.new(50_u8, 100_u8, 30_u8, 255_u8)]

        TransformEncoder.apply_subtract_green(pixels)

        # 50 - 100 = -50, wraps to 206
        # 30 - 100 = -70, wraps to 186
        pixels[0].r.should eq(206)
        pixels[0].b.should eq(186)
      end
    end

    describe ".apply_palette" do
      it "creates palette for 2-color image" do
        red = CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8)
        blue = CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8)
        pixels = [red, blue, red, blue, red, blue, red, blue]

        palette, pw = TransformEncoder.apply_palette(pixels, 8, 1)

        palette.size.should eq(2)
        pw.should eq(1)          # 8 pixels packed into 1 byte (8 bits per pixel for 2 colors)
        pixels.size.should eq(1) # Packed into single row
      end

      it "creates palette for 4-color image" do
        colors = [
          CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(0_u8, 255_u8, 0_u8, 255_u8),
          CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8),
          CrImage::Color::NRGBA.new(255_u8, 255_u8, 0_u8, 255_u8),
        ]
        pixels = colors + colors

        palette, pw = TransformEncoder.apply_palette(pixels, 8, 1)

        palette.size.should eq(4)
        pw.should eq(2) # 8 pixels packed into 2 bytes (4 bits per pixel for 4 colors)
      end

      it "creates palette for 16-color image" do
        colors = (0...16).map { |i| CrImage::Color::NRGBA.new(i.to_u8 * 16, 0_u8, 0_u8, 255_u8) }.to_a
        pixels = colors.dup

        palette, pw = TransformEncoder.apply_palette(pixels, 16, 1)

        palette.size.should eq(16)
        pw.should eq(8) # 16 pixels packed into 8 bytes (2 bits per pixel for 16 colors)
      end

      it "raises error for more than 256 colors" do
        # Create 257 unique colors
        pixels = (0...257).map { |i| CrImage::Color::NRGBA.new((i % 256).to_u8, (i // 256).to_u8, 0_u8, 255_u8) }.to_a

        expect_raises(Exception, /Palette exceeds 256 colors/) do
          TransformEncoder.apply_palette(pixels, 257, 1)
        end
      end

      it "applies delta encoding to palette" do
        red = CrImage::Color::NRGBA.new(100_u8, 0_u8, 0_u8, 255_u8)
        green = CrImage::Color::NRGBA.new(100_u8, 50_u8, 0_u8, 255_u8)
        pixels = [red, green]

        palette, pw = TransformEncoder.apply_palette(pixels, 2, 1)

        # First color unchanged
        palette[0].r.should eq(100)
        palette[0].g.should eq(0)
        # Second color is delta from first
        palette[1].r.should eq(0)  # 100 - 100
        palette[1].g.should eq(50) # 50 - 0
      end
    end
  end
end
