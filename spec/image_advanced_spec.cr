require "./spec_helper"

module CrImage
  describe "Image Module Tests" do
    describe "Image Constants" do
      it "BLACK is opaque black uniform image" do
        BLACK.should be_a(Uniform)
        color = BLACK.at(0, 0)
        r, g, b, a = color.rgba
        (r >> 8).should eq(0)
        (g >> 8).should eq(0)
        (b >> 8).should eq(0)
        (a >> 8).should eq(255)
      end

      it "WHITE is opaque white uniform image" do
        WHITE.should be_a(Uniform)
        color = WHITE.at(0, 0)
        r, g, b, a = color.rgba
        (r >> 8).should eq(255)
        (g >> 8).should eq(255)
        (b >> 8).should eq(255)
        (a >> 8).should eq(255)
      end

      it "TRANSPARENT is fully transparent uniform image" do
        TRANSPARENT.should be_a(Uniform)
        color = TRANSPARENT.at(0, 0)
        r, g, b, a = color.rgba
        (a >> 8).should eq(0)
      end

      it "OPAQUE is fully opaque uniform image" do
        OPAQUE.should be_a(Uniform)
        color = OPAQUE.at(0, 0)
        r, g, b, a = color.rgba
        (a >> 8).should eq(255)
      end
    end

    describe "Config" do
      it "creates config with color model and dimensions" do
        config = Config.new(Color.rgba_model, 100, 200)
        config.color_model.should eq(Color.rgba_model)
        config.width.should eq(100)
        config.height.should eq(200)
      end

      it "allows property access" do
        config = Config.new(Color.gray_model, 50, 75)
        config.width = 60
        config.height = 80
        config.width.should eq(60)
        config.height.should eq(80)
      end
    end

    describe "UnknownFormat Exception" do
      it "creates exception with default message" do
        ex = UnknownFormat.new
        ex.message.should_not be_nil
        ex.message.to_s.should contain("Unknown image format")
      end

      it "creates exception with custom message" do
        ex = UnknownFormat.new("Custom error")
        ex.message.should eq("Custom error")
      end
    end

    describe "Format Registration" do
      it "registers supported formats" do
        formats = CrImage.supported_formats
        formats.should_not be_empty
        formats.should contain("png")
        formats.should contain("jpeg")
        formats.should contain("bmp")
      end

      it "reads PNG image" do
        img = CrImage.read("spec/testdata/video-001.png")
        img.should_not be_nil
        img.bounds.width.should be > 0
        img.bounds.height.should be > 0
      end

      it "reads JPEG image" do
        img = CrImage.read("spec/testdata/video-001.jpeg")
        img.should_not be_nil
        img.bounds.width.should be > 0
        img.bounds.height.should be > 0
      end

      it "reads config from PNG" do
        config = CrImage.read_config("spec/testdata/video-001.png")
        config.width.should be > 0
        config.height.should be > 0
      end

      it "reads config from JPEG" do
        config = CrImage.read_config("spec/testdata/video-001.jpeg")
        config.width.should be > 0
        config.height.should be > 0
      end

      it "raises UnknownFormat for invalid file" do
        expect_raises(UnknownFormat) do
          io = IO::Memory.new("INVALID DATA".to_slice)
          CrImage.read(io)
        end
      end

      it "reads from IO stream" do
        File.open("spec/testdata/video-001.png") do |file|
          img = CrImage.read(file)
          img.should_not be_nil
        end
      end

      it "reads config from IO stream" do
        File.open("spec/testdata/video-001.png") do |file|
          config = CrImage.read_config(file)
          config.width.should be > 0
        end
      end
    end

    describe "Image Interface" do
      it "supports bracket notation for at" do
        img = RGBA.new(CrImage.rect(0, 0, 10, 10))
        img.set(5, 5, Color::RGBA.new(255, 0, 0, 255))
        color = img[5, 5]
        color.should_not be_nil
      end

      it "supports bracket notation for set" do
        img = RGBA.new(CrImage.rect(0, 0, 10, 10))
        img[5, 5] = Color::RGBA.new(255, 0, 0, 255)
        color = img.at(5, 5).as(Color::RGBA)
        color.r.should eq(255)
      end
    end

    describe "Sub-image functionality" do
      it "creates sub-image with shared pixel data" do
        m0 = RGBA.new(CrImage.rect(0, 0, 8, 5))
        m1 = m0.sub_image(CrImage.rect(1, 2, 5, 5)).as(RGBA)

        m0.bounds.width.should eq(8)
        m1.bounds.width.should eq(4)
        m0.stride.should eq(m1.stride)
      end

      it "modifying sub-image affects original" do
        m0 = RGBA.new(CrImage.rect(0, 0, 10, 10))
        m1 = m0.sub_image(CrImage.rect(2, 2, 8, 8)).as(RGBA)

        m1.set(3, 3, Color::RGBA.new(255, 0, 0, 255))

        # Pixel at (3,3) in sub-image is at (3,3) in original
        color = m0.at(3, 3).as(Color::RGBA)
        color.r.should eq(255)
      end
    end

    describe "Bounds checking" do
      it "set does nothing for out of bounds coordinates" do
        img = RGBA.new(CrImage.rect(0, 0, 10, 10))
        img.set(15, 15, Color::RGBA.new(255, 0, 0, 255))
        # Should not crash
      end

      it "iterates correctly over image bounds" do
        img = RGBA.new(CrImage.rect(2, 3, 12, 13))
        count = 0

        b = img.bounds
        b.min.y.upto(b.max.y - 1) do |y|
          b.min.x.upto(b.max.x - 1) do |x|
            img.set(x, y, Color::RGBA.new(255, 0, 0, 255))
            count += 1
          end
        end

        count.should eq(100) # 10x10 image
      end
    end
  end
end
