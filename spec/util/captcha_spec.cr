require "../spec_helper"

FONT_PATH = "spec/testdata/fonts/Roboto/Roboto-Bold.ttf"
describe CrImage::Util::Captcha do
  describe ".generate" do
    it "generates CAPTCHA with default options" do
      captcha = CrImage::Util::Captcha.generate("TEST", FONT_PATH)
      captcha.bounds.width.should eq 300
      captcha.bounds.height.should eq 100
    end

    it "generates CAPTCHA with custom dimensions" do
      options = CrImage::Util::Captcha::Options.new(width: 400, height: 150)
      captcha = CrImage::Util::Captcha.generate("HELLO", FONT_PATH, options)
      captcha.bounds.width.should eq 400
      captcha.bounds.height.should eq 150
    end

    it "generates CAPTCHA with custom noise level" do
      options = CrImage::Util::Captcha::Options.new(noise_level: 50)
      captcha = CrImage::Util::Captcha.generate("ABC", FONT_PATH, options)
      captcha.should be_a(CrImage::RGBA)
    end

    it "generates CAPTCHA with custom line count" do
      options = CrImage::Util::Captcha::Options.new(line_count: 10)
      captcha = CrImage::Util::Captcha.generate("123", FONT_PATH, options)
      captcha.should be_a(CrImage::RGBA)
    end

    it "generates CAPTCHA with custom background color" do
      options = CrImage::Util::Captcha::Options.new(
        background_color: CrImage::Color.rgb(200, 220, 240)
      )
      captcha = CrImage::Util::Captcha.generate("XYZ", FONT_PATH, options)
      captcha.should be_a(CrImage::RGBA)
    end

    it "generates CAPTCHA with custom wobble strength" do
      options = CrImage::Util::Captcha::Options.new(wobble_strength: 5.0)
      captcha = CrImage::Util::Captcha.generate("WOBBLE", FONT_PATH, options)
      captcha.should be_a(CrImage::RGBA)
    end

    it "generates CAPTCHA with custom rotation range" do
      options = CrImage::Util::Captcha::Options.new(rotation_range: 30.0)
      captcha = CrImage::Util::Captcha.generate("ROTATE", FONT_PATH, options)
      captcha.should be_a(CrImage::RGBA)
    end

    it "raises error for empty text" do
      expect_raises(ArgumentError, "Text cannot be empty") do
        CrImage::Util::Captcha.generate("", FONT_PATH)
      end
    end

    it "raises error for non-existent font" do
      expect_raises(ArgumentError, /Font file not found/) do
        CrImage::Util::Captcha.generate("TEST", "nonexistent.ttf")
      end
    end

    it "generates different images for same text" do
      captcha1 = CrImage::Util::Captcha.generate("SAME", FONT_PATH)
      captcha2 = CrImage::Util::Captcha.generate("SAME", FONT_PATH)

      # Images should be different due to randomization
      different = false
      captcha1.bounds.height.times do |y|
        captcha1.bounds.width.times do |x|
          if captcha1.at(x, y) != captcha2.at(x, y)
            different = true
            break
          end
        end
        break if different
      end

      different.should be_true
    end
  end

  describe ".random_text" do
    it "generates random text with default length" do
      text = CrImage::Util::Captcha.random_text
      text.size.should eq 6
    end

    it "generates random text with custom length" do
      text = CrImage::Util::Captcha.random_text(8)
      text.size.should eq 8
    end

    it "generates random text with custom charset" do
      text = CrImage::Util::Captcha.random_text(10, "ABC")
      text.size.should eq 10
      text.each_char do |char|
        ['A', 'B', 'C'].should contain(char)
      end
    end

    it "generates different text on each call" do
      texts = Set(String).new
      100.times do
        texts << CrImage::Util::Captcha.random_text
      end
      # Should have many unique values (very unlikely to get duplicates)
      texts.size.should be > 90
    end
  end

  describe "Options" do
    it "has sensible defaults" do
      options = CrImage::Util::Captcha::Options.new
      options.width.should eq 300
      options.height.should eq 100
      options.noise_level.should eq 25
      options.line_count.should eq 6
      options.wobble_strength.should eq 3.0
      options.rotation_range.should eq 20.0
    end

    it "allows customization" do
      options = CrImage::Util::Captcha::Options.new(
        width: 500,
        height: 200,
        noise_level: 40,
        line_count: 8,
        wobble_strength: 4.0,
        rotation_range: 25.0
      )
      options.width.should eq 500
      options.height.should eq 200
      options.noise_level.should eq 40
      options.line_count.should eq 8
      options.wobble_strength.should eq 4.0
      options.rotation_range.should eq 25.0
    end
  end
end
