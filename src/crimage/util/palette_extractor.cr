module CrImage::Util
  # Extracts dominant colors from images for theming, analysis, and design.
  #
  # Provides tools for analyzing color composition and extracting the most
  # prominent colors from images. Useful for:
  # - Generating color themes and palettes
  # - Image categorization and search
  # - Design tools and color pickers
  # - Automatic UI theming
  # - Color-based image analysis
  module PaletteExtractor
    # Extracts the most dominant colors from an image.
    #
    # Uses color quantization algorithms to identify the most prominent colors.
    # Returns colors sorted by visual prominence (most dominant first).
    #
    # Parameters:
    # - `src` : The source image
    # - `count` : Number of colors to extract (1-256, default: 5)
    # - `algorithm` : Quantization algorithm to use (default: MedianCut)
    #
    # Returns: Array of dominant colors, sorted by prominence
    #
    # Raises: `ArgumentError` if count is outside 1-256 range
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # colors = img.extract_palette(5)
    # colors.each { |c| puts c.to_hex }
    # ```
    def self.extract(src : Image, count : Int32 = 5,
                     algorithm : QuantizationAlgorithm = QuantizationAlgorithm::MedianCut) : Array(Color::Color)
      raise ArgumentError.new("count must be between 1 and 256") unless count >= 1 && count <= 256

      palette = Quantization.generate_palette(src, count, algorithm)
      palette.to_a
    end

    # Extracts dominant colors with their relative frequencies.
    #
    # Similar to `extract` but also returns the percentage of the image
    # each color represents. Results are sorted by frequency (most common first).
    #
    # Parameters:
    # - `src` : The source image
    # - `count` : Number of colors to extract (1-256, default: 5)
    # - `algorithm` : Quantization algorithm to use (default: MedianCut)
    #
    # Returns: Array of tuples (color, weight) where weight is 0.0-1.0
    #
    # Raises: `ArgumentError` if count is outside 1-256 range
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # colors = img.extract_palette_with_weights(5)
    # colors.each do |color, weight|
    #   puts "#{color.to_hex}: #{(weight * 100).round(1)}%"
    # end
    # ```
    def self.extract_with_weights(src : Image, count : Int32 = 5,
                                  algorithm : QuantizationAlgorithm = QuantizationAlgorithm::MedianCut) : Array(Tuple(Color::Color, Float64))
      raise ArgumentError.new("count must be between 1 and 256") unless count >= 1 && count <= 256

      # Get palette
      palette = Quantization.generate_palette(src, count, algorithm)

      # Count pixels matching each palette color
      color_counts = Hash(Color::Color, Int32).new(0)
      total_pixels = 0

      bounds = src.bounds
      bounds.height.times do |y|
        bounds.width.times do |x|
          pixel = src.at(x + bounds.min.x, y + bounds.min.y)
          # Find closest palette color
          closest = find_closest_color(pixel, palette)
          color_counts[closest] += 1
          total_pixels += 1
        end
      end

      # Convert to weights and sort by frequency
      results = color_counts.map do |color, count|
        {color, count.to_f64 / total_pixels}
      end

      results.sort_by { |_, weight| -weight }
    end

    # Extracts the single most dominant color from the image.
    #
    # Convenience method that returns only the most prominent color.
    #
    # Parameters:
    # - `src` : The source image
    #
    # Returns: The most dominant color
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # dominant = img.dominant_color
    # puts "Main color: #{dominant.to_hex}"
    # ```
    def self.dominant_color(src : Image) : Color::Color
      extract(src, 2).first
    end

    # Finds the closest palette color to a given pixel using Euclidean distance.
    #
    # Uses RGB color space distance for matching.
    private def self.find_closest_color(pixel : Color::Color, palette : Color::Palette) : Color::Color
      r1, g1, b1, _ = pixel.rgba

      min_distance = Float64::MAX
      closest = palette[0]

      palette.each do |color|
        r2, g2, b2, _ = color.rgba

        # Euclidean distance in RGB space
        dr = (r1 >> 8).to_i32 - (r2 >> 8).to_i32
        dg = (g1 >> 8).to_i32 - (g2 >> 8).to_i32
        db = (b1 >> 8).to_i32 - (b2 >> 8).to_i32

        distance = (dr * dr + dg * dg + db * db).to_f64

        if distance < min_distance
          min_distance = distance
          closest = color
        end
      end

      closest
    end
  end
end

module CrImage
  module Image
    # Extracts dominant colors from the image.
    #
    # Convenience method that delegates to `Util::PaletteExtractor.extract`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # colors = img.extract_palette(5)
    # ```
    def extract_palette(count : Int32 = 5,
                        algorithm : Util::QuantizationAlgorithm = Util::QuantizationAlgorithm::MedianCut) : Array(Color::Color)
      Util::PaletteExtractor.extract(self, count, algorithm)
    end

    # Extracts dominant colors with their relative frequencies.
    #
    # Convenience method that delegates to `Util::PaletteExtractor.extract_with_weights`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # colors = img.extract_palette_with_weights(5)
    # ```
    def extract_palette_with_weights(count : Int32 = 5,
                                     algorithm : Util::QuantizationAlgorithm = Util::QuantizationAlgorithm::MedianCut) : Array(Tuple(Color::Color, Float64))
      Util::PaletteExtractor.extract_with_weights(self, count, algorithm)
    end

    # Returns the most dominant color in the image.
    #
    # Convenience method that delegates to `Util::PaletteExtractor.dominant_color`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # dominant = img.dominant_color
    # ```
    def dominant_color : Color::Color
      Util::PaletteExtractor.dominant_color(self)
    end
  end
end
