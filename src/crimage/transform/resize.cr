module CrImage::Transform
  # Resizes an image using nearest neighbor interpolation.
  #
  # This is the fastest resizing algorithm but produces lower quality results,
  # especially when upscaling. Best used for pixel art or when speed is critical.
  #
  # Parameters:
  # - `src` : The source image to resize
  # - `new_width` : Target width in pixels (must be positive)
  # - `new_height` : Target height in pixels (must be positive)
  #
  # Returns: A new `Image` with the specified dimensions
  #
  # Raises: `ArgumentError` if width or height is not positive
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("input.png")
  # thumbnail = CrImage::Transform.resize_nearest(img, 100, 100)
  # # Or use the chainable API:
  # thumbnail = img.resize(100, 100, method: :nearest)
  # ```
  def self.resize_nearest(src : Image, new_width : Int32, new_height : Int32) : Image
    InputValidation.validate_image_dimensions(new_width, new_height, "resize target")

    dst = RGBA.new(CrImage.rect(0, 0, new_width, new_height))
    src_bounds = src.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    x_ratio = src_width.to_f / new_width
    y_ratio = src_height.to_f / new_height

    new_height.times do |y|
      new_width.times do |x|
        src_x = (x * x_ratio).to_i + src_bounds.min.x
        src_y = (y * y_ratio).to_i + src_bounds.min.y
        dst.set(x, y, src.at(src_x, src_y))
      end
    end

    dst
  end

  # Resizes an image using bilinear interpolation.
  #
  # Provides better quality than nearest neighbor by interpolating between
  # the four nearest pixels. Good balance between speed and quality for most uses.
  #
  # Parameters:
  # - `src` : The source image to resize
  # - `new_width` : Target width in pixels (must be positive)
  # - `new_height` : Target height in pixels (must be positive)
  #
  # Returns: A new `Image` with the specified dimensions
  #
  # Raises: `ArgumentError` if width or height is not positive
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # resized = CrImage::Transform.resize_bilinear(img, 800, 600)
  # # Or use the chainable API:
  # resized = img.resize(800, 600, method: :bilinear)
  # ```
  def self.resize_bilinear(src : Image, new_width : Int32, new_height : Int32) : Image
    InputValidation.validate_image_dimensions(new_width, new_height, "resize target")

    dst = RGBA.new(CrImage.rect(0, 0, new_width, new_height))
    src_bounds = src.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    x_ratio = (src_width - 1).to_f / new_width
    y_ratio = (src_height - 1).to_f / new_height

    new_height.times do |y|
      new_width.times do |x|
        src_x = x * x_ratio
        src_y = y * y_ratio

        x_floor = src_x.floor.to_i + src_bounds.min.x
        y_floor = src_y.floor.to_i + src_bounds.min.y
        x_ceil = BoundsCheck.clamp(x_floor + 1, src_bounds.min.x, src_bounds.max.x - 1)
        y_ceil = BoundsCheck.clamp(y_floor + 1, src_bounds.min.y, src_bounds.max.y - 1)

        x_frac = src_x - src_x.floor
        y_frac = src_y - src_y.floor

        c00 = src.at(x_floor, y_floor)
        c10 = src.at(x_ceil, y_floor)
        c01 = src.at(x_floor, y_ceil)
        c11 = src.at(x_ceil, y_ceil)

        r00, g00, b00, a00 = c00.rgba
        r10, g10, b10, a10 = c10.rgba
        r01, g01, b01, a01 = c01.rgba
        r11, g11, b11, a11 = c11.rgba

        r0 = r00 * (1 - x_frac) + r10 * x_frac
        g0 = g00 * (1 - x_frac) + g10 * x_frac
        b0 = b00 * (1 - x_frac) + b10 * x_frac
        a0 = a00 * (1 - x_frac) + a10 * x_frac

        r1 = r01 * (1 - x_frac) + r11 * x_frac
        g1 = g01 * (1 - x_frac) + g11 * x_frac
        b1 = b01 * (1 - x_frac) + b11 * x_frac
        a1 = a01 * (1 - x_frac) + a11 * x_frac

        r = (r0 * (1 - y_frac) + r1 * y_frac).to_u32
        g = (g0 * (1 - y_frac) + g1 * y_frac).to_u32
        b = (b0 * (1 - y_frac) + b1 * y_frac).to_u32
        a = (a0 * (1 - y_frac) + a1 * y_frac).to_u32

        dst.set(x, y, Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8))
      end
    end

    dst
  end

  # Cubic interpolation kernel (Catmull-Rom / bicubic)
  private def self.cubic_kernel(x : Float64) : Float64
    x = x.abs
    if x <= 1.0
      return (1.5 * x - 2.5) * x * x + 1.0
    elsif x < 2.0
      return ((-0.5 * x + 2.5) * x - 4.0) * x + 2.0
    else
      return 0.0
    end
  end

  # Lanczos sinc function with 3-lobe window
  private def self.lanczos3(x : Float64) : Float64
    return 1.0 if x.abs < 1e-10
    a = 3.0
    return 0.0 if x.abs >= a
    pi_x = ::Math::PI * x
    pi_x_a = pi_x / a
    (::Math.sin(pi_x) / pi_x) * (::Math.sin(pi_x_a) / pi_x_a)
  end

  # Resizes an image using bicubic (Catmull-Rom) interpolation.
  #
  # Uses a 4x4 pixel neighborhood for interpolation, producing high quality results
  # with good sharpness. Faster than Lanczos while maintaining excellent quality.
  # Uses separable convolution for efficiency.
  #
  # Parameters:
  # - `src` : The source image to resize
  # - `new_width` : Target width in pixels (must be positive)
  # - `new_height` : Target height in pixels (must be positive)
  #
  # Returns: A new `Image` with the specified dimensions
  #
  # Raises: `ArgumentError` if width or height is not positive
  #
  # Example:
  # ```
  # img = CrImage::JPEG.read("photo.jpg")
  # high_quality = CrImage::Transform.resize_bicubic(img, 1920, 1080)
  # # Or use the chainable API:
  # high_quality = img.resize(1920, 1080, method: :bicubic)
  # ```
  def self.resize_bicubic(src : Image, new_width : Int32, new_height : Int32) : Image
    InputValidation.validate_image_dimensions(new_width, new_height, "resize target")

    src_bounds = src.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    temp = RGBA.new(CrImage.rect(0, 0, new_width, src_height))
    x_ratio = src_width.to_f / new_width
    x_support = x_ratio > 1.0 ? 2.0 * x_ratio : 2.0

    src_height.times do |y|
      new_width.times do |x|
        src_x = (x + 0.5) * x_ratio - 0.5
        left = (src_x - x_support).ceil.to_i
        right = (src_x + x_support).floor.to_i

        r_sum = g_sum = b_sum = a_sum = weight_sum = 0.0

        (left..right).each do |sx|
          next if sx < 0 || sx >= src_width
          dist = (sx - src_x) / (x_ratio > 1.0 ? x_ratio : 1.0)
          weight = cubic_kernel(dist)
          next if weight.abs < 1e-10

          r, g, b, a = src.at(sx + src_bounds.min.x, y + src_bounds.min.y).rgba
          r_sum += (r >> 8) * weight
          g_sum += (g >> 8) * weight
          b_sum += (b >> 8) * weight
          a_sum += (a >> 8) * weight
          weight_sum += weight
        end

        if weight_sum > 0
          temp.set(x, y, Color::RGBA.new(
            (r_sum / weight_sum).clamp(0, 255).round.to_u8,
            (g_sum / weight_sum).clamp(0, 255).round.to_u8,
            (b_sum / weight_sum).clamp(0, 255).round.to_u8,
            (a_sum / weight_sum).clamp(0, 255).round.to_u8
          ))
        else
          temp.set(x, y, Color::RGBA.new(0_u8, 0_u8, 0_u8, 0_u8))
        end
      end
    end

    dst = RGBA.new(CrImage.rect(0, 0, new_width, new_height))
    y_ratio = src_height.to_f / new_height
    y_support = y_ratio > 1.0 ? 2.0 * y_ratio : 2.0

    new_height.times do |y|
      new_width.times do |x|
        src_y = (y + 0.5) * y_ratio - 0.5
        top = (src_y - y_support).ceil.to_i
        bottom = (src_y + y_support).floor.to_i

        r_sum = g_sum = b_sum = a_sum = weight_sum = 0.0

        (top..bottom).each do |sy|
          next if sy < 0 || sy >= src_height
          dist = (sy - src_y) / (y_ratio > 1.0 ? y_ratio : 1.0)
          weight = cubic_kernel(dist)
          next if weight.abs < 1e-10

          r, g, b, a = temp.at(x, sy).rgba
          r_sum += (r >> 8) * weight
          g_sum += (g >> 8) * weight
          b_sum += (b >> 8) * weight
          a_sum += (a >> 8) * weight
          weight_sum += weight
        end

        if weight_sum > 0
          dst.set(x, y, Color::RGBA.new(
            (r_sum / weight_sum).clamp(0, 255).round.to_u8,
            (g_sum / weight_sum).clamp(0, 255).round.to_u8,
            (b_sum / weight_sum).clamp(0, 255).round.to_u8,
            (a_sum / weight_sum).clamp(0, 255).round.to_u8
          ))
        else
          dst.set(x, y, Color::RGBA.new(0_u8, 0_u8, 0_u8, 0_u8))
        end
      end
    end

    dst
  end

  # Resizes an image using Lanczos-3 interpolation.
  #
  # Provides the highest quality resizing with excellent detail preservation
  # and minimal aliasing artifacts. Uses a 3-lobe windowed sinc filter.
  # Best for professional photo editing and when quality is paramount.
  # Slower than other methods due to larger kernel size.
  #
  # Parameters:
  # - `src` : The source image to resize
  # - `new_width` : Target width in pixels (must be positive)
  # - `new_height` : Target height in pixels (must be positive)
  #
  # Returns: A new `Image` with the specified dimensions
  #
  # Raises: `ArgumentError` if width or height is not positive
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("artwork.png")
  # print_quality = CrImage::Transform.resize_lanczos(img, 3000, 2000)
  # # Or use the chainable API:
  # print_quality = img.resize(3000, 2000, method: :lanczos)
  # ```
  def self.resize_lanczos(src : Image, new_width : Int32, new_height : Int32) : Image
    InputValidation.validate_image_dimensions(new_width, new_height, "resize target")

    src_bounds = src.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    temp = RGBA.new(CrImage.rect(0, 0, new_width, src_height))
    x_ratio = src_width.to_f / new_width
    x_support = x_ratio > 1.0 ? 3.0 * x_ratio : 3.0

    src_height.times do |y|
      new_width.times do |x|
        src_x = (x + 0.5) * x_ratio - 0.5
        left = (src_x - x_support).ceil.to_i
        right = (src_x + x_support).floor.to_i

        r_sum = g_sum = b_sum = a_sum = weight_sum = 0.0

        (left..right).each do |sx|
          next if sx < 0 || sx >= src_width
          dist = (sx - src_x) / (x_ratio > 1.0 ? x_ratio : 1.0)
          weight = lanczos3(dist)
          next if weight.abs < 1e-10

          r, g, b, a = src.at(sx + src_bounds.min.x, y + src_bounds.min.y).rgba
          r_sum += (r >> 8) * weight
          g_sum += (g >> 8) * weight
          b_sum += (b >> 8) * weight
          a_sum += (a >> 8) * weight
          weight_sum += weight
        end

        if weight_sum > 0
          temp.set(x, y, Color::RGBA.new(
            (r_sum / weight_sum).clamp(0, 255).round.to_u8,
            (g_sum / weight_sum).clamp(0, 255).round.to_u8,
            (b_sum / weight_sum).clamp(0, 255).round.to_u8,
            (a_sum / weight_sum).clamp(0, 255).round.to_u8
          ))
        else
          temp.set(x, y, Color::RGBA.new(0_u8, 0_u8, 0_u8, 0_u8))
        end
      end
    end

    dst = RGBA.new(CrImage.rect(0, 0, new_width, new_height))
    y_ratio = src_height.to_f / new_height
    y_support = y_ratio > 1.0 ? 3.0 * y_ratio : 3.0

    new_height.times do |y|
      new_width.times do |x|
        src_y = (y + 0.5) * y_ratio - 0.5
        top = (src_y - y_support).ceil.to_i
        bottom = (src_y + y_support).floor.to_i

        r_sum = g_sum = b_sum = a_sum = weight_sum = 0.0

        (top..bottom).each do |sy|
          next if sy < 0 || sy >= src_height
          dist = (sy - src_y) / (y_ratio > 1.0 ? y_ratio : 1.0)
          weight = lanczos3(dist)
          next if weight.abs < 1e-10

          r, g, b, a = temp.at(x, sy).rgba
          r_sum += (r >> 8) * weight
          g_sum += (g >> 8) * weight
          b_sum += (b >> 8) * weight
          a_sum += (a >> 8) * weight
          weight_sum += weight
        end

        if weight_sum > 0
          dst.set(x, y, Color::RGBA.new(
            BoundsCheck.clamp_u8((r_sum / weight_sum).round),
            BoundsCheck.clamp_u8((g_sum / weight_sum).round),
            BoundsCheck.clamp_u8((b_sum / weight_sum).round),
            BoundsCheck.clamp_u8((a_sum / weight_sum).round)
          ))
        else
          dst.set(x, y, Color::RGBA.new(0_u8, 0_u8, 0_u8, 0_u8))
        end
      end
    end

    dst
  end
end
