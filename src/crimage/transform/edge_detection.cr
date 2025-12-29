require "../util/convolution"
require "../util/pixel_iterator"

module CrImage::Transform
  # Edge detection operators for finding boundaries in images.
  #
  # Available operators:
  # - `Sobel` : Most common, good balance of accuracy and noise resistance
  # - `Prewitt` : Similar to Sobel with equal weighting
  # - `Roberts` : Fast 2x2 operator, more sensitive to noise
  # - `Scharr` : Improved Sobel with better rotational symmetry
  enum EdgeOperator
    Sobel
    Prewitt
    Roberts
    Scharr
  end

  # Applies edge detection to an image using the specified operator.
  #
  # Edge detection highlights areas of rapid intensity change, useful for
  # finding object boundaries, features, and structural information.
  #
  # Parameters:
  # - `src` : The source image
  # - `operator` : Edge detection operator to use (default: Sobel)
  # - `threshold` : Optional threshold for binary edge map (0-255, nil for gradient magnitude)
  #
  # Returns: A new grayscale `Image` showing detected edges
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # edges = CrImage::Transform.detect_edges(img)
  # binary_edges = CrImage::Transform.detect_edges(img, threshold: 50)
  # ```
  def self.detect_edges(src : Image, operator : EdgeOperator = EdgeOperator::Sobel, threshold : Int32? = nil) : Image
    if threshold
      InputValidation.validate_adjustment(threshold, 0, 255, "threshold")
    end

    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    # Convert to grayscale first for edge detection
    gray_data = Array(UInt8).new(width * height, 0_u8)
    Util::PixelIterator.each_pixel(src) do |x, y, r, g, b, a|
      gray_value = ((r * 299 + g * 587 + b * 114) // 1000) >> 8
      gray_data[y * width + x] = gray_value.to_u8
    end

    # Get kernels for the operator
    kernel_x, kernel_y = get_edge_kernels(operator)

    dst = Gray.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        gx = apply_kernel_at(gray_data, width, height, x, y, kernel_x)
        gy = apply_kernel_at(gray_data, width, height, x, y, kernel_y)

        # Calculate gradient magnitude
        magnitude = ::Math.sqrt(gx * gx + gy * gy)

        # Apply threshold if specified
        value = if threshold
                  magnitude > threshold ? 255_u8 : 0_u8
                else
                  magnitude.clamp(0, 255).to_u8
                end

        dst.set(x, y, Color::Gray.new(value))
      end
    end

    dst
  end

  # Applies Sobel edge detection (convenience method).
  #
  # Sobel operator uses 3x3 kernels with smoothing, good for general edge detection.
  #
  # Example:
  # ```
  # edges = CrImage::Transform.sobel(img)
  # ```
  def self.sobel(src : Image, threshold : Int32? = nil) : Image
    detect_edges(src, EdgeOperator::Sobel, threshold)
  end

  # Applies Prewitt edge detection (convenience method).
  #
  # Prewitt operator is similar to Sobel but with equal weighting.
  #
  # Example:
  # ```
  # edges = CrImage::Transform.prewitt(img)
  # ```
  def self.prewitt(src : Image, threshold : Int32? = nil) : Image
    detect_edges(src, EdgeOperator::Prewitt, threshold)
  end

  # Applies Roberts cross edge detection (convenience method).
  #
  # Roberts cross uses 2x2 kernels, faster but more sensitive to noise.
  #
  # Example:
  # ```
  # edges = CrImage::Transform.roberts(img)
  # ```
  def self.roberts(src : Image, threshold : Int32? = nil) : Image
    detect_edges(src, EdgeOperator::Roberts, threshold)
  end

  # Returns the horizontal and vertical kernels for the specified operator
  private def self.get_edge_kernels(operator : EdgeOperator) : Tuple(Array(Array(Float64)), Array(Array(Float64)))
    case operator
    when .sobel?
      kernel_x = [
        [-1.0, 0.0, 1.0],
        [-2.0, 0.0, 2.0],
        [-1.0, 0.0, 1.0],
      ]
      kernel_y = [
        [-1.0, -2.0, -1.0],
        [0.0, 0.0, 0.0],
        [1.0, 2.0, 1.0],
      ]
      {kernel_x, kernel_y}
    when .prewitt?
      kernel_x = [
        [-1.0, 0.0, 1.0],
        [-1.0, 0.0, 1.0],
        [-1.0, 0.0, 1.0],
      ]
      kernel_y = [
        [-1.0, -1.0, -1.0],
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
      ]
      {kernel_x, kernel_y}
    when .roberts?
      kernel_x = [
        [1.0, 0.0],
        [0.0, -1.0],
      ]
      kernel_y = [
        [0.0, 1.0],
        [-1.0, 0.0],
      ]
      {kernel_x, kernel_y}
    when .scharr?
      kernel_x = [
        [-3.0, 0.0, 3.0],
        [-10.0, 0.0, 10.0],
        [-3.0, 0.0, 3.0],
      ]
      kernel_y = [
        [-3.0, -10.0, -3.0],
        [0.0, 0.0, 0.0],
        [3.0, 10.0, 3.0],
      ]
      {kernel_x, kernel_y}
    else
      raise ArgumentError.new("Unknown edge operator")
    end
  end

  # Applies a kernel at a specific position in the grayscale data
  private def self.apply_kernel_at(data : Array(UInt8), width : Int32, height : Int32,
                                   x : Int32, y : Int32, kernel : Array(Array(Float64))) : Float64
    sum = 0.0
    radius = kernel.size // 2

    kernel.each_with_index do |row, ky|
      row.each_with_index do |weight, kx|
        dy = ky - radius
        dx = kx - radius

        src_x = (x + dx).clamp(0, width - 1)
        src_y = (y + dy).clamp(0, height - 1)

        pixel_value = data[src_y * width + src_x]
        sum += pixel_value * weight
      end
    end

    sum
  end
end
