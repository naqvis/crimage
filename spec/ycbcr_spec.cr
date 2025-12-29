require "./spec_helper"

module CrImage
  describe "Image YCbCr tests" do
    it "Test YCbCr" do
      rects = [
        rect(0, 0, 16, 16),
        rect(1, 0, 16, 16),
        rect(0, 1, 16, 16),
        rect(1, 1, 16, 16),
        rect(1, 1, 15, 16),
        rect(1, 1, 16, 15),
        rect(1, 1, 15, 15),
        rect(2, 3, 14, 15),
        rect(7, 0, 7, 16),
        rect(0, 8, 16, 8),
        rect(0, 0, 10, 11),
        rect(5, 6, 16, 16),
        rect(7, 7, 8, 8),
        rect(7, 8, 8, 9),
        rect(8, 7, 9, 8),
        rect(8, 8, 9, 9),
        rect(7, 7, 17, 17),
        rect(8, 8, 17, 17),
        rect(9, 9, 17, 17),
        rect(10, 10, 17, 17),
      ]

      sub_sample_ratios = [
        YCbCrSubSampleRatio::YCbCrSubsampleRatio444,
        YCbCrSubSampleRatio::YCbCrSubsampleRatio422,
        YCbCrSubSampleRatio::YCbCrSubsampleRatio420,
        YCbCrSubSampleRatio::YCbCrSubsampleRatio440,
        YCbCrSubSampleRatio::YCbCrSubsampleRatio411,
        YCbCrSubSampleRatio::YCbCrSubsampleRatio410,
      ]

      deltas = [
        Point.new(0, 0),
        Point.new(1000, 1001),
        Point.new(5001, -400),
        Point.new(-701, -801),
      ]

      rects.each do |r|
        sub_sample_ratios.each do |sub_sample_ratio|
          deltas.each do |delta|
            # create a YCbCr image m, whose bounds are r translated by (delta.x, delta.y)
            r1 = r + delta
            m = YCbCr.new(r1, sub_sample_ratio)

            # test that the image buffer is reasonably small even if (delta.x, delta.y) is far from the origin.
            if m.y.size > 100*100
              fail "r = #{r.to_s}, sub_sample_ratio = #{sub_sample_ratio}, delta = #{delta.to_s}: image buffer too large"
            end

            # initialize m's pixels. For 422 adn 420 subsampling, some of the cb and cr elements
            # will be set multiple times. That's OK. We just want to avoid a uniform image.
            y = r1.min.y
            while y < r1.max.y
              x = r1.min.x
              while x < r1.max.x
                yi = m.y_offset(x, y)
                ci = m.c_offset(x, y)

                m.y[yi] = (16*y + x).to_u8!
                m.cb[ci] = (y + 16*x).to_u8!
                m.cr[ci] = (y + 16*x).to_u8!
                x += 1
              end
              y += 1
            end

            # Make various sub-images of m.
            (delta.y + 3).upto(delta.y + 6) do |y0|
              (delta.y + 8).upto(delta.y + 12) do |y1|
                (delta.x + 3).upto(delta.x + 6) do |x0|
                  (delta.x + 8).upto(delta.x + 12) do |x1|
                    sub_rect = rect(x0, y0, x1, y1)
                    sub = m.sub_image(sub_rect).as(YCbCr)

                    # For each point in the sub-image's bounds, check that m.at(x,y) equals sub.at(x,y)
                    y = sub.rect.min.y
                    while y < sub.rect.max.y
                      x = sub.rect.min.x
                      while x < sub.rect.max.x
                        color0 = m.at(x, y).as(Color::YCbCr)
                        color1 = sub.at(x, y).as(Color::YCbCr)
                        unless color0 == color1
                          fail "r = #{r.to_s}, sub_sample_ratio = #{sub_sample_ratio}, delta = #{delta.to_s}, x = #{x}, y = #{y}, color0 = #{color0}, color1 = #{color1}"
                        end
                        x += 1
                      end
                      y += 1
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    it "Test YCbCr Slices Don't Overlap" do
      m = YCbCr.new(rect(0, 0, 8, 8), YCbCrSubSampleRatio::YCbCrSubsampleRatio420)
      names = ["y", "cb", "cr"]
      slices = [
        m.y[..],
        m.cb[..],
        m.cr[..],
      ]

      slices.each_with_index do |s, i|
        want = (10 + i).to_u8
        s.map! { |_| want }
      end
      slices.each_with_index do |s, i|
        want = (10 + i).to_u8
        s.each_with_index do |got, j|
          unless got == want
            fail "m.#{names[i]}[#{j}]: got #{got}, want #{want}"
          end
        end
      end
    end
  end
end
