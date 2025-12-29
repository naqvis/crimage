require "../spec_helper"

module CrImage
  describe "Image Type Specific Tests" do
    describe "Uniform Image" do
      it "has infinite bounds" do
        img = Uniform.new(Color::RGBA.new(128, 128, 128, 255))

        bounds = img.bounds
        bounds.width.should be > 1_000_000
        bounds.height.should be > 1_000_000
      end

      it "returns same color everywhere" do
        color = Color::RGBA.new(128, 128, 128, 255)
        img = Uniform.new(color)

        img.at(0, 0).should eq(color)
        img.at(1000, 1000).should eq(color)
        img.at(-1000, -1000).should eq(color)
      end

      it "changes color with set" do
        img = Uniform.new(Color::RGBA.new(0, 0, 0, 255))
        new_color = Color::RGBA.new(255, 255, 255, 255)

        img.set(0, 0, new_color)
        img.at(0, 0).should eq(new_color)
      end

      it "reports opaque correctly" do
        img = Uniform.new(Color::RGBA.new(128, 128, 128, 255))
        img.opaque?.should be_true

        img2 = Uniform.new(Color::RGBA.new(128, 128, 128, 128))
        img2.opaque?.should be_false
      end
    end

    describe "CMYK Image" do
      it "creates CMYK image" do
        img = CMYK.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets CMYK pixels" do
        img = CMYK.new(rect(0, 0, 10, 10))
        color = Color::CMYK.new(0, 255, 255, 0)

        img.set(5, 5, color)
        result = img.at(5, 5).as(Color::CMYK)

        result.c.should eq(0)
        result.m.should eq(255)
        result.y.should eq(255)
        result.k.should eq(0)
      end

      it "is always opaque" do
        img = CMYK.new(rect(0, 0, 10, 10))
        img.opaque?.should be_true
      end

      it "creates sub-image" do
        img = CMYK.new(rect(0, 0, 10, 10))
        sub = img.sub_image(rect(2, 2, 8, 8))

        sub.bounds.width.should eq(6)
      end
    end

    describe "Alpha Image" do
      it "creates Alpha image" do
        img = Alpha.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets alpha values" do
        img = Alpha.new(rect(0, 0, 10, 10))

        img.set(5, 5, Color::Alpha.new(128))
        result = img.at(5, 5).as(Color::Alpha)

        result.a.should eq(128)
      end

      it "reports opaque correctly" do
        img = Alpha.new(rect(0, 0, 10, 10))

        # Fill with opaque
        10.times do |y|
          10.times do |x|
            img.set(x, y, Color::Alpha.new(255))
          end
        end

        img.opaque?.should be_true

        # Set one transparent pixel
        img.set(5, 5, Color::Alpha.new(128))
        img.opaque?.should be_false
      end
    end

    describe "Alpha16 Image" do
      it "creates Alpha16 image" do
        img = Alpha16.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets 16-bit alpha values" do
        img = Alpha16.new(rect(0, 0, 10, 10))

        img.set(5, 5, Color::Alpha16.new(0x8000))
        result = img.at(5, 5).as(Color::Alpha16)

        result.a.should eq(0x8000)
      end

      it "reports opaque correctly" do
        img = Alpha16.new(rect(0, 0, 10, 10))

        # Fill with opaque
        10.times do |y|
          10.times do |x|
            img.set(x, y, Color::Alpha16.new(0xffff))
          end
        end

        img.opaque?.should be_true
      end
    end

    describe "Gray16 Image" do
      it "creates Gray16 image" do
        img = Gray16.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets 16-bit gray values" do
        img = Gray16.new(rect(0, 0, 10, 10))

        img.set(5, 5, Color::Gray16.new(0x8000))
        result = img.at(5, 5).as(Color::Gray16)

        result.y.should eq(0x8000)
      end

      it "is always opaque" do
        img = Gray16.new(rect(0, 0, 10, 10))
        img.opaque?.should be_true
      end
    end

    describe "Paletted Image" do
      it "creates paletted image with palette" do
        palette = Color::Palette.new([
          Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
          Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
        ])
        img = Paletted.new(rect(0, 0, 10, 10), palette)

        img.palette.size.should eq(2)
      end

      it "sets and gets palette indices" do
        palette = Color::Palette.new([
          Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
          Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
        ])
        img = Paletted.new(rect(0, 0, 10, 10), palette)

        img.set_color_index(5, 5, 1_u8)
        idx = img.color_index_at(5, 5)

        idx.should eq(1)
      end

      it "reports opaque correctly" do
        palette = Color::Palette.new([
          Color::RGBA.new(0, 0, 0, 255).as(Color::Color),
          Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
        ])
        img = Paletted.new(rect(0, 0, 10, 10), palette)

        # Fill with index 0
        10.times do |y|
          10.times do |x|
            img.set_color_index(x, y, 0_u8)
          end
        end

        img.opaque?.should be_true
      end

      it "handles transparent palette colors" do
        palette = Color::Palette.new([
          Color::RGBA.new(0, 0, 0, 0).as(Color::Color),
          Color::RGBA.new(255, 255, 255, 255).as(Color::Color),
        ])
        img = Paletted.new(rect(0, 0, 10, 10), palette)

        # Use transparent color
        img.set_color_index(5, 5, 0_u8)

        img.opaque?.should be_false
      end
    end

    describe "RGBA64 Image" do
      it "creates RGBA64 image" do
        img = RGBA64.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets 16-bit RGBA values" do
        img = RGBA64.new(rect(0, 0, 10, 10))
        color = Color::RGBA64.new(0xffff, 0x8000, 0x4000, 0xffff)

        img.set(5, 5, color)
        result = img.at(5, 5).as(Color::RGBA64)

        result.r.should eq(0xffff)
        result.g.should eq(0x8000)
        result.b.should eq(0x4000)
        result.a.should eq(0xffff)
      end

      it "reports opaque correctly" do
        img = RGBA64.new(rect(0, 0, 10, 10))

        # Fill with opaque
        10.times do |y|
          10.times do |x|
            img.set(x, y, Color::RGBA64.new(0, 0, 0, 0xffff))
          end
        end

        img.opaque?.should be_true
      end
    end

    describe "NRGBA64 Image" do
      it "creates NRGBA64 image" do
        img = NRGBA64.new(rect(0, 0, 10, 10))
        img.bounds.width.should eq(10)
      end

      it "sets and gets 16-bit NRGBA values" do
        img = NRGBA64.new(rect(0, 0, 10, 10))
        color = Color::NRGBA64.new(0xffff, 0x8000, 0x4000, 0x8000)

        img.set(5, 5, color)
        result = img.at(5, 5).as(Color::NRGBA64)

        result.r.should eq(0xffff)
        result.g.should eq(0x8000)
        result.b.should eq(0x4000)
        result.a.should eq(0x8000)
      end

      it "reports opaque correctly" do
        img = NRGBA64.new(rect(0, 0, 10, 10))

        # Fill with opaque
        10.times do |y|
          10.times do |x|
            img.set(x, y, Color::NRGBA64.new(0, 0, 0, 0xffff))
          end
        end

        img.opaque?.should be_true
      end
    end
  end
end
