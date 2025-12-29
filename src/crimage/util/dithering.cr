module CrImage::Util
  # Dithering algorithms for color quantization.
  #
  # Different algorithms produce different visual characteristics:
  # - `FloydSteinberg` : Most common, good balance of quality and speed
  # - `Atkinson` : Lighter, more artistic appearance (75% error diffusion)
  # - `Sierra` : High quality with wider error distribution
  # - `Burkes` : Similar to Sierra but slightly faster
  # - `Stucki` : Highest quality, widest error distribution
  # - `Ordered` : Fastest, uses Bayer matrix, creates regular patterns
  enum DitheringAlgorithm
    FloydSteinberg
    Atkinson
    Sierra
    Burkes
    Stucki
    Ordered
  end

  # Dithering algorithms for reducing color depth while maintaining visual quality.
  # Implements error diffusion and ordered dithering techniques.
  module Dithering
    # Applies dithering to convert an image to a limited palette.
    #
    # Dithering creates the illusion of more colors by distributing
    # quantization error to neighboring pixels.
    #
    # Parameters:
    # - `src` : The source image
    # - `palette` : Target color palette
    # - `algorithm` : Dithering algorithm to use (default: FloydSteinberg)
    #
    # Returns: A new `Paletted` image with dithering applied
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("photo.png")
    # palette = CrImage::Color::Palette.new([
    #   CrImage::Color::BLACK,
    #   CrImage::Color::WHITE,
    # ] of CrImage::Color::Color)
    # dithered = CrImage::Util::Dithering.apply(img, palette)
    # ```
    def self.apply(src : Image, palette : Color::Palette,
                   algorithm : DitheringAlgorithm = DitheringAlgorithm::FloydSteinberg) : Paletted
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      case algorithm
      when .ordered?
        apply_ordered(src, palette)
      else
        apply_error_diffusion(src, palette, algorithm)
      end
    end

    # Applies Floyd-Steinberg dithering (convenience method).
    #
    # Floyd-Steinberg is the most common error diffusion algorithm,
    # distributing error to 4 neighboring pixels.
    #
    # Example:
    # ```
    # dithered = CrImage::Util::Dithering.floyd_steinberg(img, palette)
    # ```
    def self.floyd_steinberg(src : Image, palette : Color::Palette) : Paletted
      apply(src, palette, DitheringAlgorithm::FloydSteinberg)
    end

    # Applies Atkinson dithering (convenience method).
    #
    # Atkinson dithering distributes error to 6 pixels but only uses
    # 75% of the error, creating a lighter, more artistic effect.
    #
    # Example:
    # ```
    # dithered = CrImage::Util::Dithering.atkinson(img, palette)
    # ```
    def self.atkinson(src : Image, palette : Color::Palette) : Paletted
      apply(src, palette, DitheringAlgorithm::Atkinson)
    end

    # Applies ordered (Bayer matrix) dithering (convenience method).
    #
    # Ordered dithering uses a threshold matrix, faster than error diffusion
    # but produces a more regular pattern.
    #
    # Example:
    # ```
    # dithered = CrImage::Util::Dithering.ordered(img, palette)
    # ```
    def self.ordered(src : Image, palette : Color::Palette) : Paletted
      apply(src, palette, DitheringAlgorithm::Ordered)
    end

    # Applies error diffusion dithering using the specified algorithm.
    #
    # Error diffusion distributes quantization error to neighboring pixels
    # according to algorithm-specific weights, creating smooth gradients.
    private def self.apply_error_diffusion(src : Image, palette : Color::Palette,
                                           algorithm : DitheringAlgorithm) : Paletted
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      # Create working buffer with error accumulation
      buffer = Array(Array(Float64)).new(height) do |y|
        Array(Float64).new(width * 3) do |i|
          x = i // 3
          channel = i % 3
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba
          case channel
          when 0 then (r >> 8).to_f
          when 1 then (g >> 8).to_f
          else        (b >> 8).to_f
          end
        end
      end

      dst = Paletted.new(CrImage.rect(0, 0, width, height), palette)

      # Get error diffusion matrix
      diffusion = get_diffusion_matrix(algorithm)

      height.times do |y|
        width.times do |x|
          # Get current pixel with accumulated error
          r = buffer[y][x * 3].clamp(0, 255)
          g = buffer[y][x * 3 + 1].clamp(0, 255)
          b = buffer[y][x * 3 + 2].clamp(0, 255)

          # Find closest palette color
          old_color = Color::RGBA.new(r.to_u8, g.to_u8, b.to_u8, 255_u8)
          index, new_color = find_closest_color(palette, old_color)

          dst.set_color_index(x, y, index.to_u8)

          # Calculate quantization error
          nr, ng, nb, _ = new_color.rgba
          err_r = r - (nr >> 8)
          err_g = g - (ng >> 8)
          err_b = b - (nb >> 8)

          # Distribute error to neighboring pixels
          diffusion.each do |dx, dy, weight|
            nx = x + dx
            ny = y + dy
            next if nx < 0 || nx >= width || ny < 0 || ny >= height

            buffer[ny][nx * 3] += err_r * weight
            buffer[ny][nx * 3 + 1] += err_g * weight
            buffer[ny][nx * 3 + 2] += err_b * weight
          end
        end
      end

      dst
    end

    # Applies ordered (Bayer matrix) dithering for fast, patterned results.
    #
    # Uses an 8x8 Bayer threshold matrix to create a regular dithering pattern.
    # Faster than error diffusion but produces more visible patterns.
    private def self.apply_ordered(src : Image, palette : Color::Palette) : Paletted
      src_bounds = src.bounds
      width = src_bounds.width
      height = src_bounds.height

      dst = Paletted.new(CrImage.rect(0, 0, width, height), palette)

      # 8x8 Bayer matrix
      bayer = [
        [0, 32, 8, 40, 2, 34, 10, 42],
        [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44, 4, 36, 14, 46, 6, 38],
        [60, 28, 52, 20, 62, 30, 54, 22],
        [3, 35, 11, 43, 1, 33, 9, 41],
        [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47, 7, 39, 13, 45, 5, 37],
        [63, 31, 55, 23, 61, 29, 53, 21],
      ]

      height.times do |y|
        width.times do |x|
          r, g, b, a = src.at(x + src_bounds.min.x, y + src_bounds.min.y).rgba

          # Apply threshold from Bayer matrix
          threshold = (bayer[y % 8][x % 8].to_f / 64.0 - 0.5) * 64.0

          tr = ((r >> 8) + threshold).clamp(0, 255).to_u8
          tg = ((g >> 8) + threshold).clamp(0, 255).to_u8
          tb = ((b >> 8) + threshold).clamp(0, 255).to_u8

          color = Color::RGBA.new(tr, tg, tb, 255_u8)
          index, _ = find_closest_color(palette, color)

          dst.set_color_index(x, y, index.to_u8)
        end
      end

      dst
    end

    # Returns error diffusion matrix for the specified algorithm.
    #
    # Each matrix defines how quantization error is distributed to neighboring
    # pixels. Format: Array of {dx, dy, weight} tuples where dx/dy are pixel
    # offsets and weight is the fraction of error to distribute.
    private def self.get_diffusion_matrix(algorithm : DitheringAlgorithm) : Array(Tuple(Int32, Int32, Float64))
      case algorithm
      when .floyd_steinberg?
        [
          {1, 0, 7.0 / 16.0},
          {-1, 1, 3.0 / 16.0},
          {0, 1, 5.0 / 16.0},
          {1, 1, 1.0 / 16.0},
        ]
      when .atkinson?
        [
          {1, 0, 1.0 / 8.0},
          {2, 0, 1.0 / 8.0},
          {-1, 1, 1.0 / 8.0},
          {0, 1, 1.0 / 8.0},
          {1, 1, 1.0 / 8.0},
          {0, 2, 1.0 / 8.0},
        ]
      when .sierra?
        [
          {1, 0, 5.0 / 32.0},
          {2, 0, 3.0 / 32.0},
          {-2, 1, 2.0 / 32.0},
          {-1, 1, 4.0 / 32.0},
          {0, 1, 5.0 / 32.0},
          {1, 1, 4.0 / 32.0},
          {2, 1, 2.0 / 32.0},
          {-1, 2, 2.0 / 32.0},
          {0, 2, 3.0 / 32.0},
          {1, 2, 2.0 / 32.0},
        ]
      when .burkes?
        [
          {1, 0, 8.0 / 32.0},
          {2, 0, 4.0 / 32.0},
          {-2, 1, 2.0 / 32.0},
          {-1, 1, 4.0 / 32.0},
          {0, 1, 8.0 / 32.0},
          {1, 1, 4.0 / 32.0},
          {2, 1, 2.0 / 32.0},
        ]
      when .stucki?
        [
          {1, 0, 8.0 / 42.0},
          {2, 0, 4.0 / 42.0},
          {-2, 1, 2.0 / 42.0},
          {-1, 1, 4.0 / 42.0},
          {0, 1, 8.0 / 42.0},
          {1, 1, 4.0 / 42.0},
          {2, 1, 2.0 / 42.0},
          {-2, 2, 1.0 / 42.0},
          {-1, 2, 2.0 / 42.0},
          {0, 2, 4.0 / 42.0},
          {1, 2, 2.0 / 42.0},
          {2, 2, 1.0 / 42.0},
        ]
      else
        [] of Tuple(Int32, Int32, Float64)
      end
    end

    # Finds the closest color in the palette using Euclidean distance in RGB space.
    #
    # Returns both the palette index and the actual color for efficient access.
    private def self.find_closest_color(palette : Color::Palette, color : Color::Color) : Tuple(Int32, Color::Color)
      r1, g1, b1, _ = color.rgba

      best_index = 0
      best_distance = Int32::MAX

      palette.each_with_index do |pal_color, i|
        r2, g2, b2, _ = pal_color.rgba

        # Euclidean distance in RGB space
        dr = (r1 >> 8).to_i32 - (r2 >> 8).to_i32
        dg = (g1 >> 8).to_i32 - (g2 >> 8).to_i32
        db = (b1 >> 8).to_i32 - (b2 >> 8).to_i32
        distance = dr * dr + dg * dg + db * db

        if distance < best_distance
          best_distance = distance
          best_index = i
        end
      end

      {best_index, palette[best_index]}
    end
  end
end
