module CrImage
  # Base exception for all CrImage errors
  class Error < Exception
  end

  # Raised when image format is invalid or corrupted
  class FormatError < Error
    def initialize(format : String? = nil)
      if format
        super("Invalid or corrupted #{format} image format")
      else
        super("Invalid or corrupted image format")
      end
    end

    def initialize(message : String, @cause : Exception? = nil)
      super(message)
    end
  end

  # Raised when image format is not supported
  class UnsupportedError < Error
    def initialize(feature : String)
      super("Unsupported feature: #{feature}")
    end
  end

  # Raised when image dimensions are invalid
  class DimensionError < Error
    def initialize(width : Int32, height : Int32)
      super("Invalid image dimensions: #{width}x#{height}")
    end

    def initialize(message : String)
      super(message)
    end
  end

  # Raised when memory allocation would exceed safe limits
  class MemoryError < Error
    def initialize(requested : Int64)
      super("Memory allocation would exceed safe limits: #{requested} bytes requested")
    end

    def initialize(message : String)
      super(message)
    end
  end

  # Raised when I/O operation fails
  class IOError < Error
    def initialize(message : String, @cause : Exception? = nil)
      super(message)
    end
  end

  # Raised when coordinates are out of bounds
  class BoundsError < Error
    def initialize(x : Int32, y : Int32, bounds : Rectangle)
      super("Coordinates (#{x}, #{y}) are outside image bounds #{bounds}")
    end

    def initialize(message : String)
      super(message)
    end
  end

  # Raised when an invalid argument is provided
  class InvalidArgumentError < Error
    def initialize(param : String, value : String)
      super("Invalid argument for #{param}: #{value}")
    end

    def initialize(message : String)
      super(message)
    end
  end

  # Raised when gradient configuration is invalid
  class InvalidGradientError < Error
  end

  # Raised when polygon has insufficient points
  class InsufficientPointsError < Error
    def initialize(required : Int32, provided : Int32)
      super("Polygon requires at least #{required} points, got #{provided}")
    end
  end
end
