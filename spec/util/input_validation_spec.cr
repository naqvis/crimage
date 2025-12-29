require "../spec_helper"

describe CrImage::InputValidation do
  describe ".validate_image_dimensions" do
    it "accepts valid dimensions" do
      CrImage::InputValidation.validate_image_dimensions(100, 100)
      CrImage::InputValidation.validate_image_dimensions(1920, 1080)
      CrImage::InputValidation.validate_image_dimensions(10000, 10000)
    end

    it "rejects zero dimensions" do
      expect_raises(ArgumentError, /must be positive/) do
        CrImage::InputValidation.validate_image_dimensions(0, 100)
      end
    end

    it "rejects negative dimensions" do
      expect_raises(ArgumentError, /must be positive/) do
        CrImage::InputValidation.validate_image_dimensions(100, -50)
      end
    end

    it "rejects dimensions exceeding maximum" do
      expect_raises(CrImage::DimensionError, /exceeds maximum safe dimension/) do
        CrImage::InputValidation.validate_image_dimensions(200_000, 100)
      end
    end

    it "rejects area exceeding maximum" do
      expect_raises(CrImage::DimensionError, /exceeds maximum safe area/) do
        CrImage::InputValidation.validate_image_dimensions(50_000, 50_000)
      end
    end

    it "includes context in error message" do
      expect_raises(ArgumentError, /positive/) do
        CrImage::InputValidation.validate_image_dimensions(0, 100, "thumbnail")
      end
    end
  end

  describe ".validate_quality" do
    it "accepts valid quality values" do
      CrImage::InputValidation.validate_quality(1)
      CrImage::InputValidation.validate_quality(50)
      CrImage::InputValidation.validate_quality(100)
    end

    it "rejects quality below minimum" do
      expect_raises(CrImage::InvalidArgumentError, /must be between 1 and 100/) do
        CrImage::InputValidation.validate_quality(0)
      end
    end

    it "rejects quality above maximum" do
      expect_raises(CrImage::InvalidArgumentError, /must be between 1 and 100/) do
        CrImage::InputValidation.validate_quality(101)
      end
    end

    it "accepts custom ranges" do
      CrImage::InputValidation.validate_quality(50, min: 0, max: 255)
    end
  end

  describe ".validate_radius" do
    it "accepts valid radius values" do
      CrImage::InputValidation.validate_radius(0)
      CrImage::InputValidation.validate_radius(10)
      CrImage::InputValidation.validate_radius(100)
    end

    it "rejects negative radius" do
      expect_raises(ArgumentError, /must be non-negative/) do
        CrImage::InputValidation.validate_radius(-5)
      end
    end

    it "rejects radius exceeding maximum" do
      expect_raises(ArgumentError, /exceeds maximum safe radius/) do
        CrImage::InputValidation.validate_radius(2000)
      end
    end

    it "accepts custom maximum" do
      CrImage::InputValidation.validate_radius(500, max: 1000)
    end
  end

  describe ".validate_adjustment" do
    it "accepts valid adjustment values" do
      CrImage::InputValidation.validate_adjustment(0, -255, 255)
      CrImage::InputValidation.validate_adjustment(100, -255, 255)
      CrImage::InputValidation.validate_adjustment(-100, -255, 255)
    end

    it "rejects adjustment below minimum" do
      expect_raises(ArgumentError) do
        CrImage::InputValidation.validate_adjustment(-300, -255, 255)
      end
    end

    it "rejects adjustment above maximum" do
      expect_raises(ArgumentError) do
        CrImage::InputValidation.validate_adjustment(300, -255, 255)
      end
    end
  end

  describe ".validate_factor" do
    it "accepts valid factor values" do
      CrImage::InputValidation.validate_factor(0.5, 0.0, 2.0)
      CrImage::InputValidation.validate_factor(1.0, 0.0, 2.0)
      CrImage::InputValidation.validate_factor(1.5, 0.0, 2.0)
    end

    it "rejects factor below minimum" do
      expect_raises(ArgumentError) do
        CrImage::InputValidation.validate_factor(-0.5, 0.0, 2.0)
      end
    end

    it "rejects factor above maximum" do
      expect_raises(ArgumentError) do
        CrImage::InputValidation.validate_factor(3.0, 0.0, 2.0)
      end
    end
  end

  describe ".validate_color_stops" do
    it "accepts valid color stops" do
      stops = [
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      CrImage::InputValidation.validate_color_stops(stops)
    end

    it "rejects empty stops array" do
      expect_raises(CrImage::InvalidGradientError, /at least one color stop/) do
        CrImage::InputValidation.validate_color_stops([] of CrImage::Draw::ColorStop)
      end
    end

    it "rejects stops with invalid positions" do
      stops = [
        CrImage::Draw::ColorStop.new(-0.5, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::BLUE),
      ]
      expect_raises(CrImage::InvalidGradientError, /must be between 0.0 and 1.0/) do
        CrImage::InputValidation.validate_color_stops(stops)
      end
    end

    it "rejects stops not in ascending order" do
      stops = [
        CrImage::Draw::ColorStop.new(1.0, CrImage::Color::RED),
        CrImage::Draw::ColorStop.new(0.0, CrImage::Color::BLUE),
      ]
      expect_raises(CrImage::InvalidGradientError, /ascending order/) do
        CrImage::InputValidation.validate_color_stops(stops)
      end
    end
  end

  describe ".validate_polygon_points" do
    it "accepts valid polygon" do
      points = [
        CrImage.point(0, 0),
        CrImage.point(10, 0),
        CrImage.point(5, 10),
      ]
      CrImage::InputValidation.validate_polygon_points(points)
    end

    it "rejects polygon with too few points" do
      points = [
        CrImage.point(0, 0),
        CrImage.point(10, 0),
      ]
      expect_raises(CrImage::InsufficientPointsError) do
        CrImage::InputValidation.validate_polygon_points(points)
      end
    end

    it "accepts custom minimum points" do
      points = [
        CrImage.point(0, 0),
        CrImage.point(10, 0),
      ]
      CrImage::InputValidation.validate_polygon_points(points, min_points: 2)
    end
  end
end
