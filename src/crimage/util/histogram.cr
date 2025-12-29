module CrImage::Util
  # Represents a histogram of pixel intensity values.
  #
  # A histogram shows the distribution of pixel brightness levels (0-255)
  # in an image. Useful for analyzing image characteristics and applying
  # contrast enhancements.
  #
  # The histogram contains 256 bins, one for each possible intensity value,
  # and tracks the total number of pixels analyzed.
  class Histogram
    getter bins : Array(Int32)
    getter total_pixels : Int32

    def initialize(@bins : Array(Int32), @total_pixels : Int32)
    end

    # Calculates the mean (average) intensity value across all pixels.
    #
    # Returns: Average brightness value (0.0-255.0)
    def mean : Float64
      sum = 0_i64
      @bins.each_with_index do |count, value|
        sum += count * value
      end
      sum.to_f / @total_pixels
    end

    # Calculates the median intensity value (50th percentile).
    #
    # Returns: The intensity value at which half the pixels are darker
    def median : Int32
      half = @total_pixels // 2
      cumulative = 0
      @bins.each_with_index do |count, value|
        cumulative += count
        return value if cumulative >= half
      end
      127
    end

    # Calculates the standard deviation of intensity values.
    #
    # Measures the spread of brightness values. Higher values indicate
    # more contrast, lower values indicate more uniform brightness.
    #
    # Returns: Standard deviation of pixel intensities
    def std_dev : Float64
      m = mean
      variance = 0.0
      @bins.each_with_index do |count, value|
        diff = value - m
        variance += count * diff * diff
      end
      ::Math.sqrt(variance / @total_pixels)
    end

    # Returns the intensity value at the specified percentile (0-100).
    #
    # For example, percentile(95) returns the brightness level below which
    # 95% of pixels fall.
    #
    # Parameters:
    # - `p` : Percentile value (0.0-100.0)
    #
    # Returns: Intensity value at that percentile
    #
    # Raises: `ArgumentError` if percentile is outside 0-100 range
    def percentile(p : Float64) : Int32
      raise ArgumentError.new("Percentile must be between 0 and 100") unless p >= 0 && p <= 100

      target = (@total_pixels * p / 100.0).to_i
      cumulative = 0
      @bins.each_with_index do |count, value|
        cumulative += count
        return value if cumulative >= target
      end
      255
    end
  end

  module HistogramOps
    # Computes the histogram of an image's luminance values.
    #
    # Parameters:
    # - `src` : The source image
    #
    # Returns: A `Histogram` object with 256 bins (0-255)
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("photo.png")
    # hist = CrImage::Util::HistogramOps.compute(img)
    # puts "Mean brightness: #{hist.mean}"
    # puts "Median: #{hist.median}"
    # ```
    def self.compute(src : Image) : Histogram
      bins = Array(Int32).new(256, 0)
      total = 0

      src_bounds = src.bounds
      height = src_bounds.height
      width = src_bounds.width

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          # Calculate luminance
          luminance = ((r * 299 + g * 587 + b * 114) // 1000) >> 8
          bins[luminance] += 1
          total += 1
        end
      end

      Histogram.new(bins, total)
    end

    # Applies histogram equalization to enhance image contrast.
    #
    # Histogram equalization redistributes pixel intensities to use the full
    # dynamic range, improving contrast in low-contrast images.
    #
    # Parameters:
    # - `src` : The source image
    #
    # Returns: A new `Image` with equalized histogram
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("low_contrast.png")
    # enhanced = CrImage::Util::HistogramOps.equalize(img)
    # ```
    def self.equalize(src : Image) : Image
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      # Compute histogram for each channel
      r_bins = Array(Int32).new(256, 0)
      g_bins = Array(Int32).new(256, 0)
      b_bins = Array(Int32).new(256, 0)
      total = width * height

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          r_bins[r >> 8] += 1
          g_bins[g >> 8] += 1
          b_bins[b >> 8] += 1
        end
      end

      # Compute cumulative distribution function (CDF) for each channel
      r_cdf = compute_cdf(r_bins, total)
      g_cdf = compute_cdf(g_bins, total)
      b_cdf = compute_cdf(b_bins, total)

      # Apply equalization
      dst = RGBA.new(CrImage.rect(0, 0, width, height))

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba

          new_r = r_cdf[r >> 8]
          new_g = g_cdf[g >> 8]
          new_b = b_cdf[b >> 8]

          dst.set(x, y, Color::RGBA.new(new_r, new_g, new_b, (a >> 8).to_u8))
        end
      end

      dst
    end

    # Applies adaptive histogram equalization (CLAHE - Contrast Limited AHE).
    #
    # CLAHE divides the image into tiles and applies histogram equalization
    # to each tile separately, with contrast limiting to prevent over-amplification
    # of noise. Results are interpolated for smooth transitions.
    #
    # Parameters:
    # - `src` : The source image
    # - `tile_size` : Size of tiles for local equalization (default: 8)
    # - `clip_limit` : Contrast limiting factor (default: 2.0, range: 1.0-4.0)
    #
    # Returns: A new `Image` with adaptive equalization
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("photo.png")
    # enhanced = CrImage::Util::HistogramOps.equalize_adaptive(img)
    # ```
    def self.equalize_adaptive(src : Image, tile_size : Int32 = 8, clip_limit : Float64 = 2.0) : Image
      raise ArgumentError.new("Tile size must be positive") if tile_size <= 0
      InputValidation.validate_factor(clip_limit, 1.0, 4.0, "clip limit")

      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      # Calculate number of tiles
      tiles_x = (width + tile_size - 1) // tile_size
      tiles_y = (height + tile_size - 1) // tile_size

      # Compute histogram for each tile
      tile_cdfs = Array(Array(Array(UInt8))).new(tiles_y) do |ty|
        Array(Array(UInt8)).new(tiles_x) do |tx|
          compute_tile_cdf(src, tx * tile_size, ty * tile_size, tile_size, clip_limit)
        end
      end

      # Apply equalization with bilinear interpolation
      dst = RGBA.new(CrImage.rect(0, 0, width, height))

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          luminance = ((r * 299 + g * 587 + b * 114) // 1000) >> 8

          # Find tile coordinates
          tile_x = (x.to_f / tile_size).clamp(0, tiles_x - 1).to_i
          tile_y = (y.to_f / tile_size).clamp(0, tiles_y - 1).to_i

          # Get equalized value from tile
          cdf = tile_cdfs[tile_y][tile_x]
          new_luminance = cdf[luminance]

          # Scale RGB channels proportionally
          scale = new_luminance.to_f / (luminance == 0 ? 1 : luminance)
          new_r = ((r >> 8) * scale).clamp(0, 255).to_u8
          new_g = ((g >> 8) * scale).clamp(0, 255).to_u8
          new_b = ((b >> 8) * scale).clamp(0, 255).to_u8

          dst.set(x, y, Color::RGBA.new(new_r, new_g, new_b, (a >> 8).to_u8))
        end
      end

      dst
    end

    # Computes CDF (Cumulative Distribution Function) from histogram bins.
    #
    # The CDF is used for histogram equalization, mapping input intensities
    # to output intensities that use the full dynamic range.
    private def self.compute_cdf(bins : Array(Int32), total : Int32) : Array(UInt8)
      cdf_values = Array(Int32).new(256, 0)
      cumulative = 0
      min_cdf = -1

      # Build cumulative distribution
      bins.each_with_index do |count, i|
        if count > 0 && min_cdf == -1
          min_cdf = cumulative
        end
        cumulative += count
        cdf_values[i] = cumulative
      end

      # Normalize CDF to 0-255 range
      cdf = Array(UInt8).new(256, 0_u8)
      range = total - min_cdf

      if range == 0
        return cdf
      end

      256.times do |i|
        normalized = ((cdf_values[i] - min_cdf).to_f / range) * 255
        cdf[i] = normalized.round.clamp(0, 255).to_u8
      end

      cdf
    end

    # Computes CDF for a single tile with contrast limiting (CLAHE).
    #
    # Applies histogram clipping to prevent over-amplification of noise
    # in low-contrast regions, then redistributes excess counts uniformly.
    private def self.compute_tile_cdf(src : Image, start_x : Int32, start_y : Int32,
                                      tile_size : Int32, clip_limit : Float64) : Array(UInt8)
      bins = Array(Int32).new(256, 0)
      src_bounds = src.bounds
      count = 0

      # Compute histogram for tile
      tile_size.times do |dy|
        tile_size.times do |dx|
          x = start_x + dx
          y = start_y + dy
          next if x >= src_bounds.width || y >= src_bounds.height

          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          luminance = ((r * 299 + g * 587 + b * 114) // 1000) >> 8
          bins[luminance] += 1
          count += 1
        end
      end

      return Array(UInt8).new(256) { |i| i.to_u8 } if count == 0

      # Apply contrast limiting
      clip_value = (count.to_f / 256.0 * clip_limit).to_i
      excess = 0

      bins.each_with_index do |value, i|
        if value > clip_value
          excess += value - clip_value
          bins[i] = clip_value
        end
      end

      # Redistribute excess
      redistribute = excess // 256
      bins.map! { |v| v + redistribute }

      compute_cdf(bins, count)
    end
  end
end
