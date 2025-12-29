require "../util/pixel_iterator"

module CrImage::Transform
  # Applies a sepia tone effect to an image.
  #
  # Sepia creates a warm, brownish tone reminiscent of old photographs.
  # Uses standard sepia transformation matrix.
  #
  # Parameters:
  # - `src` : The source image
  #
  # Returns: A new `Image` with sepia tone applied
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # vintage = CrImage::Transform.sepia(img)
  # ```
  def self.sepia(src : Image) : Image
    Util::PixelIterator.map_pixels_8bit(src) do |r, g, b, a|
      # Standard sepia transformation matrix
      tr = (r * 0.393 + g * 0.769 + b * 0.189).clamp(0, 255).to_u8
      tg = (r * 0.349 + g * 0.686 + b * 0.168).clamp(0, 255).to_u8
      tb = (r * 0.272 + g * 0.534 + b * 0.131).clamp(0, 255).to_u8

      Color::RGBA.new(tr, tg, tb, a)
    end
  end

  # Applies an emboss effect to an image.
  #
  # Emboss creates a 3D raised appearance by emphasizing edges and
  # converting the image to grayscale with directional lighting.
  #
  # Parameters:
  # - `src` : The source image
  # - `angle` : Light direction angle in degrees (default: 45.0)
  # - `depth` : Effect strength (default: 1.0, range: 0.5-2.0)
  #
  # Returns: A new `Image` with emboss effect
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # embossed = CrImage::Transform.emboss(img)
  # strong_emboss = CrImage::Transform.emboss(img, depth: 2.0)
  # ```
  def self.emboss(src : Image, angle : Float64 = 45.0, depth : Float64 = 1.0) : Image
    InputValidation.validate_factor(depth, 0.5, 2.0, "emboss depth")

    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    # Create emboss kernel based on angle
    rad = angle * ::Math::PI / 180.0
    dx = ::Math.cos(rad) * depth
    dy = ::Math.sin(rad) * depth

    kernel = [
      [-depth, -dy, 0.0],
      [-dx, 1.0, dx],
      [0.0, dy, depth],
    ]

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = 0.0

        kernel.each_with_index do |row, ky|
          row.each_with_index do |weight, kx|
            src_x = (x + kx - 1 + src_bounds.min.x).clamp(src_bounds.min.x, src_bounds.max.x - 1)
            src_y = (y + ky - 1 + src_bounds.min.y).clamp(src_bounds.min.y, src_bounds.max.y - 1)

            r, g, b, a = src.at(src_x, src_y).rgba

            r_sum += (r >> 8) * weight
            g_sum += (g >> 8) * weight
            b_sum += (b >> 8) * weight
          end
        end

        # Add 128 to center the values (emboss effect)
        gray = ((r_sum + g_sum + b_sum) / 3.0 + 128.0).clamp(0, 255).to_u8

        dst.set(x, y, Color::RGBA.new(gray, gray, gray, 255_u8))
      end
    end

    dst
  end

  # Applies a vignette effect to an image.
  #
  # Vignette darkens the edges of the image, drawing focus to the center.
  # Common in photography for artistic effect.
  #
  # Parameters:
  # - `src` : The source image
  # - `strength` : Vignette intensity (default: 0.5, range: 0.0-1.0)
  # - `radius` : Vignette radius as fraction of image size (default: 0.7, range: 0.1-1.0)
  #
  # Returns: A new `Image` with vignette effect
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # vignetted = CrImage::Transform.vignette(img)
  # strong_vignette = CrImage::Transform.vignette(img, strength: 0.8)
  # ```
  def self.vignette(src : Image, strength : Float64 = 0.5, radius : Float64 = 0.7) : Image
    InputValidation.validate_factor(strength, 0.0, 1.0, "vignette strength")
    InputValidation.validate_factor(radius, 0.1, 1.0, "vignette radius")

    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    center_x = width / 2.0
    center_y = height / 2.0
    max_dist = ::Math.sqrt(center_x * center_x + center_y * center_y) * radius

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    height.times do |y|
      width.times do |x|
        # Calculate distance from center
        dx = x - center_x
        dy = y - center_y
        dist = ::Math.sqrt(dx * dx + dy * dy)

        # Calculate vignette factor (1.0 at center, 0.0 at edges)
        factor = if dist < max_dist
                   1.0
                 else
                   1.0 - ((dist - max_dist) / (::Math.sqrt(center_x * center_x + center_y * center_y) - max_dist)).clamp(0.0, 1.0)
                 end

        # Apply strength
        factor = 1.0 - (1.0 - factor) * strength

        r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba

        dst.set(x, y, Color::RGBA.new(
          ((r >> 8) * factor).to_u8,
          ((g >> 8) * factor).to_u8,
          ((b >> 8) * factor).to_u8,
          (a >> 8).to_u8
        ))
      end
    end

    dst
  end

  # Adjusts color temperature of an image.
  #
  # Shifts colors toward warm (orange/red) or cool (blue) tones.
  # Useful for correcting white balance or creating mood.
  #
  # Parameters:
  # - `src` : The source image
  # - `temperature` : Temperature adjustment (-100 to 100, negative=cooler, positive=warmer)
  #
  # Returns: A new `Image` with adjusted color temperature
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # warmer = CrImage::Transform.temperature(img, 30)
  # cooler = CrImage::Transform.temperature(img, -30)
  # ```
  def self.temperature(src : Image, temperature : Int32) : Image
    InputValidation.validate_adjustment(temperature, -100, 100, "temperature")

    # Convert temperature to RGB adjustments
    r_adjust = temperature > 0 ? temperature : 0
    b_adjust = temperature < 0 ? -temperature : 0

    Util::PixelIterator.map_pixels_8bit(src) do |r, g, b, a|
      Color::RGBA.new(
        BoundsCheck.clamp_u8(r.to_i32 + r_adjust),
        g,
        BoundsCheck.clamp_u8(b.to_i32 + b_adjust),
        a
      )
    end
  end
end
