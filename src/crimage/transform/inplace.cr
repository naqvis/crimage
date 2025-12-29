module CrImage::Transform
  # In-place transformations - modify image directly without creating copies
  # These only work on RGBA images and are much more memory efficient

  # Adjusts brightness in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. The original image data is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  # - `adjustment` : Brightness adjustment value (-255 to 255)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.brightness!(img, 50)
  # CrImage::PNG.write("brighter.png", img)
  # ```
  def self.brightness!(img : Image, adjustment : Int32) : Nil
    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    height = bounds.height
    width = bounds.width

    height.times do |y|
      width.times do |x|
        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        pix = rgba.pix

        pix[i] = BoundsCheck.clamp_u8(pix[i].to_i32 + adjustment)
        pix[i + 1] = BoundsCheck.clamp_u8(pix[i + 1].to_i32 + adjustment)
        pix[i + 2] = BoundsCheck.clamp_u8(pix[i + 2].to_i32 + adjustment)
      end
    end
  end

  # Adjusts contrast in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. The original image data is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  # - `factor` : Contrast factor (0.0 to 2.0, where 1.0 is no change)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.contrast!(img, 1.5)
  # ```
  def self.contrast!(img : Image, factor : Float64) : Nil
    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    height = bounds.height
    width = bounds.width

    height.times do |y|
      width.times do |x|
        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        pix = rgba.pix

        pix[i] = BoundsCheck.clamp_u8((pix[i].to_i32 - 128) * factor + 128)
        pix[i + 1] = BoundsCheck.clamp_u8((pix[i + 1].to_i32 - 128) * factor + 128)
        pix[i + 2] = BoundsCheck.clamp_u8((pix[i + 2].to_i32 - 128) * factor + 128)
      end
    end
  end

  # Inverts colors in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. The original image data is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.invert!(img)
  # ```
  def self.invert!(img : Image) : Nil
    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    height = bounds.height
    width = bounds.width

    height.times do |y|
      width.times do |x|
        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        pix = rgba.pix

        pix[i] = (255 - pix[i]).to_u8
        pix[i + 1] = (255 - pix[i + 1]).to_u8
        pix[i + 2] = (255 - pix[i + 2]).to_u8
      end
    end
  end

  # Applies box blur in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. Uses a temporary buffer internally but
  # still more efficient than creating a full copy. The original image data
  # is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  # - `radius` : Blur radius in pixels (must be positive)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if radius is not positive or image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.blur!(img, 5)
  # ```
  def self.blur!(img : Image, radius : Int32) : Nil
    raise ArgumentError.new("Radius must be positive") if radius <= 0

    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    width = bounds.width
    height = bounds.height

    temp = Bytes.new(width * height * 4)
    kernel_size = radius * 2 + 1
    divisor = kernel_size * kernel_size

    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = a_sum = 0_u32

        (-radius..radius).each do |dy|
          (-radius..radius).each do |dx|
            src_x, src_y = BoundsCheck.clamp_point(x + dx + bounds.min.x, y + dy + bounds.min.y, bounds)
            i = rgba.pixel_offset(src_x, src_y)

            r_sum += rgba.pix[i]
            g_sum += rgba.pix[i + 1]
            b_sum += rgba.pix[i + 2]
            a_sum += rgba.pix[i + 3]
          end
        end

        ti = (y * width + x) * 4
        temp[ti] = (r_sum // divisor).to_u8
        temp[ti + 1] = (g_sum // divisor).to_u8
        temp[ti + 2] = (b_sum // divisor).to_u8
        temp[ti + 3] = (a_sum // divisor).to_u8
      end
    end

    # Copy back
    height.times do |y|
      width.times do |x|
        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        ti = (y * width + x) * 4
        rgba.pix[i] = temp[ti]
        rgba.pix[i + 1] = temp[ti + 1]
        rgba.pix[i + 2] = temp[ti + 2]
        rgba.pix[i + 3] = temp[ti + 3]
      end
    end
  end

  # Applies Gaussian blur in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. Uses a temporary buffer internally but
  # still more efficient than creating a full copy. The original image data
  # is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  # - `radius` : Blur radius in pixels (must be non-negative)
  # - `sigma` : Standard deviation of Gaussian kernel (optional, defaults to radius/3)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if radius is negative or image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.blur_gaussian!(img, 10)
  # ```
  def self.blur_gaussian!(img : Image, radius : Int32, sigma : Float64? = nil) : Nil
    raise ArgumentError.new("Radius must be non-negative") if radius < 0

    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    return if radius == 0

    bounds = rgba.bounds
    width = bounds.width
    height = bounds.height

    kernel = Util::Convolution.gaussian_kernel(radius, sigma)
    temp = Bytes.new(width * height * 4)

    # Horizontal pass
    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = a_sum = 0.0

        (-radius..radius).each do |dx|
          src_x = BoundsCheck.clamp(x + dx + bounds.min.x, bounds.min.x, bounds.max.x - 1)
          i = rgba.pixel_offset(src_x, y + bounds.min.y)
          weight = kernel[dx + radius]

          r_sum += rgba.pix[i] * weight
          g_sum += rgba.pix[i + 1] * weight
          b_sum += rgba.pix[i + 2] * weight
          a_sum += rgba.pix[i + 3] * weight
        end

        ti = (y * width + x) * 4
        temp[ti] = r_sum.round.to_u8
        temp[ti + 1] = g_sum.round.to_u8
        temp[ti + 2] = b_sum.round.to_u8
        temp[ti + 3] = a_sum.round.to_u8
      end
    end

    # Vertical pass
    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = a_sum = 0.0

        (-radius..radius).each do |dy|
          temp_y = BoundsCheck.clamp(y + dy, 0, height - 1)
          ti = (temp_y * width + x) * 4
          weight = kernel[dy + radius]

          r_sum += temp[ti] * weight
          g_sum += temp[ti + 1] * weight
          b_sum += temp[ti + 2] * weight
          a_sum += temp[ti + 3] * weight
        end

        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        rgba.pix[i] = r_sum.round.to_u8
        rgba.pix[i + 1] = g_sum.round.to_u8
        rgba.pix[i + 2] = b_sum.round.to_u8
        rgba.pix[i + 3] = a_sum.round.to_u8
      end
    end
  end

  # Applies sharpening filter in-place without creating a new image.
  #
  # Modifies the image directly, which is much faster and more memory-efficient
  # than the non-mutating version. Uses a temporary buffer internally but
  # still more efficient than creating a full copy. The original image data
  # is permanently modified.
  #
  # Parameters:
  # - `img` : The RGBA image to modify (must be RGBA type)
  # - `amount` : Sharpening strength (default: 1.0, typical range: 0.5-2.0)
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.sharpen!(img, 1.5)
  # ```
  def self.sharpen!(img : Image, amount : Float64 = 1.0) : Nil
    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    width = bounds.width
    height = bounds.height

    center = 1.0 + 4.0 * amount
    neighbor = -amount

    temp = Bytes.new(width * height * 4)

    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = a_sum = 0.0

        [-1, 0, 1].each do |dy|
          [-1, 0, 1].each do |dx|
            src_x, src_y = BoundsCheck.clamp_point(x + dx + bounds.min.x, y + dy + bounds.min.y, bounds)
            i = rgba.pixel_offset(src_x, src_y)

            weight = (dx == 0 && dy == 0) ? center : neighbor
            r_sum += rgba.pix[i] * weight
            g_sum += rgba.pix[i + 1] * weight
            b_sum += rgba.pix[i + 2] * weight
            a_sum += rgba.pix[i + 3] * weight
          end
        end

        ti = (y * width + x) * 4
        temp[ti] = BoundsCheck.clamp_u8(r_sum)
        temp[ti + 1] = BoundsCheck.clamp_u8(g_sum)
        temp[ti + 2] = BoundsCheck.clamp_u8(b_sum)
        temp[ti + 3] = BoundsCheck.clamp_u8(a_sum)
      end
    end

    # Copy back
    height.times do |y|
      width.times do |x|
        i = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)
        ti = (y * width + x) * 4
        rgba.pix[i] = temp[ti]
        rgba.pix[i + 1] = temp[ti + 1]
        rgba.pix[i + 2] = temp[ti + 2]
        rgba.pix[i + 3] = temp[ti + 3]
      end
    end
  end

  # Converts image to grayscale in-place (modifies the image directly).
  # Only works on RGBA images for performance.
  # Uses ITU-R BT.709 luminance formula: Y = 0.2126*R + 0.7152*G + 0.0722*B
  #
  # Parameters:
  # - `img` : The RGBA image to modify
  #
  # Returns: `Nil` (modifies image in-place)
  #
  # Raises: `ArgumentError` if image is not RGBA type
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png").as(CrImage::RGBA)
  # CrImage::Transform.grayscale!(img)
  # ```
  def self.grayscale!(img : Image) : Nil
    rgba = img.as?(RGBA)
    raise ArgumentError.new("In-place operations only work on RGBA images") unless rgba

    bounds = rgba.bounds
    width = bounds.width
    height = bounds.height

    height.times do |y|
      width.times do |x|
        offset = rgba.pixel_offset(x + bounds.min.x, y + bounds.min.y)

        r = rgba.pix[offset].to_u32
        g = rgba.pix[offset + 1].to_u32
        b = rgba.pix[offset + 2].to_u32

        # Use standard luminance formula (ITU-R BT.709)
        # Y = 0.2126*R + 0.7152*G + 0.0722*B
        # Approximated as: (54*R + 183*G + 19*B) / 256
        gray = ((r * 54 + g * 183 + b * 19) // 256).to_u8

        rgba.pix[offset] = gray
        rgba.pix[offset + 1] = gray
        rgba.pix[offset + 2] = gray
        # Alpha channel unchanged
      end
    end
  end
end
