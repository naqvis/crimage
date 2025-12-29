require "../util/convolution"
require "../util/pixel_iterator"

module CrImage::Transform
  # Applies a box blur filter to an image.
  #
  # Box blur is a simple averaging filter that blurs by averaging all pixels
  # within a square kernel. Fast but produces lower quality blur compared to Gaussian.
  # Edge pixels are clamped to image boundaries.
  #
  # Parameters:
  # - `src` : The source image to blur
  # - `radius` : Blur radius in pixels (must be positive)
  #
  # Returns: A new blurred `Image`
  #
  # Raises: `ArgumentError` if radius is not positive
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # blurred = CrImage::Transform.blur_box(img, 5)
  # ```
  def self.blur_box(src : Image, radius : Int32) : Image
    raise ArgumentError.new("Radius must be positive, got #{radius}") if radius <= 0

    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))
    kernel_size = radius * 2 + 1
    divisor = kernel_size * kernel_size

    height.times do |y|
      width.times do |x|
        r_sum = 0_u32
        g_sum = 0_u32
        b_sum = 0_u32
        a_sum = 0_u32

        # Sum pixels in kernel
        (-radius..radius).each do |dy|
          (-radius..radius).each do |dx|
            src_x, src_y = BoundsCheck.clamp_point(x + dx + src_bounds.min.x, y + dy + src_bounds.min.y, src_bounds)

            r, g, b, a = src.at(src_x, src_y).rgba
            r_sum += r
            g_sum += g
            b_sum += b
            a_sum += a
          end
        end

        # Average
        dst.set(x, y, Color::RGBA.new(
          ((r_sum // divisor) >> 8).to_u8,
          ((g_sum // divisor) >> 8).to_u8,
          ((b_sum // divisor) >> 8).to_u8,
          ((a_sum // divisor) >> 8).to_u8
        ))
      end
    end

    dst
  end

  # Applies Gaussian blur to an image.
  #
  # Gaussian blur uses a weighted average based on the Gaussian distribution,
  # producing natural-looking blur. Implemented as separable convolution for efficiency.
  # If sigma is not provided, it defaults to radius/3.
  #
  # Parameters:
  # - `src` : The source image to blur
  # - `radius` : Blur radius in pixels (must be non-negative, 0 returns a copy)
  # - `sigma` : Standard deviation of Gaussian kernel (optional, defaults to radius/3)
  #
  # Returns: A new blurred `Image`
  #
  # Raises: `ArgumentError` if radius is negative
  #
  # Example:
  # ```
  # img = CrImage::PNG.read("photo.png")
  # blurred = CrImage::Transform.blur_gaussian(img, 10)
  # custom_blur = CrImage::Transform.blur_gaussian(img, 10, sigma: 5.0)
  # ```
  def self.blur_gaussian(src : Image, radius : Int32, sigma : Float64? = nil) : Image
    InputValidation.validate_radius(radius)

    # Handle radius 0 case - return copy of original
    if radius == 0
      return Util::PixelIterator.map_pixels(src) { |r, g, b, a| Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8) }
    end

    kernel = Util::Convolution.gaussian_kernel(radius, sigma)
    Util::Convolution.apply_separable(src, kernel)
  end

  # Applies a sharpening filter to an image.
  #
  # Enhances edges and details using an unsharp mask technique.
  # Higher amounts produce more pronounced sharpening. Values above 2.0
  # may produce artifacts.
  #
  # Parameters:
  # - `src` : The source image to sharpen
  # - `amount` : Sharpening strength (default: 1.0, typical range: 0.5-2.0)
  #
  # Returns: A new sharpened `Image`
  #
  # Example:
  # ```
  # img = CrImage::JPEG.read("photo.jpg")
  # sharpened = CrImage::Transform.sharpen(img, 1.5)
  # ```
  def self.sharpen(src : Image, amount : Float64 = 1.0) : Image
    src_bounds = src.bounds
    width = src_bounds.width
    height = src_bounds.height

    dst = RGBA.new(CrImage.rect(0, 0, width, height))

    center = 1.0 + 4.0 * amount
    neighbor = -amount

    height.times do |y|
      width.times do |x|
        r_sum = g_sum = b_sum = a_sum = 0.0

        [-1, 0, 1].each do |dy|
          [-1, 0, 1].each do |dx|
            src_x, src_y = BoundsCheck.clamp_point(x + dx + src_bounds.min.x, y + dy + src_bounds.min.y, src_bounds)

            r, g, b, a = src.at(src_x, src_y).rgba

            weight = (dx == 0 && dy == 0) ? center : neighbor
            r_sum += (r >> 8) * weight
            g_sum += (g >> 8) * weight
            b_sum += (b >> 8) * weight
            a_sum += (a >> 8) * weight
          end
        end

        dst.set(x, y, Color::RGBA.new(
          BoundsCheck.clamp_u8(r_sum),
          BoundsCheck.clamp_u8(g_sum),
          BoundsCheck.clamp_u8(b_sum),
          BoundsCheck.clamp_u8(a_sum)
        ))
      end
    end

    dst
  end
end
