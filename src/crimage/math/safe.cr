module CrImage::Math
  # Safe provides overflow-safe arithmetic operations for image processing.
  #
  # Prevents integer overflow and memory allocation errors by validating
  # dimensions and buffer sizes before operations. Essential for handling
  # untrusted image data and preventing security vulnerabilities.
  #
  # Features:
  # - Dimension validation (max ~2.1 billion pixels per dimension)
  # - Buffer size checking (max 2GB)
  # - Overflow-safe multiplication
  # - Bounds checking for pixel access
  module Safe
    # Maximum safe image dimension to prevent integer overflow.
    MAX_DIMENSION = 0x7FFF_FFFF_i32 # ~2.1 billion pixels per dimension

    # Maximum safe pixel buffer size (2GB limit for safety).
    MAX_BUFFER_SIZE = 0x7FFF_FFFF_i64 # ~2GB

    # Safely multiplies two Int32 values with overflow checking.
    #
    # Parameters:
    # - `a` : First operand
    # - `b` : Second operand
    #
    # Returns: Result as Int64
    #
    # Raises: `MemoryError` if result exceeds Int32::MAX
    def self.mul_i32(a : Int32, b : Int32) : Int64
      result = a.to_i64 * b.to_i64
      raise MemoryError.new("Integer overflow in multiplication: #{a} * #{b}") if result > Int32::MAX
      result
    end

    # Safely calculates row stride with overflow checking.
    #
    # Parameters:
    # - `width` : Image width in pixels
    # - `bytes_per_pixel` : Bytes per pixel (1, 2, 4, or 8)
    #
    # Returns: Stride in bytes
    #
    # Raises: `DimensionError` or `MemoryError` on overflow
    def self.safe_stride(width : Int32, bytes_per_pixel : Int32) : Int32
      raise DimensionError.new("Invalid width: #{width}") if width < 0
      raise DimensionError.new("Invalid bytes per pixel: #{bytes_per_pixel}") if bytes_per_pixel < 0

      result = mul_i32(width, bytes_per_pixel)
      raise MemoryError.new("Stride calculation overflow: #{width} * #{bytes_per_pixel}") if result > Int32::MAX
      result.to_i32
    end

    # Safely calculates pixel buffer size with overflow checking.
    #
    # Validates dimensions and calculates total buffer size needed.
    #
    # Parameters:
    # - `width` : Image width in pixels
    # - `height` : Image height in pixels
    # - `bytes_per_pixel` : Bytes per pixel
    #
    # Returns: Total buffer size in bytes
    #
    # Raises: `DimensionError` or `MemoryError` if size exceeds limits
    def self.safe_buffer_size(width : Int32, height : Int32, bytes_per_pixel : Int32) : Int64
      raise DimensionError.new(width, height) if width < 0 || height < 0
      raise DimensionError.new("Invalid bytes per pixel: #{bytes_per_pixel}") if bytes_per_pixel < 0

      # Check individual dimensions
      raise DimensionError.new("Width exceeds maximum: #{width}") if width > MAX_DIMENSION
      raise DimensionError.new("Height exceeds maximum: #{height}") if height > MAX_DIMENSION

      # Calculate with overflow checking
      stride = width.to_i64 * bytes_per_pixel.to_i64
      total = stride * height.to_i64

      raise MemoryError.new(total) if total > MAX_BUFFER_SIZE
      total
    end

    # Safely calculates pixel offset with bounds checking.
    #
    # Validates coordinates are within bounds and calculates buffer offset.
    #
    # Parameters:
    # - `x, y` : Pixel coordinates
    # - `rect` : Image bounds
    # - `stride` : Row stride in bytes
    # - `bytes_per_pixel` : Bytes per pixel
    #
    # Returns: Byte offset in pixel buffer
    #
    # Raises: `BoundsError` if coordinates out of bounds, `MemoryError` on overflow
    def self.safe_pixel_offset(x : Int32, y : Int32, rect : Rectangle, stride : Int32, bytes_per_pixel : Int32) : Int32
      # Validate coordinates are within bounds
      unless x >= rect.min.x && x < rect.max.x && y >= rect.min.y && y < rect.max.y
        raise BoundsError.new(x, y, rect)
      end

      # Calculate offset with overflow checking
      dy = y - rect.min.y
      dx = x - rect.min.x

      raise MemoryError.new("Y offset overflow") if dy < 0 || dy > MAX_DIMENSION
      raise MemoryError.new("X offset overflow") if dx < 0 || dx > MAX_DIMENSION

      y_offset = dy.to_i64 * stride.to_i64
      x_offset = dx.to_i64 * bytes_per_pixel.to_i64
      total = y_offset + x_offset

      raise MemoryError.new("Pixel offset overflow") if total > Int32::MAX || total < 0
      total.to_i32
    end

    # Validates image dimensions before allocation.
    #
    # Checks that dimensions are non-negative and within safe limits.
    #
    # Parameters:
    # - `width` : Image width
    # - `height` : Image height
    #
    # Raises: `DimensionError` if dimensions are invalid or exceed limits
    def self.validate_dimensions(width : Int32, height : Int32)
      raise DimensionError.new(width, height) if width < 0 || height < 0
      raise DimensionError.new("Width exceeds maximum: #{width}") if width > MAX_DIMENSION
      raise DimensionError.new("Height exceeds maximum: #{height}") if height > MAX_DIMENSION
    end

    # Validates rectangle dimensions.
    #
    # Parameters:
    # - `rect` : Rectangle to validate
    #
    # Raises: `DimensionError` if rectangle dimensions are invalid
    def self.validate_rectangle(rect : Rectangle)
      validate_dimensions(rect.width, rect.height)
    end
  end
end

module CrImage
  SafeMath = Math::Safe
end
