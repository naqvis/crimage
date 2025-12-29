module CrImage::Transform
  # Interpolation method for arbitrary angle rotation.
  #
  # Options:
  # - `Nearest` : Fast, lower quality (pixel-perfect for pixel art)
  # - `Bilinear` : Slower, higher quality (smooth edges)
  enum RotationInterpolation
    Nearest  # Fast, lower quality
    Bilinear # Slower, higher quality
  end

  # Rotates an image by an arbitrary angle (in degrees) clockwise.
  #
  # The output image is sized to contain the entire rotated image without cropping.
  # Empty areas are filled with the specified background color (default: transparent).
  # For 90°, 180°, 270° rotations, uses optimized fast paths.
  #
  # Parameters:
  # - `src` : The source image to rotate
  # - `angle_degrees` : Rotation angle in degrees (positive = clockwise)
  # - `interpolation` : Interpolation method (Nearest or Bilinear)
  # - `background` : Color for empty areas (default: transparent)
  #
  # Returns: A new `Image` containing the rotated result
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  #
  # # Rotate 45 degrees with bilinear interpolation
  # rotated = CrImage::Transform.rotate(img, 45.0)
  #
  # # Rotate with nearest neighbor (faster)
  # rotated = CrImage::Transform.rotate(img, 30.0,
  #   interpolation: CrImage::Transform::RotationInterpolation::Nearest)
  #
  # # Rotate with white background
  # rotated = CrImage::Transform.rotate(img, 15.0,
  #   background: CrImage::Color::WHITE)
  # ```
  def self.rotate(
    src : Image,
    angle_degrees : Float64,
    interpolation : RotationInterpolation = RotationInterpolation::Bilinear,
    background : Color::Color = Color::TRANSPARENT,
  ) : Image
    # Handle special cases for 90° increments (use fast path)
    normalized_angle = angle_degrees % 360.0
    normalized_angle += 360.0 if normalized_angle < 0

    case normalized_angle
    when 0.0
      # No rotation needed, return copy
      return copy_image(src)
    when 90.0
      return rotate_90(src)
    when 180.0
      return rotate_180(src)
    when 270.0
      return rotate_270(src)
    end

    # Convert angle to radians
    angle_rad = angle_degrees * ::Math::PI / 180.0

    # Calculate sine and cosine once
    cos_angle = ::Math.cos(angle_rad)
    sin_angle = ::Math.sin(angle_rad)

    src_bounds = src.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    # Calculate bounding box of rotated image
    corners = [
      {0.0, 0.0},
      {src_width.to_f64, 0.0},
      {0.0, src_height.to_f64},
      {src_width.to_f64, src_height.to_f64},
    ]

    rotated_corners = corners.map do |x, y|
      {
        x * cos_angle - y * sin_angle,
        x * sin_angle + y * cos_angle,
      }
    end

    min_x = rotated_corners.map(&.[0]).min
    max_x = rotated_corners.map(&.[0]).max
    min_y = rotated_corners.map(&.[1]).min
    max_y = rotated_corners.map(&.[1]).max

    dst_width = (max_x - min_x).ceil.to_i
    dst_height = (max_y - min_y).ceil.to_i

    # Create destination image
    dst = RGBA.new(CrImage.rect(0, 0, dst_width, dst_height))

    # Fill with background color
    bg_rgba = Color.rgba_model.convert(background).as(Color::RGBA)
    dst.fill(bg_rgba)

    # Calculate center offsets
    center_x = src_width / 2.0
    center_y = src_height / 2.0
    dst_center_x = dst_width / 2.0
    dst_center_y = dst_height / 2.0

    # Inverse rotation matrix (to map destination to source)
    inv_cos = cos_angle
    inv_sin = -sin_angle

    # Perform rotation using inverse mapping
    case interpolation
    when .nearest?
      rotate_nearest(dst, src, dst_width, dst_height, src_bounds,
        center_x, center_y, dst_center_x, dst_center_y,
        inv_cos, inv_sin)
    when .bilinear?
      rotate_bilinear(dst, src, dst_width, dst_height, src_bounds,
        center_x, center_y, dst_center_x, dst_center_y,
        inv_cos, inv_sin)
    end

    dst
  end

  # Rotates an image 90 degrees clockwise.
  #
  # The output dimensions are swapped (width becomes height, height becomes width).
  # This is a lossless operation that preserves all pixel data.
  #
  # Parameters:
  # - `src` : The source image to rotate
  #
  # Returns: A new `Image` rotated 90 degrees clockwise
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("landscape.png")
  # portrait = CrImage::Transform.rotate_90(img)
  # ```
  def self.rotate_90(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, height, width))

    height.times do |y|
      width.times do |x|
        dst.set(height - 1 - y, x, src.at(x + src_bounds.min.x, y + src_bounds.min.y))
      end
    end

    dst
  end

  # Rotates an image 180 degrees.
  #
  # The output dimensions remain the same as the input.
  # This is a lossless operation that preserves all pixel data.
  #
  # Parameters:
  # - `src` : The source image to rotate
  #
  # Returns: A new `Image` rotated 180 degrees
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # flipped = CrImage::Transform.rotate_180(img)
  # ```
  def self.rotate_180(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        dst.set(width - 1 - x, height - 1 - y, src.at(x + src_bounds.min.x, y + src_bounds.min.y))
      end
    end

    dst
  end

  # Rotates an image 270 degrees clockwise (90 degrees counter-clockwise).
  #
  # The output dimensions are swapped (width becomes height, height becomes width).
  # This is a lossless operation that preserves all pixel data.
  #
  # Parameters:
  # - `src` : The source image to rotate
  #
  # Returns: A new `Image` rotated 270 degrees clockwise
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("portrait.png")
  # landscape = CrImage::Transform.rotate_270(img)
  # ```
  def self.rotate_270(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, height, width))

    height.times do |y|
      width.times do |x|
        dst.set(y, width - 1 - x, src.at(x + src_bounds.min.x, y + src_bounds.min.y))
      end
    end

    dst
  end

  # Flips an image horizontally (mirror effect).
  #
  # Creates a mirror image by reversing pixels along the horizontal axis.
  # The output dimensions remain the same as the input.
  #
  # Parameters:
  # - `src` : The source image to flip
  #
  # Returns: A new `Image` flipped horizontally
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("face.png")
  # mirrored = CrImage::Transform.flip_horizontal(img)
  # ```
  def self.flip_horizontal(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        dst.set(width - 1 - x, y, src.at(x + src_bounds.min.x, y + src_bounds.min.y))
      end
    end

    dst
  end

  # Flips an image vertically (upside down).
  #
  # Reverses pixels along the vertical axis, turning the image upside down.
  # The output dimensions remain the same as the input.
  #
  # Parameters:
  # - `src` : The source image to flip
  #
  # Returns: A new `Image` flipped vertically
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # upside_down = CrImage::Transform.flip_vertical(img)
  # ```
  def self.flip_vertical(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        dst.set(x, height - 1 - y, src.at(x + src_bounds.min.x, y + src_bounds.min.y))
      end
    end

    dst
  end

  # Crops an image to the specified rectangle.
  #
  # Extracts a rectangular region from the source image. The crop rectangle
  # is automatically clipped to the source image bounds.
  #
  # Parameters:
  # - `src` : The source image to crop
  # - `rect` : The rectangle defining the crop region
  #
  # Returns: A new `Image` containing only the cropped region
  #
  # Raises: `ArgumentError` if the crop rectangle is completely outside image bounds
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # crop_rect = CrImage.rect(100, 100, 300, 300)
  # cropped = CrImage::Transform.crop(img, crop_rect)
  # ```
  def self.crop(src : Image, rect : Rectangle) : Image
    src_bounds = src.bounds

    # Ensure crop rectangle is within source bounds
    crop_rect = BoundsCheck.clip_rect(rect, src_bounds)
    raise ArgumentError.new("Crop rectangle #{rect} is outside image bounds #{src_bounds}") if crop_rect.empty

    width = crop_rect.width
    height = crop_rect.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        dst.set(x, y, src.at(x + crop_rect.min.x, y + crop_rect.min.y))
      end
    end

    dst
  end

  # Helper methods for arbitrary rotation

  # Nearest neighbor rotation (fast)
  private def self.rotate_nearest(
    dst : RGBA, src : Image,
    dst_width : Int32, dst_height : Int32, src_bounds : Rectangle,
    center_x : Float64, center_y : Float64,
    dst_center_x : Float64, dst_center_y : Float64,
    inv_cos : Float64, inv_sin : Float64,
  )
    dst_height.times do |dst_y|
      dst_width.times do |dst_x|
        dx = dst_x - dst_center_x
        dy = dst_y - dst_center_y

        src_x = (dx * inv_cos - dy * inv_sin + center_x).round.to_i
        src_y = (dx * inv_sin + dy * inv_cos + center_y).round.to_i

        if src_x >= 0 && src_x < src_bounds.width && src_y >= 0 && src_y < src_bounds.height
          color = src.at(src_x + src_bounds.min.x, src_y + src_bounds.min.y)
          dst.set(dst_x, dst_y, color)
        end
      end
    end
  end

  # Bilinear interpolation rotation (higher quality)
  private def self.rotate_bilinear(
    dst : RGBA, src : Image,
    dst_width : Int32, dst_height : Int32, src_bounds : Rectangle,
    center_x : Float64, center_y : Float64,
    dst_center_x : Float64, dst_center_y : Float64,
    inv_cos : Float64, inv_sin : Float64,
  )
    dst_height.times do |dst_y|
      dst_width.times do |dst_x|
        dx = dst_x - dst_center_x
        dy = dst_y - dst_center_y

        src_x_f = dx * inv_cos - dy * inv_sin + center_x
        src_y_f = dx * inv_sin + dy * inv_cos + center_y

        src_x = src_x_f.floor.to_i
        src_y = src_y_f.floor.to_i
        frac_x = src_x_f - src_x
        frac_y = src_y_f - src_y

        if src_x >= 0 && src_x < src_bounds.width - 1 &&
           src_y >= 0 && src_y < src_bounds.height - 1
          c00 = src.at(src_x + src_bounds.min.x, src_y + src_bounds.min.y)
          c10 = src.at(src_x + 1 + src_bounds.min.x, src_y + src_bounds.min.y)
          c01 = src.at(src_x + src_bounds.min.x, src_y + 1 + src_bounds.min.y)
          c11 = src.at(src_x + 1 + src_bounds.min.x, src_y + 1 + src_bounds.min.y)

          r00, g00, b00, a00 = c00.rgba
          r10, g10, b10, a10 = c10.rgba
          r01, g01, b01, a01 = c01.rgba
          r11, g11, b11, a11 = c11.rgba

          r0 = r00 * (1 - frac_x) + r10 * frac_x
          g0 = g00 * (1 - frac_x) + g10 * frac_x
          b0 = b00 * (1 - frac_x) + b10 * frac_x
          a0 = a00 * (1 - frac_x) + a10 * frac_x

          r1 = r01 * (1 - frac_x) + r11 * frac_x
          g1 = g01 * (1 - frac_x) + g11 * frac_x
          b1 = b01 * (1 - frac_x) + b11 * frac_x
          a1 = a01 * (1 - frac_x) + a11 * frac_x

          r = (r0 * (1 - frac_y) + r1 * frac_y).to_u32
          g = (g0 * (1 - frac_y) + g1 * frac_y).to_u32
          b = (b0 * (1 - frac_y) + b1 * frac_y).to_u32
          a = (a0 * (1 - frac_y) + a1 * frac_y).to_u32

          dst.set(dst_x, dst_y, Color::RGBA.new(
            (r >> 8).to_u8,
            (g >> 8).to_u8,
            (b >> 8).to_u8,
            (a >> 8).to_u8
          ))
        elsif src_x >= 0 && src_x < src_bounds.width &&
              src_y >= 0 && src_y < src_bounds.height
          color = src.at(src_x + src_bounds.min.x, src_y + src_bounds.min.y)
          dst.set(dst_x, dst_y, color)
        end
      end
    end
  end

  # Helper to copy an image
  private def self.copy_image(src : Image) : Image
    bounds = src.bounds
    dst = RGBA.new(CrImage.rect(0, 0, bounds.width, bounds.height))

    bounds.height.times do |y|
      bounds.width.times do |x|
        dst.set(x, y, src.at(x + bounds.min.x, y + bounds.min.y))
      end
    end

    dst
  end

  # Applies EXIF orientation transform to correct image rotation.
  #
  # Digital cameras store orientation information in EXIF metadata to indicate
  # how the image should be displayed. This method applies the necessary
  # rotation and/or flip to display the image correctly.
  #
  # Parameters:
  # - `src` : The source image to orient
  # - `orientation` : EXIF orientation value (1-8)
  #
  # Returns: A new `Image` with correct orientation, or copy if no transform needed
  #
  # Orientation values:
  # - 1: Normal (no transform)
  # - 2: Flip horizontal
  # - 3: Rotate 180°
  # - 4: Flip vertical
  # - 5: Transpose (flip horizontal + rotate 270°)
  # - 6: Rotate 90° clockwise
  # - 7: Transverse (flip horizontal + rotate 90°)
  # - 8: Rotate 270° clockwise (90° counter-clockwise)
  #
  # Example:
  # ```
  # img = CrImage::JPEG.read("photo.jpg")
  # exif = CrImage::EXIF.read("photo.jpg")
  # if exif
  #   oriented = CrImage::Transform.auto_orient(img, exif.orientation)
  # end
  # ```
  def self.auto_orient(src : Image, orientation : EXIF::Orientation) : Image
    case orientation
    when .normal?
      copy_image(src)
    when .flip_horizontal?
      flip_horizontal(src)
    when .rotate180?
      rotate_180(src)
    when .flip_vertical?
      flip_vertical(src)
    when .transpose?
      # Flip horizontal then rotate 270° (or equivalently: rotate 90° then flip vertical)
      flip_horizontal(rotate_270(src))
    when .rotate90_cw?
      rotate_90(src)
    when .transverse?
      # Flip horizontal then rotate 90° (or equivalently: rotate 270° then flip vertical)
      flip_horizontal(rotate_90(src))
    when .rotate270_cw?
      rotate_270(src)
    else
      copy_image(src)
    end
  end

  # Applies EXIF orientation transform using integer value.
  #
  # Convenience overload that accepts raw orientation value (1-8).
  def self.auto_orient(src : Image, orientation : Int32) : Image
    exif_orientation = EXIF::Orientation.from_value?(orientation) || EXIF::Orientation::Normal
    auto_orient(src, exif_orientation)
  end
end
