require "../util/pixel_iterator"

module CrImage::Transform
  # Optimized contrast adjustment on RGBA pixels using fixed-point math
  # Formula: (value - 128) * factor + 128
  # Uses integer approximation: factor is scaled by 256
  private def self.optimized_contrast_rgba(pixels : UInt8*, count : Int64, factor : Float64)
    return if count <= 0

    # Convert factor to fixed-point (scale by 256)
    factor_fixed = (factor * 256.0).to_i32.clamp(0, 512)

    # Process each pixel with scalar code (SIMD is complex for this operation)
    count.times do |i|
      offset = i * 4
      r = pixels[offset + 0].to_i32
      g = pixels[offset + 1].to_i32
      b = pixels[offset + 2].to_i32

      # (value - 128) * factor + 128
      pixels[offset + 0] = (((r - 128) * factor_fixed) // 256 + 128).clamp(0, 255).to_u8
      pixels[offset + 1] = (((g - 128) * factor_fixed) // 256 + 128).clamp(0, 255).to_u8
      pixels[offset + 2] = (((b - 128) * factor_fixed) // 256 + 128).clamp(0, 255).to_u8
      # Alpha unchanged: pixels[offset + 3]
    end
  end

  # SIMD helper for brightness adjustment on RGBA pixels
  # Processes 4 pixels (16 bytes) at a time using saturating arithmetic
  private def self.simd_brightness_rgba(pixels : UInt8*, count : Int64, adjustment : Int32)
    return if count <= 0

    # Process 4 pixels (16 bytes) at a time
    simd_count = (count // 4) * 4
    remainder = count - simd_count

    # Clamp adjustment to valid range
    adj = adjustment.clamp(-255, 255)

    # Create adjustment vector (add to RGB, not A)
    adj_abs = adj.abs.to_u8
    adj_vec = StaticArray[
      adj_abs, adj_abs, adj_abs, 0_u8,
      adj_abs, adj_abs, adj_abs, 0_u8,
      adj_abs, adj_abs, adj_abs, 0_u8,
      adj_abs, adj_abs, adj_abs, 0_u8,
    ]
    adj_ptr = adj_vec.to_unsafe

    # Process SIMD chunks
    i = 0
    while i < simd_count
      pixel_ptr = pixels + (i * 4)

      {% if flag?(:x86_64) %}
        if adj >= 0
          asm(
            "movdqu ($0), %xmm0
             movdqu ($1), %xmm1
             paddusb %xmm1, %xmm0
             movdqu %xmm0, ($0)"
                  :: "r"(pixel_ptr), "r"(adj_ptr)
                  : "xmm0", "xmm1", "memory"
                  : "volatile"
          )
        else
          asm(
            "movdqu ($0), %xmm0
             movdqu ($1), %xmm1
             psubusb %xmm1, %xmm0
             movdqu %xmm0, ($0)"
                  :: "r"(pixel_ptr), "r"(adj_ptr)
                  : "xmm0", "xmm1", "memory"
                  : "volatile"
          )
        end
      {% elsif flag?(:aarch64) %}
        if adj >= 0
          asm(
            "ld1 {v0.16b}, [$0]
             ld1 {v1.16b}, [$1]
             uqadd v0.16b, v0.16b, v1.16b
             st1 {v0.16b}, [$0]"
                  :: "r"(pixel_ptr), "r"(adj_ptr)
                  : "v0", "v1", "memory"
                  : "volatile"
          )
        else
          asm(
            "ld1 {v0.16b}, [$0]
             ld1 {v1.16b}, [$1]
             uqsub v0.16b, v0.16b, v1.16b
             st1 {v0.16b}, [$0]"
                  :: "r"(pixel_ptr), "r"(adj_ptr)
                  : "v0", "v1", "memory"
                  : "volatile"
          )
        end
      {% else %}
        # Scalar fallback
        4.times do |j|
          offset = (i + j) * 4
          pixels[offset + 0] = (pixels[offset + 0].to_i32 + adjustment).clamp(0, 255).to_u8
          pixels[offset + 1] = (pixels[offset + 1].to_i32 + adjustment).clamp(0, 255).to_u8
          pixels[offset + 2] = (pixels[offset + 2].to_i32 + adjustment).clamp(0, 255).to_u8
        end
      {% end %}

      i += 4
    end

    # Handle remaining pixels
    remainder.times do |j|
      offset = (simd_count + j) * 4
      pixels[offset + 0] = (pixels[offset + 0].to_i32 + adjustment).clamp(0, 255).to_u8
      pixels[offset + 1] = (pixels[offset + 1].to_i32 + adjustment).clamp(0, 255).to_u8
      pixels[offset + 2] = (pixels[offset + 2].to_i32 + adjustment).clamp(0, 255).to_u8
    end
  end

  # SIMD helper for color inversion on RGBA pixels
  # Inverts RGB channels (255 - value) while preserving alpha
  # Processes 4 pixels (16 bytes) at a time
  private def self.simd_invert_rgba(pixels : UInt8*, count : Int64)
    return if count <= 0

    # Process 4 pixels (16 bytes) at a time
    simd_count = (count // 4) * 4
    remainder = count - simd_count

    # Mask for inverting RGB but not A (0xFF for RGB, 0x00 for A)
    mask = StaticArray[
      0xFF_u8, 0xFF_u8, 0xFF_u8, 0x00_u8,
      0xFF_u8, 0xFF_u8, 0xFF_u8, 0x00_u8,
      0xFF_u8, 0xFF_u8, 0xFF_u8, 0x00_u8,
      0xFF_u8, 0xFF_u8, 0xFF_u8, 0x00_u8,
    ]
    mask_ptr = mask.to_unsafe

    # Process SIMD chunks
    i = 0
    while i < simd_count
      pixel_ptr = pixels + (i * 4)

      {% if flag?(:x86_64) %}
        asm(
          "movdqu ($0), %xmm0
           movdqu ($1), %xmm1
           pxor %xmm1, %xmm0
           movdqu %xmm0, ($0)"
                :: "r"(pixel_ptr), "r"(mask_ptr)
                : "xmm0", "xmm1", "memory"
                : "volatile"
        )
      {% elsif flag?(:aarch64) %}
        asm(
          "ld1 {v0.16b}, [$0]
           ld1 {v1.16b}, [$1]
           eor v0.16b, v0.16b, v1.16b
           st1 {v0.16b}, [$0]"
                :: "r"(pixel_ptr), "r"(mask_ptr)
                : "v0", "v1", "memory"
                : "volatile"
        )
      {% else %}
        # Scalar fallback
        4.times do |j|
          offset = (i + j) * 4
          pixels[offset + 0] = (255 - pixels[offset + 0]).to_u8
          pixels[offset + 1] = (255 - pixels[offset + 1]).to_u8
          pixels[offset + 2] = (255 - pixels[offset + 2]).to_u8
        end
      {% end %}

      i += 4
    end

    # Handle remaining pixels
    remainder.times do |j|
      offset = (simd_count + j) * 4
      pixels[offset + 0] = (255 - pixels[offset + 0]).to_u8
      pixels[offset + 1] = (255 - pixels[offset + 1]).to_u8
      pixels[offset + 2] = (255 - pixels[offset + 2]).to_u8
    end
  end

  # Adjusts the brightness of an image.
  #
  # Adds a constant value to all RGB channels. Positive values brighten,
  # negative values darken. Values are clamped to 0-255 range.
  # Alpha channel is preserved.
  #
  # Parameters:
  # - `src` : The source image to adjust
  # - `adjustment` : Brightness adjustment value (-255 to 255)
  #
  # Returns: A new `Image` with adjusted brightness
  #
  # Raises: `ArgumentError` if adjustment is outside valid range
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # brighter = CrImage::Transform.brightness(img, 50)
  # darker = CrImage::Transform.brightness(img, -30)
  # ```
  def self.brightness(src : Image, adjustment : Int32) : Image
    InputValidation.validate_adjustment(adjustment, -255, 255, "brightness")

    # Fast path for RGBA images using SIMD
    if src.is_a?(RGBA)
      src_rgba = src.as(RGBA)
      dst = RGBA.new(CrImage.rect(0, 0, src_rgba.bounds.width, src_rgba.bounds.height))
      dst.pix.copy_from(src_rgba.pix.to_unsafe, src_rgba.pix.size)

      pixel_count = (src_rgba.bounds.width.to_i64 * src_rgba.bounds.height.to_i64)
      simd_brightness_rgba(dst.pix.to_unsafe, pixel_count, adjustment)

      return dst
    end

    # Fallback for other image types
    Util::PixelIterator.map_pixels_8bit(src) do |r, g, b, a|
      Color::RGBA.new(
        BoundsCheck.clamp_u8(r.to_i32 + adjustment),
        BoundsCheck.clamp_u8(g.to_i32 + adjustment),
        BoundsCheck.clamp_u8(b.to_i32 + adjustment),
        a
      )
    end
  end

  # Adjusts the contrast of an image.
  #
  # Scales RGB values around the midpoint (128). Values greater than 1.0
  # increase contrast, values less than 1.0 decrease contrast.
  # Alpha channel is preserved.
  #
  # Parameters:
  # - `src` : The source image to adjust
  # - `factor` : Contrast factor (0.0 to 2.0, where 1.0 is no change)
  #
  # Returns: A new `Image` with adjusted contrast
  #
  # Raises: `ArgumentError` if factor is outside valid range
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # high_contrast = CrImage::Transform.contrast(img, 1.5)
  # low_contrast = CrImage::Transform.contrast(img, 0.7)
  # ```
  def self.contrast(src : Image, factor : Float64) : Image
    InputValidation.validate_factor(factor, 0.0, 2.0, "contrast")

    # Fast path for RGBA images
    if src.is_a?(RGBA)
      src_rgba = src.as(RGBA)
      dst = RGBA.new(CrImage.rect(0, 0, src_rgba.bounds.width, src_rgba.bounds.height))
      dst.pix.copy_from(src_rgba.pix.to_unsafe, src_rgba.pix.size)

      pixel_count = (src_rgba.bounds.width.to_i64 * src_rgba.bounds.height.to_i64)
      optimized_contrast_rgba(dst.pix.to_unsafe, pixel_count, factor)

      return dst
    end

    # Fallback for other image types
    Util::PixelIterator.map_pixels_8bit(src) do |r, g, b, a|
      Color::RGBA.new(
        BoundsCheck.clamp_u8((r.to_i32 - 128) * factor + 128),
        BoundsCheck.clamp_u8((g.to_i32 - 128) * factor + 128),
        BoundsCheck.clamp_u8((b.to_i32 - 128) * factor + 128),
        a
      )
    end
  end

  # Converts an image to grayscale.
  #
  # Uses the luminosity method with standard weights (R: 0.299, G: 0.587, B: 0.114)
  # to convert color images to grayscale. Returns a `Gray` image.
  #
  # Parameters:
  # - `src` : The source image to convert
  #
  # Returns: A new `Gray` image
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("color_photo.png")
  # gray = CrImage::Transform.grayscale(img)
  # CrImage::PNG.write("gray_photo.png", gray)
  # ```
  def self.grayscale(src : Image) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = Gray.new(CrImage.rect(0, 0, width, height))

    Util::PixelIterator.each_pixel(src) do |x, y, r, g, b, a|
      gray_value = ((r * 299 + g * 587 + b * 114) // 1000) >> 8
      dst.set(x, y, Color::Gray.new(gray_value.to_u8))
    end

    dst
  end

  # Inverts the colors of an image (negative effect).
  #
  # Subtracts each RGB channel value from 255 to create a color negative.
  # Alpha channel is preserved.
  #
  # Parameters:
  # - `src` : The source image to invert
  #
  # Returns: A new `Image` with inverted colors
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # negative = CrImage::Transform.invert(img)
  # ```
  def self.invert(src : Image) : Image
    # Fast path for RGBA images using SIMD
    if src.is_a?(RGBA)
      src_rgba = src.as(RGBA)
      dst = RGBA.new(CrImage.rect(0, 0, src_rgba.bounds.width, src_rgba.bounds.height))
      dst.pix.copy_from(src_rgba.pix.to_unsafe, src_rgba.pix.size)

      pixel_count = (src_rgba.bounds.width.to_i64 * src_rgba.bounds.height.to_i64)
      simd_invert_rgba(dst.pix.to_unsafe, pixel_count)

      return dst
    end

    # Fallback for other image types
    Util::PixelIterator.map_pixels_8bit(src) do |r, g, b, a|
      Color::RGBA.new(
        (255 - r).to_u8,
        (255 - g).to_u8,
        (255 - b).to_u8,
        a
      )
    end
  end
end
