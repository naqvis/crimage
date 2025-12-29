module CrImage::Color
  # LAB represents a color in the CIELAB color space.
  # L is lightness (0-100), A is green-red axis (-128 to 127), B is blue-yellow axis (-128 to 127).
  struct LAB
    include Color

    property l : Float64 # Lightness: 0-100
    property a : Float64 # Green-Red: -128 to 127
    property b : Float64 # Blue-Yellow: -128 to 127

    def initialize(@l, @a, @b)
    end

    def rgba : {UInt32, UInt32, UInt32, UInt32}
      to_rgba.rgba
    end

    def to_rgba : RGBA
      # Convert LAB to XYZ
      # Reference white point D65
      ref_x = 95.047
      ref_y = 100.000
      ref_z = 108.883

      fy = (@l + 16.0) / 116.0
      fx = @a / 500.0 + fy
      fz = fy - @b / 200.0

      # Inverse transformation
      xr = if fx ** 3 > 0.008856
             fx ** 3
           else
             (fx - 16.0 / 116.0) / 7.787
           end

      yr = if @l > 7.9996
             (((@l + 16.0) / 116.0) ** 3)
           else
             @l / 903.3
           end

      zr = if fz ** 3 > 0.008856
             fz ** 3
           else
             (fz - 16.0 / 116.0) / 7.787
           end

      x = ref_x * xr
      y = ref_y * yr
      z = ref_z * zr

      # Convert XYZ to RGB
      # Using sRGB transformation matrix
      x_norm = x / 100.0
      y_norm = y / 100.0
      z_norm = z / 100.0

      r_linear = x_norm * 3.2406 + y_norm * -1.5372 + z_norm * -0.4986
      g_linear = x_norm * -0.9689 + y_norm * 1.8758 + z_norm * 0.0415
      b_linear = x_norm * 0.0557 + y_norm * -0.2040 + z_norm * 1.0570

      # Apply gamma correction (sRGB)
      r_srgb = gamma_correct(r_linear)
      g_srgb = gamma_correct(g_linear)
      b_srgb = gamma_correct(b_linear)

      # Convert to 0-255 range and clamp
      r = (r_srgb * 255).round.clamp(0, 255).to_u8
      g = (g_srgb * 255).round.clamp(0, 255).to_u8
      b = (b_srgb * 255).round.clamp(0, 255).to_u8

      RGBA.new(r, g, b, 255_u8)
    end

    private def gamma_correct(value : Float64) : Float64
      if value > 0.0031308
        1.055 * (value ** (1.0 / 2.4)) - 0.055
      else
        12.92 * value
      end
    end

    def to_s(io : IO) : Nil
      io << "LAB(#{l},#{a},#{b})"
    end

    def_equals_and_hash @l, @a, @b
  end

  struct RGBA
    # Convert RGBA to LAB color space
    def to_lab : LAB
      # Convert RGB to linear RGB (inverse gamma correction)
      r_linear = inverse_gamma_correct(@r.to_f / 255.0)
      g_linear = inverse_gamma_correct(@g.to_f / 255.0)
      b_linear = inverse_gamma_correct(@b.to_f / 255.0)

      # Convert linear RGB to XYZ using sRGB transformation matrix
      x = r_linear * 0.4124 + g_linear * 0.3576 + b_linear * 0.1805
      y = r_linear * 0.2126 + g_linear * 0.7152 + b_linear * 0.0722
      z = r_linear * 0.0193 + g_linear * 0.1192 + b_linear * 0.9505

      # Normalize by reference white point D65
      x_norm = (x * 100.0) / 95.047
      y_norm = (y * 100.0) / 100.000
      z_norm = (z * 100.0) / 108.883

      # Apply LAB transformation
      fx = lab_transform(x_norm)
      fy = lab_transform(y_norm)
      fz = lab_transform(z_norm)

      l = 116.0 * fy - 16.0
      a = 500.0 * (fx - fy)
      b = 200.0 * (fy - fz)

      LAB.new(l, a, b)
    end

    private def inverse_gamma_correct(value : Float64) : Float64
      if value > 0.04045
        ((value + 0.055) / 1.055) ** 2.4
      else
        value / 12.92
      end
    end

    private def lab_transform(value : Float64) : Float64
      if value > 0.008856
        value ** (1.0 / 3.0)
      else
        (7.787 * value) + (16.0 / 116.0)
      end
    end
  end
end
