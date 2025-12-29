module CrImage::Util
  # Smart cropping strategies.
  #
  # Different strategies for identifying important image regions:
  # - `Entropy` : Keeps regions with most detail/information (texture, patterns)
  # - `Edge` : Keeps regions with most edges (objects, boundaries)
  # - `CenterWeighted` : Balances content importance with center proximity
  # - `Attention` : Focuses on upper-center regions likely to contain subjects/faces
  enum CropStrategy
    Entropy
    Edge
    CenterWeighted
    Attention
  end

  # Smart cropping that preserves important image content
  #
  # Unlike simple center cropping, smart crop analyzes the image to find
  # the most interesting region to keep when resizing to a different aspect ratio.
  module SmartCrop
    # Performs smart crop to target dimensions
    #
    # Analyzes the image to find the most interesting region and crops to it.
    # Useful for generating thumbnails that preserve important content.
    #
    # ```
    # img = CrImage.read("photo.jpg")
    # thumbnail = img.smart_crop(800, 600)
    # ```
    def self.crop(src : Image, target_width : Int32, target_height : Int32,
                  strategy : CropStrategy = CropStrategy::Entropy) : Image
      raise ArgumentError.new("target dimensions must be positive") if target_width <= 0 || target_height <= 0

      bounds = src.bounds
      src_width = bounds.max.x - bounds.min.x
      src_height = bounds.max.y - bounds.min.y

      # If target is larger, just return original
      return src if target_width >= src_width && target_height >= src_height

      # Calculate target aspect ratio
      target_ratio = target_width.to_f64 / target_height

      # Find best crop region
      crop_rect = case strategy
                  when .entropy?
                    find_entropy_region(src, target_width, target_height)
                  when .edge?
                    find_edge_region(src, target_width, target_height)
                  when .center_weighted?
                    find_center_weighted_region(src, target_width, target_height)
                  when .attention?
                    find_attention_region(src, target_width, target_height)
                  else
                    # Fallback to center crop
                    center_crop_rect(src_width, src_height, target_width, target_height)
                  end

      src.crop(crop_rect)
    end

    # Finds the region with highest entropy (most information/detail).
    #
    # Uses variance as a proxy for entropy, scanning the image with a sliding
    # window to find the most detailed region.
    private def self.find_entropy_region(src : Image, target_width : Int32, target_height : Int32) : Rectangle
      bounds = src.bounds
      src_width = bounds.max.x - bounds.min.x
      src_height = bounds.max.y - bounds.min.y

      # Calculate sliding window size
      window_width = [target_width, src_width].min
      window_height = [target_height, src_height].min

      # Sample stride (don't check every pixel for performance)
      stride_x = [1, (src_width - window_width) // 20].max
      stride_y = [1, (src_height - window_height) // 20].max

      best_score = 0.0
      best_x = 0
      best_y = 0

      # Slide window across image
      y = 0
      while y <= src_height - window_height
        x = 0
        while x <= src_width - window_width
          score = calculate_entropy_score(src, x, y, window_width, window_height)

          if score > best_score
            best_score = score
            best_x = x
            best_y = y
          end

          x += stride_x
        end
        y += stride_y
      end

      CrImage.rect(best_x, best_y, best_x + window_width, best_y + window_height)
    end

    # Calculates entropy score for a region (higher = more detail).
    #
    # Computes variance of pixel values as a measure of information content.
    # Higher variance indicates more texture and detail.
    private def self.calculate_entropy_score(src : Image, x : Int32, y : Int32, width : Int32, height : Int32) : Float64
      # Sample pixels in region
      sample_size = 100
      step_x = [1, width // 10].max
      step_y = [1, height // 10].max

      # Calculate variance as proxy for entropy
      values = [] of Int32
      bounds = src.bounds

      sy = y
      while sy < y + height && sy < bounds.max.y
        sx = x
        while sx < x + width && sx < bounds.max.x
          r, g, b, _ = src.at(sx + bounds.min.x, sy + bounds.min.y).rgba
          # Convert to grayscale
          gray = ((r >> 8) * 299 + (g >> 8) * 587 + (b >> 8) * 114) // 1000
          values << gray.to_i32
          sx += step_x
        end
        sy += step_y
      end

      return 0.0 if values.empty?

      # Calculate variance
      mean = values.sum.to_f64 / values.size
      variance = values.sum { |v| (v - mean) ** 2 } / values.size

      variance
    end

    # Finds the region with most edges (objects and boundaries).
    #
    # Uses gradient magnitude to detect edges, scanning for the region
    # with the strongest edge content.
    private def self.find_edge_region(src : Image, target_width : Int32, target_height : Int32) : Rectangle
      bounds = src.bounds
      src_width = bounds.max.x - bounds.min.x
      src_height = bounds.max.y - bounds.min.y

      window_width = [target_width, src_width].min
      window_height = [target_height, src_height].min

      stride_x = [1, (src_width - window_width) // 20].max
      stride_y = [1, (src_height - window_height) // 20].max

      best_score = 0.0
      best_x = 0
      best_y = 0

      y = 0
      while y <= src_height - window_height
        x = 0
        while x <= src_width - window_width
          score = calculate_edge_score(src, x, y, window_width, window_height)

          if score > best_score
            best_score = score
            best_x = x
            best_y = y
          end

          x += stride_x
        end
        y += stride_y
      end

      CrImage.rect(best_x, best_y, best_x + window_width, best_y + window_height)
    end

    # Calculates edge score for a region using simple gradient.
    #
    # Computes gradient magnitude using Sobel-like operators.
    # Higher scores indicate more edges and object boundaries.
    private def self.calculate_edge_score(src : Image, x : Int32, y : Int32, width : Int32, height : Int32) : Float64
      step = [2, width // 20].max
      edge_sum = 0.0
      count = 0

      bounds = src.bounds

      sy = y + 1
      while sy < y + height - 1 && sy < bounds.max.y - 1
        sx = x + 1
        while sx < x + width - 1 && sx < bounds.max.x - 1
          # Simple Sobel-like gradient
          r1, g1, b1, _ = src.at(sx - 1 + bounds.min.x, sy + bounds.min.y).rgba
          r2, g2, b2, _ = src.at(sx + 1 + bounds.min.x, sy + bounds.min.y).rgba
          r3, g3, b3, _ = src.at(sx + bounds.min.x, sy - 1 + bounds.min.y).rgba
          r4, g4, b4, _ = src.at(sx + bounds.min.x, sy + 1 + bounds.min.y).rgba

          gx = ((r2 >> 8).to_i32 - (r1 >> 8).to_i32).abs + ((g2 >> 8).to_i32 - (g1 >> 8).to_i32).abs + ((b2 >> 8).to_i32 - (b1 >> 8).to_i32).abs
          gy = ((r4 >> 8).to_i32 - (r3 >> 8).to_i32).abs + ((g4 >> 8).to_i32 - (g3 >> 8).to_i32).abs + ((b4 >> 8).to_i32 - (b3 >> 8).to_i32).abs

          edge_sum += ::Math.sqrt(gx.to_f64 * gx + gy.to_f64 * gy)
          count += 1

          sx += step
        end
        sy += step
      end

      count > 0 ? edge_sum / count : 0.0
    end

    # Finds region balancing content importance with center proximity.
    #
    # Combines entropy scoring with distance from center, preferring
    # detailed regions near the image center.
    private def self.find_center_weighted_region(src : Image, target_width : Int32, target_height : Int32) : Rectangle
      bounds = src.bounds
      src_width = bounds.max.x - bounds.min.x
      src_height = bounds.max.y - bounds.min.y

      window_width = [target_width, src_width].min
      window_height = [target_height, src_height].min

      stride_x = [1, (src_width - window_width) // 15].max
      stride_y = [1, (src_height - window_height) // 15].max

      center_x = src_width // 2
      center_y = src_height // 2

      best_score = 0.0
      best_x = 0
      best_y = 0

      y = 0
      while y <= src_height - window_height
        x = 0
        while x <= src_width - window_width
          # Content score
          content_score = calculate_entropy_score(src, x, y, window_width, window_height)

          # Distance from center (normalized)
          window_center_x = x + window_width // 2
          window_center_y = y + window_height // 2
          dx = (window_center_x - center_x).abs.to_f64 / src_width
          dy = (window_center_y - center_y).abs.to_f64 / src_height
          distance = ::Math.sqrt(dx * dx + dy * dy)

          # Center weight (closer to center = higher score)
          center_weight = 1.0 - distance

          # Combined score (70% content, 30% center proximity)
          score = content_score * 0.7 + center_weight * content_score * 0.3

          if score > best_score
            best_score = score
            best_x = x
            best_y = y
          end

          x += stride_x
        end
        y += stride_y
      end

      CrImage.rect(best_x, best_y, best_x + window_width, best_y + window_height)
    end

    # Finds region likely to contain important subjects (faces, objects).
    #
    # Combines edge detection with upper-center weighting, as subjects
    # are typically positioned in the upper-center third of photos.
    private def self.find_attention_region(src : Image, target_width : Int32, target_height : Int32) : Rectangle
      # Combines edge detection with center weighting
      # Areas with high edge density in upper-center are likely to contain faces/subjects
      bounds = src.bounds
      src_width = bounds.max.x - bounds.min.x
      src_height = bounds.max.y - bounds.min.y

      window_width = [target_width, src_width].min
      window_height = [target_height, src_height].min

      stride_x = [1, (src_width - window_width) // 15].max
      stride_y = [1, (src_height - window_height) // 15].max

      # Attention is typically in upper-center third
      attention_y = src_height // 3

      best_score = 0.0
      best_x = 0
      best_y = 0

      y = 0
      while y <= src_height - window_height
        x = 0
        while x <= src_width - window_width
          edge_score = calculate_edge_score(src, x, y, window_width, window_height)

          # Vertical position weight (prefer upper-center)
          window_center_y = y + window_height // 2
          y_distance = (window_center_y - attention_y).abs.to_f64 / src_height
          y_weight = 1.0 - y_distance

          # Horizontal center weight
          window_center_x = x + window_width // 2
          center_x = src_width // 2
          x_distance = (window_center_x - center_x).abs.to_f64 / src_width
          x_weight = 1.0 - x_distance

          # Combined score
          score = edge_score * (0.5 + y_weight * 0.3 + x_weight * 0.2)

          if score > best_score
            best_score = score
            best_x = x
            best_y = y
          end

          x += stride_x
        end
        y += stride_y
      end

      CrImage.rect(best_x, best_y, best_x + window_width, best_y + window_height)
    end

    # Simple center crop as fallback.
    #
    # Returns a rectangle centered on the image.
    private def self.center_crop_rect(src_width : Int32, src_height : Int32, target_width : Int32, target_height : Int32) : Rectangle
      x = (src_width - target_width) // 2
      y = (src_height - target_height) // 2
      CrImage.rect(x, y, x + target_width, y + target_height)
    end
  end
end

module CrImage
  module Image
    # Performs smart crop to target dimensions.
    #
    # Convenience method that delegates to `Util::SmartCrop.crop`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # thumbnail = img.smart_crop(800, 600)
    # ```
    def smart_crop(width : Int32, height : Int32,
                   strategy : Util::CropStrategy = Util::CropStrategy::Entropy) : Image
      Util::SmartCrop.crop(self, width, height, strategy)
    end
  end
end
