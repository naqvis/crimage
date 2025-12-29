require "./spec_helper"

module CrImage
  private def self.cmp(cm : Color::Model, c0 : Color::Color, c1 : Color::Color) : Bool
    r0, g0, b0, a0 = cm.convert(c0).rgba
    r1, g1, b1, a1 = cm.convert(c1).rgba
    r0 == r1 && g0 == g1 && b0 == b1 && a0 == a1
  end

  describe "Image Tests" do
    it "Test Image" do
      tests = [
        {name: "rgba", image: RGBA.new(rect(0, 0, 10, 10))},
        {name: "rgba64", image: RGBA64.new(rect(0, 0, 10, 10))},
        {name: "nrgba", image: NRGBA.new(rect(0, 0, 10, 10))},
        {name: "nrgba64", image: NRGBA64.new(rect(0, 0, 10, 10))},
        {name: "alpha", image: Alpha.new(rect(0, 0, 10, 10))},
        {name: "alpha16", image: Alpha16.new(rect(0, 0, 10, 10))},
        {name: "gray", image: Gray.new(rect(0, 0, 10, 10))},
        {name: "gray16", image: Gray16.new(rect(0, 0, 10, 10))},
        {name: "paletted", image: Paletted.new(rect(0, 0, 10, 10), Color::Palette.new([Color::TRANSPARENT.as(Color::Color), Color::OPAQUE]))},
      ]

      tests.each do |tc|
        m = tc[:image]
        unless rect(0, 0, 10, 10).eq(m.bounds)
          fail "#{tc[:name]}: want bounds rect(0,0,10,10), got #{m.bounds}"
        end
        unless cmp(m.color_model, Color::TRANSPARENT, m.at(6, 3))
          fail "#{tc[:name]}: at (6,3), want a zero color, got #{m.at(6, 3)}"
        end
        m.set(6, 3, Color::OPAQUE)
        unless cmp(m.color_model, Color::OPAQUE, m.at(6, 3))
          fail "#{tc[:name]}: at (6,3), want a non-zero color #{m.color_model.convert(Color::OPAQUE)}, got #{m.at(6, 3)}"
        end
        unless m.sub_image(rect(6, 3, 7, 4)).opaque?
          fail "#{tc[:name]}: at (6,3) was not opaque"
        end
        m = m.sub_image(rect(3, 2, 9, 8))
        unless rect(3, 2, 9, 8).eq(m.bounds)
          fail "#{tc[:name]}: sub-image want bounds rect(3,2,9,8), got #{m.bounds.to_s}"
        end
        unless cmp(m.color_model, Color::OPAQUE, m.at(6, 3))
          fail "#{tc[:name]}: at (6,3), want a non-zero color, got #{m.at(6, 3)}"
        end
        unless cmp(m.color_model, Color::TRANSPARENT, m.at(3, 3))
          fail "#{tc[:name]}: at (3,3), want a zero color, got #{m.at(3, 3)}"
        end
        m.set(3, 3, Color::OPAQUE)
        unless cmp(m.color_model, Color::OPAQUE, m.at(3, 3))
          fail "#{tc[:name]}: at (3,3), want a non-zero color, got #{m.at(3, 3)}"
        end

        # test that taking an empty sub-image starting at corners doesn't raise exception
        m.sub_image(rect(0, 0, 0, 0))
        m.sub_image(rect(10, 0, 10, 0))
        m.sub_image(rect(0, 10, 0, 10))
        m.sub_image(rect(10, 10, 10, 10))
      end
    end

    it "Test 16 Bits Per Color Channel" do
      tests = [
        {name: "RGBA64", m: Color.rgba64_model},
        {name: "RGBA64", m: Color.nrgba64_model},
        {name: "RGBA64", m: Color.alpha16_model},
        {name: "RGBA64", m: Color.gray16_model},
      ]

      tests.each do |cm|
        c = cm[:m].convert(Color::RGBA64.new(0x1234, 0x1234, 0x1234, 0x1234)) # Premultiplied alpha.
        r, _, _, _ = c.rgba
        unless r == 0x1234
          fail "#{cm[:name]}: want red value 0x1234, got #{sprintf("0x%x", r)}"
        end
      end
      test_image = [
        {name: "RGBA64", m: RGBA64.new(rect(0, 0, 10, 10))},
        {name: "NRGBA64", m: NRGBA64.new(rect(0, 0, 10, 10))},
        {name: "Alpha16", m: Alpha16.new(rect(0, 0, 10, 10))},
        {name: "Gray16", m: Gray16.new(rect(0, 0, 10, 10))},
      ]
      test_image.each do |cm|
        m = cm[:m]
        m.set(1, 2, Color::NRGBA64.new(0xffff, 0xffff, 0xffff, 0x1357)) # Non-premultiplied alpha
        r, _, _, _ = m.at(1, 2).rgba
        unless r == 0x1357
          fail "#{cm[:name]}: want red value 0x1357, got #{sprintf("0x%x", r)}"
        end
      end
    end
  end
end
