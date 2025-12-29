module CrImage::Util
  # Convolution operations for image filtering and effects.
  #
  # Provides low-level convolution operations used by filters like blur,
  # sharpen, and edge detection. Supports both standard 2D kernels and
  # separable 1D kernels for performance.
  module Convolution
    # Applies a 2D convolution kernel to an image.
    #
    # Convolves the image with the specified kernel matrix. Each output pixel
    # is computed as a weighted sum of neighboring input pixels according to
    # the kernel weights.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel` : 2D array of weights (must be square and odd-sized)
    # - `divisor` : Optional normalization divisor (default: sum of kernel)
    #
    # Returns: A new RGBA image with convolution applied
    #
    # Raises: `ArgumentError` if kernel is not square or not odd-sized
    #
    # Example:
    # ```
    # # 3x3 sharpen kernel
    # kernel = [
    #   [0.0, -1.0, 0.0],
    #   [-1.0, 5.0, -1.0],
    #   [0.0, -1.0, 0.0],
    # ]
    # sharpened = CrImage::Util::Convolution.apply_kernel(img, kernel)
    # ```
    def self.apply_kernel(src : Image, kernel : Array(Array(Float64)), divisor : Float64? = nil) : Image
      raise ArgumentError.new("Kernel must be square") unless kernel.all? { |row| row.size == kernel.size }
      raise ArgumentError.new("Kernel size must be odd") unless kernel.size.odd?

      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height
      radius = kernel.size // 2

      actual_divisor = divisor || kernel.sum { |row| row.sum }
      actual_divisor = 1.0 if actual_divisor == 0.0

      dst = RGBA.new(CrImage.rect(0, 0, width, height))

      height.times do |y|
        width.times do |x|
          r_sum = g_sum = b_sum = a_sum = 0.0

          kernel.each_with_index do |row, ky|
            row.each_with_index do |weight, kx|
              dy = ky - radius
              dx = kx - radius

              src_x = (x + dx + src_bounds.min.x).clamp(src_bounds.min.x, src_bounds.max.x - 1)
              src_y = (y + dy + src_bounds.min.y).clamp(src_bounds.min.y, src_bounds.max.y - 1)

              r, g, b, a = src.at(src_x, src_y).rgba

              r_sum += (r >> 8) * weight
              g_sum += (g >> 8) * weight
              b_sum += (b >> 8) * weight
              a_sum += (a >> 8) * weight
            end
          end

          dst.set(x, y, Color::RGBA.new(
            (r_sum / actual_divisor).clamp(0, 255).to_u8,
            (g_sum / actual_divisor).clamp(0, 255).to_u8,
            (b_sum / actual_divisor).clamp(0, 255).to_u8,
            (a_sum / actual_divisor).clamp(0, 255).to_u8
          ))
        end
      end

      dst
    end

    # Applies a separable 1D convolution kernel (horizontal then vertical).
    #
    # Separable convolution is much faster than 2D convolution for kernels
    # that can be decomposed into horizontal and vertical passes (like Gaussian blur).
    # Complexity is O(n) instead of O(n²) per pixel.
    #
    # Parameters:
    # - `src` : The source image
    # - `kernel` : 1D array of weights (must be odd-sized)
    #
    # Returns: A new RGBA image with separable convolution applied
    #
    # Raises: `ArgumentError` if kernel size is not odd
    #
    # Example:
    # ```
    # # 1D Gaussian kernel
    # kernel = [0.06, 0.24, 0.40, 0.24, 0.06]
    # blurred = CrImage::Util::Convolution.apply_separable(img, kernel)
    # ```
    def self.apply_separable(src : Image, kernel : Array(Float64)) : Image
      raise ArgumentError.new("Kernel size must be odd") unless kernel.size.odd?

      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height
      radius = kernel.size // 2

      temp = RGBA.new(CrImage.rect(0, 0, width, height))

      # Horizontal pass
      height.times do |y|
        width.times do |x|
          r_sum = g_sum = b_sum = a_sum = 0.0

          kernel.each_with_index do |weight, i|
            dx = i - radius
            src_x = (x + dx + src_bounds.min.x).clamp(src_bounds.min.x, src_bounds.max.x - 1)
            src_y = y + src_bounds.min.y

            r, g, b, a = src.at(src_x, src_y).rgba

            r_sum += (r >> 8) * weight
            g_sum += (g >> 8) * weight
            b_sum += (b >> 8) * weight
            a_sum += (a >> 8) * weight
          end

          temp.set(x, y, Color::RGBA.new(
            r_sum.round.to_u8,
            g_sum.round.to_u8,
            b_sum.round.to_u8,
            a_sum.round.to_u8
          ))
        end
      end

      dst = RGBA.new(CrImage.rect(0, 0, width, height))

      # Vertical pass
      height.times do |y|
        width.times do |x|
          r_sum = g_sum = b_sum = a_sum = 0.0

          kernel.each_with_index do |weight, i|
            dy = i - radius
            temp_x = x
            temp_y = (y + dy).clamp(0, height - 1)

            r, g, b, a = temp.at(temp_x, temp_y).rgba

            r_sum += (r >> 8) * weight
            g_sum += (g >> 8) * weight
            b_sum += (b >> 8) * weight
            a_sum += (a >> 8) * weight
          end

          dst.set(x, y, Color::RGBA.new(
            r_sum.round.to_u8,
            g_sum.round.to_u8,
            b_sum.round.to_u8,
            a_sum.round.to_u8
          ))
        end
      end

      dst
    end

    # Generates a 1D Gaussian kernel for blur operations.
    #
    # Creates a normalized Gaussian distribution kernel suitable for
    # separable convolution. The kernel is symmetric and sums to 1.0.
    #
    # Parameters:
    # - `radius` : Kernel radius (total size = radius * 2 + 1)
    # - `sigma` : Standard deviation (default: radius / 3, clamped to 0.5 minimum)
    #
    # Returns: Normalized 1D Gaussian kernel
    #
    # Raises: `ArgumentError` if radius is negative
    #
    # Example:
    # ```
    # kernel = CrImage::Util::Convolution.gaussian_kernel(3, 1.5)
    # # Returns 7-element array with Gaussian distribution
    # ```
    def self.gaussian_kernel(radius : Int32, sigma : Float64? = nil) : Array(Float64)
      raise ArgumentError.new("Radius must be non-negative") if radius < 0
      return [1.0] if radius == 0

      actual_sigma = sigma || (radius / 3.0).clamp(0.5, Float64::MAX)
      kernel_size = radius * 2 + 1
      kernel = Array(Float64).new(kernel_size, 0.0)

      sum = 0.0
      (-radius..radius).each do |i|
        exponent = -(i * i).to_f / (2.0 * actual_sigma * actual_sigma)
        value = ::Math.exp(exponent)
        kernel[i + radius] = value
        sum += value
      end

      kernel.map { |v| v / sum }
    end
  end
end
