require "../spec_helper"

module CrImage::WEBP
  describe Writer do
    describe ".write_bitstream" do
      it "generates bitstream for 1x1 opaque image" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(1, 1)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 255_u8))

        data, has_alpha = Writer.write_bitstream(img)

        data.size.should be > 0
        has_alpha.should be_false
        # First byte should be magic byte
        data[0].should eq(0x2f)
      end

      it "generates bitstream for 2x2 image with alpha" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(2, 2)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(255_u8, 0_u8, 0_u8, 128_u8))
        img.set_nrgba(1, 0, CrImage::Color::NRGBA.new(0_u8, 255_u8, 0_u8, 255_u8))
        img.set_nrgba(0, 1, CrImage::Color::NRGBA.new(0_u8, 0_u8, 255_u8, 255_u8))
        img.set_nrgba(1, 1, CrImage::Color::NRGBA.new(255_u8, 255_u8, 255_u8, 255_u8))

        data, has_alpha = Writer.write_bitstream(img)

        data.size.should be > 0
        has_alpha.should be_true
        data[0].should eq(0x2f)
      end

      it "pads bitstream to even length" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(1, 1)))
        img.set_nrgba(0, 0, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 255_u8))

        data, _ = Writer.write_bitstream(img)

        # Length should be even
        (data.size % 2).should eq(0)
      end

      it "generates bitstream for solid color image" do
        img = CrImage::NRGBA.new(Rectangle.new(Point.new(0, 0), Point.new(4, 4)))
        color = CrImage::Color::NRGBA.new(128_u8, 128_u8, 128_u8, 255_u8)

        4.times do |y|
          4.times do |x|
            img.set_nrgba(x, y, color)
          end
        end

        data, has_alpha = Writer.write_bitstream(img)

        data.size.should be > 0
        has_alpha.should be_false
        # Should compress well due to repetition
        data.size.should be < 4 * 4 * 4 # Much smaller than uncompressed
      end
    end
  end
end
