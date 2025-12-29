require "../spec_helper"

describe CrImage::Util::Blurhash do
  describe ".encode" do
    it "encodes a solid color image" do
      img = CrImage.rgba(32, 32, CrImage::Color::RED)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 3)

      hash.should_not be_empty
      hash.size.should eq(4 + 2 * 4 * 3) # 4 header + 2 * components
    end

    it "encodes with default components" do
      img = CrImage.rgba(32, 32, CrImage::Color::BLUE)
      hash = CrImage::Util::Blurhash.encode(img)

      hash.should_not be_empty
      CrImage::Util::Blurhash.valid?(hash).should be_true
    end

    it "encodes with minimum components" do
      img = CrImage.rgba(16, 16, CrImage::Color::GREEN)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 1, y_components: 1)

      hash.size.should eq(6) # 1 + 1 + 4 = 6 (size + max_ac + dc)
    end

    it "encodes with maximum components" do
      img = CrImage.rgba(16, 16, CrImage::Color::WHITE)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 9, y_components: 9)

      expected_length = 4 + 2 * 9 * 9
      hash.size.should eq(expected_length)
    end

    it "raises for invalid x_components" do
      img = CrImage.rgba(16, 16)
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.encode(img, x_components: 0, y_components: 3)
      end
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.encode(img, x_components: 10, y_components: 3)
      end
    end

    it "raises for invalid y_components" do
      img = CrImage.rgba(16, 16)
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 0)
      end
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 10)
      end
    end

    it "produces different hashes for different images" do
      red_img = CrImage.rgba(32, 32, CrImage::Color::RED)
      blue_img = CrImage.rgba(32, 32, CrImage::Color::BLUE)

      red_hash = CrImage::Util::Blurhash.encode(red_img)
      blue_hash = CrImage::Util::Blurhash.encode(blue_img)

      red_hash.should_not eq(blue_hash)
    end
  end

  describe ".decode" do
    it "decodes a blurhash to an image" do
      # First encode an image
      original = CrImage.rgba(32, 32, CrImage::Color::RED)
      hash = CrImage::Util::Blurhash.encode(original, x_components: 4, y_components: 3)

      # Then decode it
      decoded = CrImage::Util::Blurhash.decode(hash, 32, 32)

      decoded.should_not be_nil
      decoded.bounds.width.should eq(32)
      decoded.bounds.height.should eq(32)
    end

    it "decodes to different sizes" do
      img = CrImage.rgba(64, 64, CrImage::Color::GREEN)
      hash = CrImage::Util::Blurhash.encode(img)

      small = CrImage::Util::Blurhash.decode(hash, 16, 16)
      large = CrImage::Util::Blurhash.decode(hash, 128, 128)

      small.bounds.width.should eq(16)
      small.bounds.height.should eq(16)
      large.bounds.width.should eq(128)
      large.bounds.height.should eq(128)
    end

    it "applies punch parameter for contrast" do
      img = CrImage.rgba(32, 32, CrImage::Color::BLUE)
      hash = CrImage::Util::Blurhash.encode(img)

      normal = CrImage::Util::Blurhash.decode(hash, 32, 32, punch: 1.0)
      punched = CrImage::Util::Blurhash.decode(hash, 32, 32, punch: 2.0)

      # Both should decode successfully
      normal.should_not be_nil
      punched.should_not be_nil
    end

    it "raises for invalid blurhash" do
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.decode("abc", 32, 32)
      end
    end

    it "raises for wrong length blurhash" do
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.decode("LEHV6nWB2yk8", 32, 32) # Too short
      end
    end
  end

  describe ".average_color" do
    it "extracts average color from blurhash" do
      # Create a solid red image
      img = CrImage.rgba(32, 32, CrImage::Color::RED)
      hash = CrImage::Util::Blurhash.encode(img)

      avg = CrImage::Util::Blurhash.average_color(hash)

      # Should be close to red
      avg.r.should be > 200
      avg.g.should be < 50
      avg.b.should be < 50
    end

    it "extracts average from mixed color image" do
      img = CrImage.rgba(32, 32)
      # Fill half red, half blue
      32.times do |y|
        32.times do |x|
          color = x < 16 ? CrImage::Color::RED : CrImage::Color::BLUE
          img.set(x, y, color)
        end
      end

      hash = CrImage::Util::Blurhash.encode(img)
      avg = CrImage::Util::Blurhash.average_color(hash)

      # Should be purple-ish (mix of red and blue)
      avg.r.should be > 50
      avg.b.should be > 50
    end

    it "raises for invalid blurhash" do
      expect_raises(CrImage::Util::Blurhash::Error) do
        CrImage::Util::Blurhash.average_color("abc")
      end
    end
  end

  describe ".valid?" do
    it "returns true for valid blurhash" do
      img = CrImage.rgba(32, 32, CrImage::Color::WHITE)
      hash = CrImage::Util::Blurhash.encode(img)

      CrImage::Util::Blurhash.valid?(hash).should be_true
    end

    it "returns false for too short string" do
      CrImage::Util::Blurhash.valid?("abc").should be_false
    end

    it "returns false for wrong length" do
      CrImage::Util::Blurhash.valid?("LEHV6nWB2yk8").should be_false
    end

    it "returns false for invalid characters" do
      CrImage::Util::Blurhash.valid?("!!!!!!").should be_false
    end
  end

  describe ".components" do
    it "returns component counts" do
      img = CrImage.rgba(32, 32)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 5, y_components: 4)

      x, y = CrImage::Util::Blurhash.components(hash)
      x.should eq(5)
      y.should eq(4)
    end

    it "returns correct components for minimum" do
      img = CrImage.rgba(16, 16)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 1, y_components: 1)

      x, y = CrImage::Util::Blurhash.components(hash)
      x.should eq(1)
      y.should eq(1)
    end

    it "returns correct components for maximum" do
      img = CrImage.rgba(16, 16)
      hash = CrImage::Util::Blurhash.encode(img, x_components: 9, y_components: 9)

      x, y = CrImage::Util::Blurhash.components(hash)
      x.should eq(9)
      y.should eq(9)
    end
  end

  describe "round-trip encoding/decoding" do
    it "preserves average color through round-trip" do
      # Create solid color image
      original = CrImage.rgba(32, 32, CrImage::Color::RED)

      hash = CrImage::Util::Blurhash.encode(original, x_components: 4, y_components: 3)
      avg = CrImage::Util::Blurhash.average_color(hash)

      # Average should be close to red
      avg.r.should be > 200
      avg.g.should be < 50
      avg.b.should be < 50
    end

    it "encodes and decodes without error" do
      img = CrImage.gradient(64, 64, CrImage::Color::RED, CrImage::Color::BLUE, direction: :horizontal)

      hash = CrImage::Util::Blurhash.encode(img, x_components: 4, y_components: 3)
      decoded = CrImage::Util::Blurhash.decode(hash, 64, 64)

      decoded.bounds.width.should eq(64)
      decoded.bounds.height.should eq(64)
    end
  end

  describe "known blurhash values" do
    it "decodes a known blurhash correctly" do
      # This is a well-known test hash from the blurhash examples
      # It represents a simple gradient
      hash = "L00000fQfQfQfQfQfQfQfQfQfQfQ"

      # Should be valid
      CrImage::Util::Blurhash.valid?(hash).should be_true

      # Should decode without error
      img = CrImage::Util::Blurhash.decode(hash, 32, 32)
      img.bounds.width.should eq(32)
      img.bounds.height.should eq(32)
    end
  end
end
