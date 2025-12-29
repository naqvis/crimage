require "../spec_helper"

describe CrImage::Font::Face do
  describe "convenience methods" do
    # Create a test face using FreeType
    font_path = "spec/testdata/fonts/DejaVuSans.ttf"

    it "measure returns text width in pixels" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      width = face.measure("Hello")
      width.should be > 0
      width.should be < 200 # Sanity check

      # Longer text should be wider
      width2 = face.measure("Hello, World!")
      width2.should be > width
    end

    it "text_bounds returns bounding rectangle" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      bounds = face.text_bounds("Hello")
      bounds.width.should be > 0
      bounds.height.should be > 0

      # Min.y should be negative (above baseline)
      bounds.min.y.should be < 0
    end

    it "text_size returns width and height tuple" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      width, height = face.text_size("Test")
      width.should be > 0
      height.should be > 0
    end

    it "line_height returns positive value" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      line_height = face.line_height
      line_height.should be > 0
      line_height.should be >= 24 # Should be at least font size
    end

    it "ascent returns positive value" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      ascent = face.ascent
      ascent.should be > 0
    end

    it "descent returns positive value" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      descent = face.descent
      descent.should be >= 0
    end

    it "ascent + descent approximately equals line_height" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      sum = face.ascent + face.descent
      line_height = face.line_height

      # Should be close (within a few pixels due to rounding)
      (sum - line_height).abs.should be < 5
    end

    it "measure returns 0 for empty string" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, 24.0)

      width = face.measure("")
      width.should eq(0)
    end

    it "scales with font size" do
      next unless File.exists?(font_path)

      font = FreeType::TrueType.load(font_path)
      face_small = FreeType::TrueType.new_face(font, 12.0)
      face_large = FreeType::TrueType.new_face(font, 24.0)

      width_small = face_small.measure("Test")
      width_large = face_large.measure("Test")

      # Larger font should produce wider text
      width_large.should be > width_small

      # Should be approximately 2x (with some tolerance)
      ratio = width_large.to_f / width_small.to_f
      ratio.should be > 1.5
      ratio.should be < 2.5
    end
  end
end
