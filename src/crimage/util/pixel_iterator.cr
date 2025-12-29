module CrImage::Util
  # Pixel iteration utilities for functional-style image processing.
  #
  # Provides high-level iteration methods for transforming images pixel-by-pixel
  # using blocks/closures. Useful for custom color transformations and filters.
  module PixelIterator
    # Maps each pixel through a transformation function.
    #
    # Applies the given block to every pixel in the image, where the block
    # receives 32-bit RGBA values and returns a new color.
    #
    # Parameters:
    # - `src` : The source image
    # - `block` : Transformation function (r, g, b, a) -> Color
    #
    # Returns: A new RGBA image with transformed pixels
    #
    # Example:
    # ```
    # # Invert colors
    # inverted = CrImage::Util::PixelIterator.map_pixels(img) do |r, g, b, a|
    #   CrImage::Color.rgba(
    #     (65535 - r).to_u8,
    #     (65535 - g).to_u8,
    #     (65535 - b).to_u8,
    #     a >> 8
    #   )
    # end
    # ```
    def self.map_pixels(src : Image, &block : UInt32, UInt32, UInt32, UInt32 -> Color::Color) : Image
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      dst = RGBA.new(CrImage.rect(0, 0, width, height))

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          dst.set(x, y, yield(r, g, b, a))
        end
      end

      dst
    end

    # Maps each pixel through a transformation function using 8-bit values.
    #
    # Convenience method that converts 32-bit color values to 8-bit (0-255)
    # before passing to the block. Simpler for most use cases.
    #
    # Parameters:
    # - `src` : The source image
    # - `block` : Transformation function (r, g, b, a) -> Color::RGBA
    #
    # Returns: A new RGBA image with transformed pixels
    #
    # Example:
    # ```
    # # Increase brightness
    # brighter = CrImage::Util::PixelIterator.map_pixels_8bit(img) do |r, g, b, a|
    #   CrImage::Color::RGBA.new(
    #     (r + 50).clamp(0, 255).to_u8,
    #     (g + 50).clamp(0, 255).to_u8,
    #     (b + 50).clamp(0, 255).to_u8,
    #     a
    #   )
    # end
    # ```
    def self.map_pixels_8bit(src : Image, &block : UInt8, UInt8, UInt8, UInt8 -> Color::RGBA) : Image
      map_pixels(src) do |r, g, b, a|
        yield((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, (a >> 8).to_u8)
      end
    end

    # Iterates over each pixel with coordinates and color values.
    #
    # Calls the block for every pixel, passing both position (x, y) and
    # 32-bit color values (r, g, b, a). Useful for analysis and statistics.
    #
    # Parameters:
    # - `src` : The source image
    # - `block` : Iteration function (x, y, r, g, b, a) -> Nil
    #
    # Returns: Nothing (side effects only)
    #
    # Example:
    # ```
    # # Count bright pixels
    # bright_count = 0
    # CrImage::Util::PixelIterator.each_pixel(img) do |x, y, r, g, b, a|
    #   luminance = (r * 299 + g * 587 + b * 114) // 1000
    #   bright_count += 1 if luminance > 32768
    # end
    # ```
    def self.each_pixel(src : Image, &block : Int32, Int32, UInt32, UInt32, UInt32, UInt32 -> Nil)
      src_bounds = src.bounds
      height = src_bounds.height
      width = src_bounds.width

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          yield(x, y, r, g, b, a)
        end
      end
    end
  end
end
