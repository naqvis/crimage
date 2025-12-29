module CrImage::Util
  # Visual difference detection and highlighting.
  #
  # Generates diff images showing pixel differences between two images,
  # useful for visual regression testing.
  module VisualDiff
    # Generates a diff image highlighting differences between two images.
    #
    # Pixels that differ beyond the threshold are highlighted in the specified color.
    # Unchanged pixels are shown in grayscale (dimmed).
    #
    # Parameters:
    # - `img1` : First image (reference)
    # - `img2` : Second image (comparison)
    # - `threshold` : Color difference threshold (0-255, default: 10)
    # - `highlight_color` : Color for different pixels (default: red)
    # - `show_unchanged` : Whether to show unchanged pixels in grayscale (default: true)
    #
    # Returns: Diff image with highlighted differences
    #
    # Raises: `ArgumentError` if images have different dimensions
    def self.diff(img1 : Image, img2 : Image,
                  threshold : Int32 = 10,
                  highlight_color : Color::Color = Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8),
                  show_unchanged : Bool = true) : RGBA
      b1 = img1.bounds
      b2 = img2.bounds

      unless b1.width == b2.width && b1.height == b2.height
        raise ArgumentError.new("Images must have same dimensions: #{b1.width}x#{b1.height} vs #{b2.width}x#{b2.height}")
      end

      width = b1.width
      height = b1.height
      result = CrImage.rgba(width, height)

      hr, hg, hb, ha = highlight_color.rgba

      height.times do |y|
        width.times do |x|
          c1 = img1.at(x + b1.min.x, y + b1.min.y)
          c2 = img2.at(x + b2.min.x, y + b2.min.y)

          r1, g1, b1_val, a1 = c1.rgba
          r2, g2, b2_val, a2 = c2.rgba

          # Calculate color difference (max channel difference)
          dr = ((r1 >> 8).to_i32 - (r2 >> 8).to_i32).abs
          dg = ((g1 >> 8).to_i32 - (g2 >> 8).to_i32).abs
          db = ((b1_val >> 8).to_i32 - (b2_val >> 8).to_i32).abs
          da = ((a1 >> 8).to_i32 - (a2 >> 8).to_i32).abs

          max_diff = [dr, dg, db, da].max

          if max_diff > threshold
            # Highlight different pixel
            result.set(x, y, Color::RGBA.new((hr >> 8).to_u8, (hg >> 8).to_u8, (hb >> 8).to_u8, (ha >> 8).to_u8))
          elsif show_unchanged
            # Show unchanged pixel in grayscale (dimmed)
            gray = (((r1 >> 8) * 299 + (g1 >> 8) * 587 + (b1_val >> 8) * 114) // 1000).to_u8
            dimmed = (gray // 2).to_u8
            result.set(x, y, Color::RGBA.new(dimmed, dimmed, dimmed, 255_u8))
          else
            # Copy original pixel
            result.set(x, y, Color::RGBA.new((r1 >> 8).to_u8, (g1 >> 8).to_u8, (b1_val >> 8).to_u8, (a1 >> 8).to_u8))
          end
        end
      end

      result
    end

    # Counts the number of different pixels between two images.
    #
    # Parameters:
    # - `img1` : First image
    # - `img2` : Second image
    # - `threshold` : Color difference threshold (0-255, default: 10)
    #
    # Returns: Number of pixels that differ
    #
    # Raises: `ArgumentError` if images have different dimensions
    def self.diff_count(img1 : Image, img2 : Image, threshold : Int32 = 10) : Int32
      b1 = img1.bounds
      b2 = img2.bounds

      unless b1.width == b2.width && b1.height == b2.height
        raise ArgumentError.new("Images must have same dimensions")
      end

      count = 0
      b1.height.times do |y|
        b1.width.times do |x|
          c1 = img1.at(x + b1.min.x, y + b1.min.y)
          c2 = img2.at(x + b2.min.x, y + b2.min.y)

          r1, g1, b1_val, a1 = c1.rgba
          r2, g2, b2_val, a2 = c2.rgba

          dr = ((r1 >> 8).to_i32 - (r2 >> 8).to_i32).abs
          dg = ((g1 >> 8).to_i32 - (g2 >> 8).to_i32).abs
          db = ((b1_val >> 8).to_i32 - (b2_val >> 8).to_i32).abs
          da = ((a1 >> 8).to_i32 - (a2 >> 8).to_i32).abs

          max_diff = [dr, dg, db, da].max
          count += 1 if max_diff > threshold
        end
      end

      count
    end

    # Calculates the percentage of different pixels.
    #
    # Parameters:
    # - `img1` : First image
    # - `img2` : Second image
    # - `threshold` : Color difference threshold (0-255, default: 10)
    #
    # Returns: Percentage of different pixels (0.0 to 100.0)
    def self.diff_percent(img1 : Image, img2 : Image, threshold : Int32 = 10) : Float64
      b1 = img1.bounds
      total = b1.width * b1.height
      return 0.0 if total == 0

      count = diff_count(img1, img2, threshold)
      (count.to_f64 / total) * 100.0
    end

    # Checks if two images are visually identical within threshold.
    #
    # Parameters:
    # - `img1` : First image
    # - `img2` : Second image
    # - `threshold` : Color difference threshold (default: 10)
    # - `tolerance` : Maximum allowed different pixels (default: 0)
    #
    # Returns: true if images are identical within tolerance
    def self.identical?(img1 : Image, img2 : Image,
                        threshold : Int32 = 10,
                        tolerance : Int32 = 0) : Bool
      b1 = img1.bounds
      b2 = img2.bounds

      return false unless b1.width == b2.width && b1.height == b2.height

      diff_count(img1, img2, threshold) <= tolerance
    end
  end
end

module CrImage
  module Image
    # Generates a visual diff against another image.
    def visual_diff(other : Image, threshold : Int32 = 10,
                    highlight_color : Color::Color = Color::RGBA.new(255_u8, 0_u8, 0_u8, 255_u8)) : RGBA
      Util::VisualDiff.diff(self, other, threshold, highlight_color)
    end

    # Counts different pixels compared to another image.
    def diff_count(other : Image, threshold : Int32 = 10) : Int32
      Util::VisualDiff.diff_count(self, other, threshold)
    end

    # Checks if visually identical to another image.
    def identical?(other : Image, threshold : Int32 = 10, tolerance : Int32 = 0) : Bool
      Util::VisualDiff.identical?(self, other, threshold, tolerance)
    end
  end
end
