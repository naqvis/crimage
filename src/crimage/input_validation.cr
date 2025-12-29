module CrImage
  # InputValidation provides security-focused validation for user inputs
  # to prevent DoS attacks and resource exhaustion
  module InputValidation
    # Maximum reasonable image dimension (100,000 pixels)
    # Prevents memory exhaustion attacks
    MAX_SAFE_DIMENSION = 100_000

    # Maximum reasonable image area (100 megapixels)
    # A 10000x10000 image at 4 bytes/pixel = 400MB
    MAX_SAFE_AREA = 100_000_000_i64

    # Maximum reasonable file size for reading (500MB)
    MAX_SAFE_FILE_SIZE = 500_000_000_i64

    # Validate image dimensions are reasonable
    def self.validate_image_dimensions(width : Int32, height : Int32, context : String = "image")
      if width <= 0
        raise ArgumentError.new("Width must be positive, got #{width}")
      end

      if height <= 0
        raise ArgumentError.new("Height must be positive, got #{height}")
      end

      if width > MAX_SAFE_DIMENSION
        raise DimensionError.new("#{context} width #{width} exceeds maximum safe dimension #{MAX_SAFE_DIMENSION}")
      end

      if height > MAX_SAFE_DIMENSION
        raise DimensionError.new("#{context} height #{height} exceeds maximum safe dimension #{MAX_SAFE_DIMENSION}")
      end

      area = width.to_i64 * height.to_i64
      if area > MAX_SAFE_AREA
        raise DimensionError.new("#{context} area #{area} (#{width}x#{height}) exceeds maximum safe area #{MAX_SAFE_AREA}")
      end
    end

    # Validate quality parameter for JPEG/WebP encoding
    def self.validate_quality(quality : Int32, min : Int32 = 1, max : Int32 = 100)
      unless quality >= min && quality <= max
        raise InvalidArgumentError.new("quality", "must be between #{min} and #{max}, got #{quality}")
      end
    end

    # Validate radius parameter for blur operations
    def self.validate_radius(radius : Int32, max : Int32 = 1000)
      if radius < 0
        raise ArgumentError.new("Radius must be non-negative, got #{radius}")
      end

      if radius > max
        raise ArgumentError.new("Radius #{radius} exceeds maximum safe radius #{max}")
      end
    end

    # Validate adjustment parameter for brightness/contrast
    def self.validate_adjustment(adjustment : Int32, min : Int32, max : Int32, name : String = "adjustment")
      unless adjustment >= min && adjustment <= max
        raise ArgumentError.new("Adjustment must be between #{min} and #{max}, got #{adjustment}")
      end
    end

    # Validate factor parameter for contrast/scale operations
    def self.validate_factor(factor : Float64, min : Float64, max : Float64, name : String = "factor")
      unless factor >= min && factor <= max
        raise ArgumentError.new("Factor must be between #{min} and #{max}, got #{factor}")
      end
    end

    # Validate color stop positions for gradients
    def self.validate_color_stops(stops : Array)
      if stops.empty?
        raise InvalidGradientError.new("Gradient must have at least one color stop")
      end

      stops.each_with_index do |stop, i|
        unless stop.position >= 0.0 && stop.position <= 1.0
          raise InvalidGradientError.new("Color stop #{i} position #{stop.position} must be between 0.0 and 1.0")
        end
      end

      # Verify stops are in ascending order
      stops.each_cons(2) do |pair|
        if pair[0].position > pair[1].position
          raise InvalidGradientError.new("Color stops must be in ascending order by position")
        end
      end
    end

    # Validate polygon has sufficient points
    def self.validate_polygon_points(points : Array(Point), min_points : Int32 = 3)
      if points.size < min_points
        raise InsufficientPointsError.new(min_points, points.size)
      end
    end
  end
end
