# Image comparison and quality metrics.
# Provides tools for measuring similarity and quality between images.

module CrImage::Util
  module Metrics
    # Calculates Mean Squared Error (MSE) between two images.
    #
    # MSE measures the average squared difference between corresponding pixels.
    # Lower values indicate more similar images. 0 means identical images.
    #
    # Parameters:
    # - `img1` : First image
    # - `img2` : Second image
    #
    # Returns: MSE value (0.0 = identical, higher = more different)
    #
    # Raises: `ArgumentError` if images have different dimensions
    #
    # Example:
    # ```
    # original = CrImage::PNG.read("original.png")
    # compressed = CrImage::JPEG.read("compressed.jpg")
    # mse = CrImage::Util::Metrics.mse(original, compressed)
    # puts "MSE: #{mse}"
    # ```
    def self.mse(img1 : Image, img2 : Image) : Float64
      validate_same_size(img1, img2)

      bounds1 = img1.bounds
      width = bounds1.width
      height = bounds1.height

      sum = 0.0
      total_pixels = width * height * 3 # RGB channels

      height.times do |y|
        width.times do |x|
          r1, g1, b1, _ = img1.at(x + bounds1.min.x, y + bounds1.min.y).rgba
          r2, g2, b2, _ = img2.at(x + bounds1.min.x, y + bounds1.min.y).rgba

          diff_r = (r1 >> 8).to_i32 - (r2 >> 8).to_i32
          diff_g = (g1 >> 8).to_i32 - (g2 >> 8).to_i32
          diff_b = (b1 >> 8).to_i32 - (b2 >> 8).to_i32

          sum += diff_r * diff_r + diff_g * diff_g + diff_b * diff_b
        end
      end

      sum / total_pixels
    end

    # Calculates Peak Signal-to-Noise Ratio (PSNR) between two images.
    #
    # PSNR is a quality metric expressed in decibels (dB). Higher values
    # indicate better quality/similarity. Commonly used for compression quality.
    #
    # Typical values:
    # - > 40 dB: Excellent quality
    # - 30-40 dB: Good quality
    # - 20-30 dB: Acceptable quality
    # - < 20 dB: Poor quality
    #
    # Parameters:
    # - `img1` : First image (typically original)
    # - `img2` : Second image (typically compressed/processed)
    #
    # Returns: PSNR value in dB (higher = better quality)
    #
    # Raises: `ArgumentError` if images have different dimensions
    #
    # Example:
    # ```
    # original = CrImage::PNG.read("original.png")
    # compressed = CrImage::JPEG.read("compressed.jpg")
    # psnr = CrImage::Util::Metrics.psnr(original, compressed)
    # puts "PSNR: #{psnr.round(2)} dB"
    # ```
    def self.psnr(img1 : Image, img2 : Image) : Float64
      mse_value = mse(img1, img2)
      return Float64::INFINITY if mse_value == 0.0

      max_pixel = 255.0
      10.0 * ::Math.log10((max_pixel * max_pixel) / mse_value)
    end

    # Calculates Structural Similarity Index (SSIM) between two images.
    #
    # SSIM measures perceived quality by comparing luminance, contrast, and
    # structure. Returns a value between -1 and 1, where 1 means identical.
    # More perceptually accurate than MSE/PSNR.
    #
    # Parameters:
    # - `img1` : First image
    # - `img2` : Second image
    # - `window_size` : Size of sliding window (default: 11)
    #
    # Returns: SSIM value (-1 to 1, where 1 = identical)
    #
    # Raises: `ArgumentError` if images have different dimensions
    #
    # Example:
    # ```
    # original = CrImage::PNG.read("original.png")
    # processed = CrImage::PNG.read("processed.png")
    # ssim = CrImage::Util::Metrics.ssim(original, processed)
    # puts "SSIM: #{ssim.round(4)}"
    # ```
    def self.ssim(img1 : Image, img2 : Image, window_size : Int32 = 11) : Float64
      validate_same_size(img1, img2)
      raise ArgumentError.new("Window size must be odd and positive") unless window_size > 0 && window_size.odd?

      bounds1 = img1.bounds
      width = bounds1.width
      height = bounds1.height

      # Convert to grayscale for SSIM calculation
      gray1 = to_grayscale_array(img1)
      gray2 = to_grayscale_array(img2)

      # Constants for stability
      c1 = (0.01 * 255) ** 2
      c2 = (0.03 * 255) ** 2

      ssim_sum = 0.0
      count = 0

      radius = window_size // 2

      (radius...height - radius).each do |y|
        (radius...width - radius).each do |x|
          # Calculate statistics in window
          mean1, mean2, var1, var2, covar = calculate_window_stats(
            gray1, gray2, width, x, y, window_size
          )

          # SSIM formula
          numerator = (2 * mean1 * mean2 + c1) * (2 * covar + c2)
          denominator = (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2)

          ssim_sum += numerator / denominator
          count += 1
        end
      end

      count > 0 ? ssim_sum / count : 0.0
    end

    # Calculates a perceptual hash (pHash) for image similarity detection.
    #
    # Perceptual hashing creates a compact fingerprint of an image that
    # remains similar even after transformations like resizing, compression,
    # or minor edits. Useful for duplicate detection.
    #
    # The hash is a 64-bit integer where Hamming distance indicates similarity.
    # Hamming distance < 10 typically indicates similar images.
    #
    # Parameters:
    # - `img` : The image to hash
    #
    # Returns: 64-bit perceptual hash
    #
    # Example:
    # ```
    # img1 = CrImage::PNG.read("photo1.png")
    # img2 = CrImage::PNG.read("photo2.png")
    # hash1 = CrImage::Util::Metrics.perceptual_hash(img1)
    # hash2 = CrImage::Util::Metrics.perceptual_hash(img2)
    # distance = hamming_distance(hash1, hash2)
    # puts "Similar!" if distance < 10
    # ```
    def self.perceptual_hash(img : Image) : UInt64
      # Resize to 32x32 for DCT
      small = Transform.resize_bilinear(img, 32, 32)

      # Convert to grayscale
      gray = Array(Float64).new(32 * 32) do |i|
        x = i % 32
        y = i // 32
        r, g, b, _ = small.at(x, y).rgba
        (((r * 299 + g * 587 + b * 114) // 1000) >> 8).to_f
      end

      # Apply DCT (Discrete Cosine Transform) - simplified 8x8 version
      dct = simple_dct(gray)

      # Calculate median of low frequencies (excluding DC component)
      low_freq = dct[1...65].sort
      median = low_freq[low_freq.size // 2]

      # Generate hash based on values above/below median
      hash = 0_u64
      64.times do |i|
        hash |= (1_u64 << i) if dct[i + 1] > median
      end

      hash
    end

    # Calculates Hamming distance between two perceptual hashes.
    #
    # Hamming distance counts the number of differing bits.
    # Lower values indicate more similar images.
    #
    # Parameters:
    # - `hash1` : First perceptual hash
    # - `hash2` : Second perceptual hash
    #
    # Returns: Number of differing bits (0-64)
    #
    # Example:
    # ```
    # distance = CrImage::Util::Metrics.hamming_distance(hash1, hash2)
    # puts "Very similar" if distance < 5
    # puts "Similar" if distance < 10
    # puts "Different" if distance >= 10
    # ```
    def self.hamming_distance(hash1 : UInt64, hash2 : UInt64) : Int32
      xor = hash1 ^ hash2
      count = 0
      64.times do
        count += 1 if (xor & 1) == 1
        xor >>= 1
      end
      count
    end

    # Validates that two images have the same dimensions
    private def self.validate_same_size(img1 : Image, img2 : Image)
      b1 = img1.bounds
      b2 = img2.bounds
      if b1.width != b2.width || b1.height != b2.height
        raise ArgumentError.new("Images must have the same dimensions (#{b1.width}x#{b1.height} vs #{b2.width}x#{b2.height})")
      end
    end

    # Converts image to grayscale array
    private def self.to_grayscale_array(img : Image) : Array(Float64)
      bounds = img.bounds
      width = bounds.width
      height = bounds.height

      Array(Float64).new(width * height) do |i|
        x = i % width
        y = i // width
        r, g, b, _ = img.at(x + bounds.min.x, y + bounds.min.y).rgba
        (((r * 299 + g * 587 + b * 114) // 1000) >> 8).to_f
      end
    end

    # Calculates statistics in a window for SSIM
    private def self.calculate_window_stats(gray1 : Array(Float64), gray2 : Array(Float64),
                                            width : Int32, cx : Int32, cy : Int32,
                                            window_size : Int32) : Tuple(Float64, Float64, Float64, Float64, Float64)
      radius = window_size // 2
      n = window_size * window_size

      sum1 = sum2 = sum1_sq = sum2_sq = sum12 = 0.0

      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          idx = (cy + dy) * width + (cx + dx)
          v1 = gray1[idx]
          v2 = gray2[idx]

          sum1 += v1
          sum2 += v2
          sum1_sq += v1 * v1
          sum2_sq += v2 * v2
          sum12 += v1 * v2
        end
      end

      mean1 = sum1 / n
      mean2 = sum2 / n
      var1 = sum1_sq / n - mean1 * mean1
      var2 = sum2_sq / n - mean2 * mean2
      covar = sum12 / n - mean1 * mean2

      {mean1, mean2, var1, var2, covar}
    end

    # Simplified DCT for perceptual hashing
    private def self.simple_dct(data : Array(Float64)) : Array(Float64)
      size = 32
      dct = Array(Float64).new(size * size, 0.0)

      8.times do |v|
        8.times do |u|
          sum = 0.0
          size.times do |y|
            size.times do |x|
              pixel = data[y * size + x]
              sum += pixel * ::Math.cos((2 * x + 1) * u * ::Math::PI / 16.0) *
                     ::Math.cos((2 * y + 1) * v * ::Math::PI / 16.0)
            end
          end
          dct[v * 8 + u] = sum
        end
      end

      dct
    end
  end
end
