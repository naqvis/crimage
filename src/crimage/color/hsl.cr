module CrImage::Color
  # HSL represents a color in the HSL (Hue, Saturation, Lightness) color space.
  # Hue is in degrees (0-360), Saturation and Lightness are in the range 0-1.
  struct HSL
    include Color

    property h : Float64 # Hue: 0-360 degrees
    property s : Float64 # Saturation: 0-1
    property l : Float64 # Lightness: 0-1

    def initialize(@h, @s, @l)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      to_rgba.rgba
    end

    def to_rgba : RGBA
      # Normalize hue to 0-360 range
      h_norm = @h % 360.0
      h_norm += 360.0 if h_norm < 0

      # Clamp s and l to 0-1
      s_clamped = @s.clamp(0.0, 1.0)
      l_clamped = @l.clamp(0.0, 1.0)

      c = (1 - (2 * l_clamped - 1).abs) * s_clamped
      x = c * (1 - ((h_norm / 60.0) % 2 - 1).abs)
      m = l_clamped - c / 2.0

      r_prime, g_prime, b_prime = case h_norm
                                  when 0...60
                                    {c, x, 0.0}
                                  when 60...120
                                    {x, c, 0.0}
                                  when 120...180
                                    {0.0, c, x}
                                  when 180...240
                                    {0.0, x, c}
                                  when 240...300
                                    {x, 0.0, c}
                                  else # 300...360
                                    {c, 0.0, x}
                                  end

      r = ((r_prime + m) * 255).round.to_u8
      g = ((g_prime + m) * 255).round.to_u8
      b = ((b_prime + m) * 255).round.to_u8

      RGBA.new(r, g, b, 255_u8)
    end

    def to_s(io : IO) : Nil
      io << "HSL(#{h},#{s},#{l})"
    end

    def_equals_and_hash @h, @s, @l
  end

  struct RGBA
    # Convert RGBA to HSL color space (ignores alpha channel)
    def to_hsl : HSL
      # Handle fully transparent pixels
      return HSL.new(0.0, 0.0, 0.0) if @a == 0

      r_norm = @r.to_f / 255.0
      g_norm = @g.to_f / 255.0
      b_norm = @b.to_f / 255.0

      c_max = [r_norm, g_norm, b_norm].max
      c_min = [r_norm, g_norm, b_norm].min
      delta = c_max - c_min

      # Calculate lightness
      l = (c_max + c_min) / 2.0

      # Calculate saturation
      s = if delta == 0
            0.0
          else
            delta / (1 - (2 * l - 1).abs)
          end

      # Clamp saturation to avoid floating point errors
      s = s.clamp(0.0, 1.0)

      # Calculate hue
      h = if delta == 0
            0.0
          elsif c_max == r_norm
            60.0 * (((g_norm - b_norm) / delta) % 6)
          elsif c_max == g_norm
            60.0 * (((b_norm - r_norm) / delta) + 2)
          else # c_max == b_norm
            60.0 * (((r_norm - g_norm) / delta) + 4)
          end

      # Normalize hue to 0-360
      h += 360.0 if h < 0

      HSL.new(h, s, l)
    end
  end
end
