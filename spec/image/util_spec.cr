require "../spec_helper"

module CrImage
  describe "Image Utility Tests" do
    it "draws YCbCr 4:4:4 to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio444)

      # Set some YCbCr values
      yi = src.y_offset(5, 5)
      ci = src.c_offset(5, 5)
      src.y[yi] = 128_u8
      src.cb[ci] = 128_u8
      src.cr[ci] = 128_u8

      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)
      result.should be_true

      # Should have drawn gray
      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should be_close(128, 10)
      color.g.should be_close(128, 10)
      color.b.should be_close(128, 10)
    end

    it "draws YCbCr 4:2:2 to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio422)

      # Initialize YCbCr data to avoid index errors
      src.y.size.times { |i| src.y[i] = 128_u8 }
      src.cb.size.times { |i| src.cb[i] = 128_u8 }
      src.cr.size.times { |i| src.cr[i] = 128_u8 }

      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)
      result.should be_true
    end

    it "draws YCbCr 4:2:0 to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio420)

      # Initialize YCbCr data to avoid index errors
      src.y.size.times { |i| src.y[i] = 128_u8 }
      src.cb.size.times { |i| src.cb[i] = 128_u8 }
      src.cr.size.times { |i| src.cr[i] = 128_u8 }

      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)
      result.should be_true
    end

    it "draws YCbCr 4:4:0 to RGBA" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio440)

      # Initialize YCbCr data to avoid index errors
      src.y.size.times { |i| src.y[i] = 128_u8 }
      src.cb.size.times { |i| src.cb[i] = 128_u8 }
      src.cr.size.times { |i| src.cr[i] = 128_u8 }

      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)
      result.should be_true
    end

    it "handles partial rectangle drawing" do
      dst = RGBA.new(rect(0, 0, 20, 20))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio444)

      # Draw to a sub-rectangle
      result = CrImage.draw_ycbcr(dst, rect(5, 5, 15, 15), src, Point.zero)
      result.should be_true
    end

    it "handles source offset" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 20, 20), YCbCrSubSampleRatio::YCbCrSubsampleRatio444)

      # Draw from offset source
      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.new(5, 5))
      result.should be_true
    end

    it "converts YCbCr colors correctly" do
      dst = RGBA.new(rect(0, 0, 10, 10))
      src = YCbCr.new(rect(0, 0, 10, 10), YCbCrSubSampleRatio::YCbCrSubsampleRatio444)

      # Set red in YCbCr space
      yi = src.y_offset(5, 5)
      ci = src.c_offset(5, 5)
      src.y[yi] = 76_u8   # Y for red
      src.cb[ci] = 85_u8  # Cb for red
      src.cr[ci] = 255_u8 # Cr for red

      CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)

      # Should be reddish
      color = dst.at(5, 5).as(Color::RGBA)
      color.r.should be > 200
      color.g.should be < 100
      color.b.should be < 100
    end

    it "handles subsampled chroma correctly" do
      dst = RGBA.new(rect(0, 0, 8, 8))
      src = YCbCr.new(rect(0, 0, 8, 8), YCbCrSubSampleRatio::YCbCrSubsampleRatio420)

      # Initialize chroma to avoid index errors
      src.cb.size.times { |i| src.cb[i] = 128_u8 }
      src.cr.size.times { |i| src.cr[i] = 128_u8 }

      # Fill Y with gradient
      8.times do |y|
        8.times do |x|
          yi = src.y_offset(x, y)
          src.y[yi] = ((x + y) * 16).to_u8
        end
      end

      result = CrImage.draw_ycbcr(dst, dst.bounds, src, Point.zero)
      result.should be_true

      # Should have drawn gradient
      dst.at(0, 0).as(Color::RGBA).r.should be < dst.at(7, 7).as(Color::RGBA).r
    end
  end
end
