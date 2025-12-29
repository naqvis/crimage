module CrImage::Util
  # Structuring element shapes for morphological operations.
  #
  # The structuring element defines which neighboring pixels are considered
  # during morphological operations:
  # - `Rectangle` : All pixels in a square region (most common)
  # - `Cross` : Only pixels in horizontal and vertical lines
  # - `Ellipse` : Circular/elliptical region for smoother results
  enum StructuringElement
    Rectangle
    Cross
    Ellipse
  end

  # Morphological operations for image processing.
  # Includes erosion, dilation, opening, closing, and morphological gradient.
  module Morphology
    # Applies erosion to an image.
    #
    # Erosion shrinks bright regions and enlarges dark regions.
    # Useful for removing small bright spots and separating objects.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel_size` : Size of structuring element (must be odd)
    # - `shape` : Shape of structuring element (default: Rectangle)
    #
    # Returns: A new eroded `Image`
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("noisy.png")
    # eroded = CrImage::Util::Morphology.erode(img, 3)
    # ```
    def self.erode(src : Image, kernel_size : Int32 = 3,
                   shape : StructuringElement = StructuringElement::Rectangle) : Image
      validate_kernel_size(kernel_size)

      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      # Convert to grayscale for morphological operations
      gray_data = to_grayscale_data(src)

      dst = Gray.new(CrImage.rect(0, 0, width, height))
      kernel = create_kernel(kernel_size, shape)
      radius = kernel_size // 2

      height.times do |y|
        width.times do |x|
          min_value = 255_u8

          kernel.each_with_index do |row, ky|
            row.each_with_index do |active, kx|
              next unless active

              dy = ky - radius
              dx = kx - radius
              src_x = (x + dx).clamp(0, width - 1)
              src_y = (y + dy).clamp(0, height - 1)

              pixel_value = gray_data[src_y * width + src_x]
              min_value = pixel_value if pixel_value < min_value
            end
          end

          dst.set(x, y, Color::Gray.new(min_value))
        end
      end

      dst
    end

    # Applies dilation to an image.
    #
    # Dilation expands bright regions and shrinks dark regions.
    # Useful for filling small holes and connecting nearby objects.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel_size` : Size of structuring element (must be odd)
    # - `shape` : Shape of structuring element (default: Rectangle)
    #
    # Returns: A new dilated `Image`
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("binary.png")
    # dilated = CrImage::Util::Morphology.dilate(img, 3)
    # ```
    def self.dilate(src : Image, kernel_size : Int32 = 3,
                    shape : StructuringElement = StructuringElement::Rectangle) : Image
      validate_kernel_size(kernel_size)

      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      gray_data = to_grayscale_data(src)

      dst = Gray.new(CrImage.rect(0, 0, width, height))
      kernel = create_kernel(kernel_size, shape)
      radius = kernel_size // 2

      height.times do |y|
        width.times do |x|
          max_value = 0_u8

          kernel.each_with_index do |row, ky|
            row.each_with_index do |active, kx|
              next unless active

              dy = ky - radius
              dx = kx - radius
              src_x = (x + dx).clamp(0, width - 1)
              src_y = (y + dy).clamp(0, height - 1)

              pixel_value = gray_data[src_y * width + src_x]
              max_value = pixel_value if pixel_value > max_value
            end
          end

          dst.set(x, y, Color::Gray.new(max_value))
        end
      end

      dst
    end

    # Applies morphological opening (erosion followed by dilation).
    #
    # Opening removes small bright spots while preserving larger structures.
    # Useful for noise removal and smoothing object boundaries.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel_size` : Size of structuring element (must be odd)
    # - `shape` : Shape of structuring element (default: Rectangle)
    #
    # Returns: A new opened `Image`
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("noisy.png")
    # opened = CrImage::Util::Morphology.open(img, 5)
    # ```
    def self.open(src : Image, kernel_size : Int32 = 3,
                  shape : StructuringElement = StructuringElement::Rectangle) : Image
      eroded = erode(src, kernel_size, shape)
      dilate(eroded, kernel_size, shape)
    end

    # Applies morphological closing (dilation followed by erosion).
    #
    # Closing fills small holes and gaps while preserving larger structures.
    # Useful for connecting nearby objects and filling gaps.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel_size` : Size of structuring element (must be odd)
    # - `shape` : Shape of structuring element (default: Rectangle)
    #
    # Returns: A new closed `Image`
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("gaps.png")
    # closed = CrImage::Util::Morphology.close(img, 5)
    # ```
    def self.close(src : Image, kernel_size : Int32 = 3,
                   shape : StructuringElement = StructuringElement::Rectangle) : Image
      dilated = dilate(src, kernel_size, shape)
      erode(dilated, kernel_size, shape)
    end

    # Applies morphological gradient (dilation - erosion).
    #
    # Gradient highlights edges and boundaries of objects.
    # Useful for edge detection and boundary extraction.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel_size` : Size of structuring element (must be odd)
    # - `shape` : Shape of structuring element (default: Rectangle)
    #
    # Returns: A new gradient `Image`
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("objects.png")
    # gradient = CrImage::Util::Morphology.gradient(img, 3)
    # ```
    def self.gradient(src : Image, kernel_size : Int32 = 3,
                      shape : StructuringElement = StructuringElement::Rectangle) : Image
      dilated = dilate(src, kernel_size, shape)
      eroded = erode(src, kernel_size, shape)

      # Compute difference
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      dst = Gray.new(CrImage.rect(0, 0, width, height))

      height.times do |y|
        width.times do |x|
          d = dilated.at(x, y).as(Color::Gray).y.to_i32
          e = eroded.at(x, y).as(Color::Gray).y.to_i32
          diff = (d - e).clamp(0, 255).to_u8
          dst.set(x, y, Color::Gray.new(diff))
        end
      end

      dst
    end

    # Validates that kernel size is positive and odd.
    #
    # Morphological kernels must be odd-sized to have a center pixel.
    private def self.validate_kernel_size(size : Int32)
      raise ArgumentError.new("Kernel size must be positive and odd, got #{size}") unless size > 0 && size.odd?
    end

    # Converts image to grayscale data array for morphological processing.
    #
    # Uses standard luminance formula (ITU-R BT.601) to convert RGB to grayscale.
    private def self.to_grayscale_data(img : Image) : Array(UInt8)
      bounds = img.bounds
      width = bounds.width
      height = bounds.height

      Array(UInt8).new(width * height) do |i|
        x = i % width
        y = i // width
        r, g, b, _ = img.at(x + bounds.min.x, y + bounds.min.y).rgba
        (((r * 299 + g * 587 + b * 114) // 1000) >> 8).to_u8
      end
    end

    # Creates a structuring element kernel with the specified shape.
    #
    # Returns a 2D boolean array where true indicates active pixels that
    # participate in the morphological operation.
    private def self.create_kernel(size : Int32, shape : StructuringElement) : Array(Array(Bool))
      kernel = Array.new(size) { Array.new(size, false) }
      center = size // 2
      radius = center

      case shape
      when .rectangle?
        # All elements are active
        size.times do |y|
          size.times do |x|
            kernel[y][x] = true
          end
        end
      when .cross?
        # Only center row and column
        size.times do |i|
          kernel[center][i] = true
          kernel[i][center] = true
        end
      when .ellipse?
        # Circular/elliptical shape
        size.times do |y|
          size.times do |x|
            dy = y - center
            dx = x - center
            distance = ::Math.sqrt(dx * dx + dy * dy)
            kernel[y][x] = distance <= radius
          end
        end
      end

      kernel
    end
  end
end
