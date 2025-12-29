module CrImage::Util
  # Noise types for generation and addition.
  #
  # Different noise types produce different visual characteristics:
  # - `Uniform` : Random noise with uniform distribution (-1 to 1)
  # - `Gaussian` : Normal distribution noise, most natural-looking
  # - `SaltAndPepper` : Random black and white pixels, simulates sensor noise
  # - `Perlin` : Smooth, coherent noise for natural textures
  enum NoiseType
    Uniform
    Gaussian
    SaltAndPepper
    Perlin
  end

  # Noise generation and addition for textures and effects.
  #
  # Provides tools for adding various types of noise to images, useful for:
  # - Creating film grain effects
  # - Simulating analog photography
  # - Adding texture to flat areas
  # - Testing image processing algorithms
  # - Generating procedural textures
  module Noise
    # Adds noise to an image for film grain or texture effects.
    #
    # Applies random noise to each pixel based on the specified algorithm.
    # The amount parameter controls intensity, and monochrome determines
    # whether the same noise is applied to all channels or different noise
    # per channel.
    #
    # Parameters:
    # - `src` : The source image
    # - `amount` : Noise intensity (0.0 = none, 1.0 = maximum, default: 0.1)
    # - `noise_type` : Type of noise algorithm (default: Gaussian)
    # - `monochrome` : Use same noise for all channels (default: false)
    #
    # Returns: A new RGBA image with noise applied
    #
    # Raises: `ArgumentError` if amount is outside 0.0-1.0 range
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # grainy = img.add_noise(0.1, NoiseType::Gaussian)
    # ```
    def self.add_noise(src : Image, amount : Float64 = 0.1,
                       noise_type : NoiseType = NoiseType::Gaussian,
                       monochrome : Bool = false) : RGBA
      raise ArgumentError.new("amount must be between 0.0 and 1.0") unless amount >= 0.0 && amount <= 1.0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      result = CrImage.rgba(src_width, src_height, Color::TRANSPARENT)

      # Copy and add noise
      src_height.times do |y|
        src_width.times do |x|
          pixel = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
          r, g, b, a = pixel.rgba

          # Generate noise
          noise_value = case noise_type
                        when .uniform?
                          generate_uniform_noise
                        when .gaussian?
                          generate_gaussian_noise
                        when .salt_and_pepper?
                          generate_salt_pepper_noise
                        when .perlin?
                          generate_perlin_noise(x, y)
                        else
                          0.0
                        end

          # Apply noise
          if monochrome
            # Same noise for all channels
            noise_offset = (noise_value * amount * 255).to_i32
            new_r = ((r >> 8).to_i32 + noise_offset).clamp(0, 255)
            new_g = ((g >> 8).to_i32 + noise_offset).clamp(0, 255)
            new_b = ((b >> 8).to_i32 + noise_offset).clamp(0, 255)
          else
            # Different noise per channel
            noise_r = (generate_noise(noise_type, x, y) * amount * 255).to_i32
            noise_g = (generate_noise(noise_type, x + 1, y) * amount * 255).to_i32
            noise_b = (generate_noise(noise_type, x, y + 1) * amount * 255).to_i32

            new_r = ((r >> 8).to_i32 + noise_r).clamp(0, 255)
            new_g = ((g >> 8).to_i32 + noise_g).clamp(0, 255)
            new_b = ((b >> 8).to_i32 + noise_b).clamp(0, 255)
          end

          result.set(x, y, Color.rgba(new_r.to_u8, new_g.to_u8, new_b.to_u8, (a >> 8).to_u8))
        end
      end

      result
    end

    # Generates a noise texture image.
    #
    # Creates an image filled entirely with noise pattern. Useful for creating
    # procedural textures, backgrounds, and overlay effects. The scale parameter
    # affects Perlin noise frequency.
    #
    # Parameters:
    # - `width` : Width of generated image (must be positive)
    # - `height` : Height of generated image (must be positive)
    # - `noise_type` : Type of noise to generate (default: Gaussian)
    # - `scale` : Scale factor for Perlin noise frequency (default: 1.0)
    #
    # Returns: A new RGBA image filled with noise
    #
    # Raises: `ArgumentError` if dimensions or scale are invalid
    #
    # Example:
    # ```
    # noise_texture = CrImage.generate_noise(800, 600, NoiseType::Perlin)
    # ```
    def self.generate_noise_texture(width : Int32, height : Int32,
                                    noise_type : NoiseType = NoiseType::Gaussian,
                                    scale : Float64 = 1.0) : RGBA
      raise ArgumentError.new("width must be positive") if width <= 0
      raise ArgumentError.new("height must be positive") if height <= 0
      raise ArgumentError.new("scale must be positive") if scale <= 0.0

      result = CrImage.rgba(width, height, Color::TRANSPARENT)

      height.times do |y|
        width.times do |x|
          noise_value = case noise_type
                        when .perlin?
                          # Scale coordinates for Perlin noise
                          scaled_x = x.to_f64 * scale / 50.0
                          scaled_y = y.to_f64 * scale / 50.0
                          (generate_perlin_noise(scaled_x.to_i32, scaled_y.to_i32) + 1.0) / 2.0
                        else
                          (generate_noise(noise_type, x, y) + 1.0) / 2.0
                        end

          intensity = (noise_value * 255).clamp(0, 255).to_i32
          result.set(x, y, Color.rgb(intensity.to_u8, intensity.to_u8, intensity.to_u8))
        end
      end

      result
    end

    # Generates uniform random noise with equal probability across range.
    #
    # Returns: Random value between -1.0 and 1.0
    private def self.generate_uniform_noise : Float64
      Random.rand * 2.0 - 1.0
    end

    # Generates Gaussian (normal distribution) noise using Box-Muller transform.
    #
    # Produces noise with bell curve distribution, most values near zero.
    # Clamped to ±3 standard deviations for stability.
    #
    # Returns: Random value between -1.0 and 1.0 (Gaussian distribution)
    private def self.generate_gaussian_noise : Float64
      u1 = Random.rand
      u2 = Random.rand

      # Box-Muller transform
      magnitude = ::Math.sqrt(-2.0 * ::Math.log(u1))
      z0 = magnitude * ::Math.cos(2.0 * ::Math::PI * u2)

      # Clamp to reasonable range
      z0.clamp(-3.0, 3.0) / 3.0
    end

    # Generates salt and pepper noise (random black or white pixels).
    #
    # 5% chance of black (-1.0), 5% chance of white (1.0), 90% no noise (0.0).
    # Simulates sensor defects and transmission errors.
    #
    # Returns: -1.0 (pepper), 1.0 (salt), or 0.0 (no noise)
    private def self.generate_salt_pepper_noise : Float64
      rand_val = Random.rand
      if rand_val < 0.05
        -1.0 # Pepper (black)
      elsif rand_val > 0.95
        1.0 # Salt (white)
      else
        0.0 # No noise
      end
    end

    # Generates simplified Perlin-like noise for smooth, natural patterns.
    #
    # Uses hash-based pseudo-random function for coherent noise. This is a
    # simplified version optimized for performance rather than true Perlin noise.
    #
    # Returns: Pseudo-random value between -1.0 and 1.0 based on coordinates
    private def self.generate_perlin_noise(x : Int32, y : Int32) : Float64
      # Simple hash-based noise - safe version
      # Use modulo to prevent overflow
      n = (x.abs % 10000 + y.abs % 10000 * 57) % 100000

      # Simple pseudo-random function using wrapping multiplication
      n = n.to_u32 &* 2654435761_u32

      # Normalize to -1.0 to 1.0
      value = (n.to_f64 / 2147483648.0) - 1.0
      value
    end

    # Generates noise value based on the specified type and coordinates.
    #
    # Dispatches to the appropriate noise generation function.
    private def self.generate_noise(noise_type : NoiseType, x : Int32, y : Int32) : Float64
      case noise_type
      when .uniform?
        generate_uniform_noise
      when .gaussian?
        generate_gaussian_noise
      when .salt_and_pepper?
        generate_salt_pepper_noise
      when .perlin?
        generate_perlin_noise(x, y)
      else
        0.0
      end
    end
  end
end

module CrImage
  module Image
    # Adds noise to the image.
    #
    # Convenience method that delegates to `Util::Noise.add_noise`.
    #
    # Example:
    # ```
    # img = CrImage.read("photo.jpg")
    # grainy = img.add_noise(0.1)
    # ```
    def add_noise(amount : Float64 = 0.1,
                  noise_type : Util::NoiseType = Util::NoiseType::Gaussian,
                  monochrome : Bool = false) : RGBA
      Util::Noise.add_noise(self, amount, noise_type, monochrome)
    end
  end

  # Generates a noise texture image.
  #
  # Convenience method that delegates to `Util::Noise.generate_noise_texture`.
  #
  # Example:
  # ```
  # noise = CrImage.generate_noise(800, 600)
  # ```
  def self.generate_noise(width : Int32, height : Int32,
                          noise_type : Util::NoiseType = Util::NoiseType::Gaussian,
                          scale : Float64 = 1.0) : RGBA
    Util::Noise.generate_noise_texture(width, height, noise_type, scale)
  end
end
