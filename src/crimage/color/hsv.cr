module CrImage::Color
  # HSV represents a color in the HSV (Hue, Saturation, Value) color space.
  # Hue is in degrees (0-360), Saturation and Value are in the range 0-1.
  struct HSV
    include Color

    property h : Float64 # Hue: 0-360 degrees
    property s : Float64 # Saturation: 0-1
    property v : Float64 # Value: 0-1

    def initialize(@h, @s, @v)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      to_rgba.rgba
    end

    def to_rgba : RGBA
      # Normalize hue to 0-360 range
      h_norm = @h % 360.0
      h_norm += 360.0 if h_norm < 0

      # Clamp s and v to 0-1
      s_clamped = @s.clamp(0.0, 1.0)
      v_clamped = @v.clamp(0.0, 1.0)

      c = v_clamped * s_clamped
      x = c * (1 - ((h_norm / 60.0) % 2 - 1).abs)
      m = v_clamped - c

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
      io << "HSV(#{h},#{s},#{v})"
    end

    def_equals_and_hash @h, @s, @v
  end

  struct RGBA
    # Convert RGBA to HSV color space (ignores alpha channel)
    def to_hsv : HSV
      # Handle fully transparent pixels
      return HSV.new(0.0, 0.0, 0.0) if @a == 0

      r_norm = @r.to_f / 255.0
      g_norm = @g.to_f / 255.0
      b_norm = @b.to_f / 255.0

      c_max = [r_norm, g_norm, b_norm].max
      c_min = [r_norm, g_norm, b_norm].min
      delta = c_max - c_min

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

      # Calculate saturation
      s = c_max == 0 ? 0.0 : delta / c_max

      # Value is just the max
      v = c_max

      HSV.new(h, s, v)
    end
  end
end
