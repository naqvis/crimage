module CrImage::WEBP::VP8L
  # VP8L Transform implementations
  abstract class Transform
    abstract def inverse(pix : Bytes, h : Int32) : Bytes
  end

  # Predictor transform
  class PredictorTransform < Transform
    @old_width : Int32
    @bits : UInt32
    @pix : Bytes

    def initialize(@old_width, @bits, @pix)
    end

    def inverse(pix : Bytes, h : Int32) : Bytes
      return pix if @old_width == 0 || h == 0

      # First pixel: mode 0 (opaque black)
      pix[3] = pix[3] &+ 0xff

      # First row: mode 1 (L - left)
      p = 4_i32
      mask = (1_i32 << @bits) - 1
      x = 1_i32
      while x < @old_width
        pix[p + 0] = pix[p + 0] &+ pix[p - 4]
        pix[p + 1] = pix[p + 1] &+ pix[p - 3]
        pix[p + 2] = pix[p + 2] &+ pix[p - 2]
        pix[p + 3] = pix[p + 3] &+ pix[p - 1]
        p += 4
        x += 1
      end

      top = 0_i32
      tiles_per_row = n_tiles(@old_width, @bits)

      y = 1_i32
      while y < h
        # First column: mode 2 (T - top)
        pix[p + 0] = pix[p + 0] &+ pix[top + 0]
        pix[p + 1] = pix[p + 1] &+ pix[top + 1]
        pix[p + 2] = pix[p + 2] &+ pix[top + 2]
        pix[p + 3] = pix[p + 3] &+ pix[top + 3]
        p += 4
        top += 4

        q = 4 * (y >> @bits) * tiles_per_row
        predictor_mode = @pix[q + 1] & 0x0f
        q += 4

        x = 1_i32
        while x < @old_width
          if (x & mask) == 0
            predictor_mode = @pix[q + 1] & 0x0f
            q += 4
          end

          case predictor_mode
          when 0 # Opaque black
            pix[p + 3] = pix[p + 3] &+ 0xff
          when 1 # L
            pix[p + 0] = pix[p + 0] &+ pix[p - 4]
            pix[p + 1] = pix[p + 1] &+ pix[p - 3]
            pix[p + 2] = pix[p + 2] &+ pix[p - 2]
            pix[p + 3] = pix[p + 3] &+ pix[p - 1]
          when 2 # T
            pix[p + 0] = pix[p + 0] &+ pix[top + 0]
            pix[p + 1] = pix[p + 1] &+ pix[top + 1]
            pix[p + 2] = pix[p + 2] &+ pix[top + 2]
            pix[p + 3] = pix[p + 3] &+ pix[top + 3]
          when 3 # TR
            pix[p + 0] = pix[p + 0] &+ pix[top + 4]
            pix[p + 1] = pix[p + 1] &+ pix[top + 5]
            pix[p + 2] = pix[p + 2] &+ pix[top + 6]
            pix[p + 3] = pix[p + 3] &+ pix[top + 7]
          when 4 # TL
            pix[p + 0] = pix[p + 0] &+ pix[top - 4]
            pix[p + 1] = pix[p + 1] &+ pix[top - 3]
            pix[p + 2] = pix[p + 2] &+ pix[top - 2]
            pix[p + 3] = pix[p + 3] &+ pix[top - 1]
          when 5 # Average2(Average2(L, TR), T)
            pix[p + 0] = pix[p + 0] &+ avg2(avg2(pix[p - 4], pix[top + 4]), pix[top + 0])
            pix[p + 1] = pix[p + 1] &+ avg2(avg2(pix[p - 3], pix[top + 5]), pix[top + 1])
            pix[p + 2] = pix[p + 2] &+ avg2(avg2(pix[p - 2], pix[top + 6]), pix[top + 2])
            pix[p + 3] = pix[p + 3] &+ avg2(avg2(pix[p - 1], pix[top + 7]), pix[top + 3])
          when 6 # Average2(L, TL)
            pix[p + 0] = pix[p + 0] &+ avg2(pix[p - 4], pix[top - 4])
            pix[p + 1] = pix[p + 1] &+ avg2(pix[p - 3], pix[top - 3])
            pix[p + 2] = pix[p + 2] &+ avg2(pix[p - 2], pix[top - 2])
            pix[p + 3] = pix[p + 3] &+ avg2(pix[p - 1], pix[top - 1])
          when 7 # Average2(L, T)
            pix[p + 0] = pix[p + 0] &+ avg2(pix[p - 4], pix[top + 0])
            pix[p + 1] = pix[p + 1] &+ avg2(pix[p - 3], pix[top + 1])
            pix[p + 2] = pix[p + 2] &+ avg2(pix[p - 2], pix[top + 2])
            pix[p + 3] = pix[p + 3] &+ avg2(pix[p - 1], pix[top + 3])
          when 8 # Average2(TL, T)
            pix[p + 0] = pix[p + 0] &+ avg2(pix[top - 4], pix[top + 0])
            pix[p + 1] = pix[p + 1] &+ avg2(pix[top - 3], pix[top + 1])
            pix[p + 2] = pix[p + 2] &+ avg2(pix[top - 2], pix[top + 2])
            pix[p + 3] = pix[p + 3] &+ avg2(pix[top - 1], pix[top + 3])
          when 9 # Average2(T, TR)
            pix[p + 0] = pix[p + 0] &+ avg2(pix[top + 0], pix[top + 4])
            pix[p + 1] = pix[p + 1] &+ avg2(pix[top + 1], pix[top + 5])
            pix[p + 2] = pix[p + 2] &+ avg2(pix[top + 2], pix[top + 6])
            pix[p + 3] = pix[p + 3] &+ avg2(pix[top + 3], pix[top + 7])
          when 10 # Average2(Average2(L, TL), Average2(T, TR))
            pix[p + 0] = pix[p + 0] &+ avg2(avg2(pix[p - 4], pix[top - 4]), avg2(pix[top + 0], pix[top + 4]))
            pix[p + 1] = pix[p + 1] &+ avg2(avg2(pix[p - 3], pix[top - 3]), avg2(pix[top + 1], pix[top + 5]))
            pix[p + 2] = pix[p + 2] &+ avg2(avg2(pix[p - 2], pix[top - 2]), avg2(pix[top + 2], pix[top + 6]))
            pix[p + 3] = pix[p + 3] &+ avg2(avg2(pix[p - 1], pix[top - 1]), avg2(pix[top + 3], pix[top + 7]))
          when 11 # Select(L, T, TL)
            l0 = pix[p - 4].to_i32
            l1 = pix[p - 3].to_i32
            l2 = pix[p - 2].to_i32
            l3 = pix[p - 1].to_i32
            c0 = pix[top - 4].to_i32
            c1 = pix[top - 3].to_i32
            c2 = pix[top - 2].to_i32
            c3 = pix[top - 1].to_i32
            t0 = pix[top + 0].to_i32
            t1 = pix[top + 1].to_i32
            t2 = pix[top + 2].to_i32
            t3 = pix[top + 3].to_i32
            l = (c0 - t0).abs + (c1 - t1).abs + (c2 - t2).abs + (c3 - t3).abs
            t = (c0 - l0).abs + (c1 - l1).abs + (c2 - l2).abs + (c3 - l3).abs
            if l < t
              pix[p + 0] = pix[p + 0] &+ l0.to_u8
              pix[p + 1] = pix[p + 1] &+ l1.to_u8
              pix[p + 2] = pix[p + 2] &+ l2.to_u8
              pix[p + 3] = pix[p + 3] &+ l3.to_u8
            else
              pix[p + 0] = pix[p + 0] &+ t0.to_u8
              pix[p + 1] = pix[p + 1] &+ t1.to_u8
              pix[p + 2] = pix[p + 2] &+ t2.to_u8
              pix[p + 3] = pix[p + 3] &+ t3.to_u8
            end
          when 12 # ClampAddSubtractFull(L, T, TL)
            pix[p + 0] = pix[p + 0] &+ clamp_add_subtract_full(pix[p - 4], pix[top + 0], pix[top - 4])
            pix[p + 1] = pix[p + 1] &+ clamp_add_subtract_full(pix[p - 3], pix[top + 1], pix[top - 3])
            pix[p + 2] = pix[p + 2] &+ clamp_add_subtract_full(pix[p - 2], pix[top + 2], pix[top - 2])
            pix[p + 3] = pix[p + 3] &+ clamp_add_subtract_full(pix[p - 1], pix[top + 3], pix[top - 1])
          when 13 # ClampAddSubtractHalf(Average2(L, T), TL)
            pix[p + 0] = pix[p + 0] &+ clamp_add_subtract_half(avg2(pix[p - 4], pix[top + 0]), pix[top - 4])
            pix[p + 1] = pix[p + 1] &+ clamp_add_subtract_half(avg2(pix[p - 3], pix[top + 1]), pix[top - 3])
            pix[p + 2] = pix[p + 2] &+ clamp_add_subtract_half(avg2(pix[p - 2], pix[top + 2]), pix[top - 2])
            pix[p + 3] = pix[p + 3] &+ clamp_add_subtract_half(avg2(pix[p - 1], pix[top + 3]), pix[top - 1])
          end

          p += 4
          top += 4
          x += 1
        end
        y += 1
      end

      pix
    end

    private def avg2(a : UInt8, b : UInt8) : UInt8
      ((a.to_i32 + b.to_i32) // 2).to_u8
    end

    private def clamp_add_subtract_full(a : UInt8, b : UInt8, c : UInt8) : UInt8
      x = a.to_i32 + b.to_i32 - c.to_i32
      return 0_u8 if x < 0
      return 255_u8 if x > 255
      x.to_u8
    end

    private def clamp_add_subtract_half(a : UInt8, b : UInt8) : UInt8
      x = a.to_i32 + (a.to_i32 - b.to_i32) // 2
      return 0_u8 if x < 0
      return 255_u8 if x > 255
      x.to_u8
    end

    private def n_tiles(size : Int32, bits : UInt32) : Int32
      VP8L.n_tiles(size, bits)
    end
  end

  # Cross-color transform
  class CrossColorTransform < Transform
    @old_width : Int32
    @bits : UInt32
    @pix : Bytes

    def initialize(@old_width, @bits, @pix)
    end

    def inverse(pix : Bytes, h : Int32) : Bytes
      green_to_red = 0_i32
      green_to_blue = 0_i32
      red_to_blue = 0_i32
      p = 0_i32
      mask = (1_i32 << @bits) - 1
      tiles_per_row = n_tiles(@old_width, @bits)

      0.upto(h - 1) do |y|
        q = 4 * (y >> @bits) * tiles_per_row

        0.upto(@old_width - 1) do |x|
          if (x & mask) == 0
            # Convert UInt8 to signed Int8 by reinterpreting the byte
            red_to_blue = to_signed_int8(@pix[q + 0])
            green_to_blue = to_signed_int8(@pix[q + 1])
            green_to_red = to_signed_int8(@pix[q + 2])
            q += 4
          end

          red = pix[p + 0]
          green = pix[p + 1]
          blue = pix[p + 2]

          # Apply cross-color transform corrections
          red &+= (((green_to_red * to_signed_int8(green)).to_u32! >> 5) & 0xFF).to_u8
          blue &+= (((green_to_blue * to_signed_int8(green)).to_u32! >> 5) & 0xFF).to_u8
          blue &+= (((red_to_blue * to_signed_int8(red)).to_u32! >> 5) & 0xFF).to_u8

          pix[p + 0] = red
          pix[p + 2] = blue
          p += 4
        end
      end

      pix
    end

    # Convert UInt8 to signed Int8 value (-128 to 127)
    private def to_signed_int8(b : UInt8) : Int32
      b >= 128 ? b.to_i32 - 256 : b.to_i32
    end

    private def n_tiles(size : Int32, bits : UInt32) : Int32
      VP8L.n_tiles(size, bits)
    end
  end

  # Subtract green transform
  class SubtractGreenTransform < Transform
    @old_width : Int32

    def initialize(@old_width)
    end

    def inverse(pix : Bytes, h : Int32) : Bytes
      p = 0
      while p < pix.size
        green = pix[p + 1]
        pix[p + 0] = pix[p + 0] &+ green
        pix[p + 2] = pix[p + 2] &+ green
        p += 4
      end
      pix
    end
  end

  # Color indexing transform
  class ColorIndexingTransform < Transform
    @old_width : Int32
    @bits : UInt32
    @pix : Bytes

    def initialize(@old_width, @bits, @pix)
    end

    def inverse(pix : Bytes, h : Int32) : Bytes
      if @bits == 0
        p = 0
        while p < pix.size
          i = 4 * pix[p + 1].to_u32
          pix[p + 0] = @pix[i + 0]
          pix[p + 1] = @pix[i + 1]
          pix[p + 2] = @pix[i + 2]
          pix[p + 3] = @pix[i + 3]
          p += 4
        end
        return pix
      end

      v_mask, x_mask, bits_per_pixel = case @bits
                                       when 1 then {0x0f_u32, 0x01_i32, 4_u32}
                                       when 2 then {0x03_u32, 0x03_i32, 2_u32}
                                       when 3 then {0x01_u32, 0x07_i32, 1_u32}
                                       else        {0_u32, 0_i32, 0_u32}
                                       end

      dst = Bytes.new(4 * @old_width * h)
      d, p, v = 0, 0, 0_u32

      0.upto(h - 1) do |y|
        0.upto(@old_width - 1) do |x|
          if (x & x_mask) == 0
            v = pix[p + 1].to_u32
            p += 4
          end

          i = 4 * (v & v_mask)
          dst[d + 0] = @pix[i + 0]
          dst[d + 1] = @pix[i + 1]
          dst[d + 2] = @pix[i + 2]
          dst[d + 3] = @pix[i + 3]
          d += 4

          v >>= bits_per_pixel
        end
      end

      dst
    end
  end
end
