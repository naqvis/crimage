# This file implements the Inverse Discrete Cosine Transform for JPEG decoding.
# The IDCT converts frequency domain data back to spatial image data.

module CrImage::JPEG
  # Inverse Discrete Cosine Transform (IDCT) implementation.
  # Uses a fixed-point butterfly algorithm instead of the direct cosine formula.
  module IDCT
    COS1_18          = 257107
    SIN1_18          =  51142
    COS3_18          = 217965
    SIN3_18          = 145639
    SQRT2INV_COS6_18 =  70936
    SQRT2INV_SIN6_18 = 171254

    COS1_12          =  4017
    SIN1_12          =   799
    COS3_12          =  3406
    SIN3_12          =  2276
    SQRT2INV_14      = 11585
    SQRT2INV_COS6_12 =  1108
    SQRT2INV_SIN6_12 =  2676

    # Perform 2D IDCT on an 8x8 block
    # Input: 64-element array of DCT coefficients
    # Output: 64-element array of pixel values
    def self.transform(block : Indexable(Int32)) : Array(Int32)
      output = Array(Int32).new(64, 0)
      transform_into(block, output)
      output
    end

    @[AlwaysInline]
    def self.transform_pixels_into(block : Indexable(Int32), work : Array(Int32) | Slice(Int32), output : Bytes) : Nil
      raise ArgumentError.new("Output must have 64 elements") unless output.size == 64
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64
      raise ArgumentError.new("Work must have 64 elements") unless work.size == 64

      64.times do |i|
        work[i] = block[i]
      end

      idct_rows(work)
      idct_cols(work)
      write_clamped_pixels(work, output)
    end

    def self.transform_into(block : Indexable(Int32), output : Array(Int32) | Slice(Int32)) : Nil
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64
      raise ArgumentError.new("Output must have 64 elements") unless output.size == 64

      64.times do |i|
        output[i] = block[i]
      end

      idct_rows(output)
      idct_cols(output)

      clamp_pixels(output)
    end

    def self.transform_dequantize_into(block : Indexable(Int32), quant : Indexable(UInt16), output : Array(Int32) | Slice(Int32)) : Nil
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64
      raise ArgumentError.new("Quant table must have 64 elements") unless quant.size == 64
      raise ArgumentError.new("Output must have 64 elements") unless output.size == 64

      64.times do |i|
        output[i] = block[i] &* quant[i].to_i32
      end

      idct_rows(output)
      idct_cols(output)

      clamp_pixels(output)
    end

    @[AlwaysInline]
    def self.transform_dequantize_pixels_into(block : Indexable(Int32), quant : Indexable(UInt16),
                                              work : Array(Int32) | Slice(Int32), output : Bytes) : Nil
      raise ArgumentError.new("Output must have 64 elements") unless output.size == 64
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64
      raise ArgumentError.new("Quant table must have 64 elements") unless quant.size == 64
      raise ArgumentError.new("Work must have 64 elements") unless work.size == 64

      64.times do |i|
        work[i] = block[i] &* quant[i].to_i32
      end

      idct_rows(work)
      idct_cols(work)
      write_clamped_pixels(work, output)
    end

    private def self.clamp_pixels(output : Array(Int32) | Slice(Int32)) : Nil
      64.times do |i|
        pixel = ((output[i] + 4) >> 3) + 128
        output[i] = pixel.clamp(0, 255)
      end
    end

    private def self.write_pixels(input : Array(Int32) | Slice(Int32), output : Bytes) : Nil
      64.times do |i|
        output[i] = input[i].to_u8
      end
    end

    @[AlwaysInline]
    private def self.write_clamped_pixels(input : Array(Int32) | Slice(Int32), output : Bytes) : Nil
      8.times do |row|
        base = row * 8

        pixel = ((input[base] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base] = pixel.to_u8

        pixel = ((input[base + 1] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 1] = pixel.to_u8

        pixel = ((input[base + 2] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 2] = pixel.to_u8

        pixel = ((input[base + 3] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 3] = pixel.to_u8

        pixel = ((input[base + 4] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 4] = pixel.to_u8

        pixel = ((input[base + 5] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 5] = pixel.to_u8

        pixel = ((input[base + 6] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 6] = pixel.to_u8

        pixel = ((input[base + 7] + 4) >> 3) + 128
        pixel = 0 if pixel < 0
        pixel = 255 if pixel > 255
        output[base + 7] = pixel.to_u8
      end
    end

    @[AlwaysInline]
    private def self.dct_box(x0 : Int32, x1 : Int32, kcos : Int32, ksin : Int32) : {Int32, Int32}
      ksum = kcos &* (x0 &+ x1)
      y0 = ksum &+ ((ksin &- kcos) &* x1)
      y1 = ksum &- ((kcos &+ ksin) &* x0)
      {y0, y1}
    end

    @[AlwaysInline]
    private def self.idct_rows(block : Array(Int32) | Slice(Int32)) : Nil
      8.times do |row|
        base = row * 8

        x0 = block[base]
        x7 = block[base + 1]
        x2 = block[base + 2]
        x5 = block[base + 3]
        x1 = block[base + 4]
        x6 = block[base + 5]
        x3 = block[base + 6]
        x4 = block[base + 7]

        if x7 == 0 && x2 == 0 && x5 == 0 && x1 == 0 && x6 == 0 && x3 == 0 && x4 == 0
          dc = x0 << 20
          8.times do |i|
            block[base + i] = dc
          end
          next
        end

        x0 <<= 17
        x1 <<= 17
        x0, x1 = x0 &+ x1, x0 &- x1

        x2, x3 = dct_box(x2, x3, SQRT2INV_COS6_18, -SQRT2INV_SIN6_18)
        x1, x2 = x1 &+ x2, x1 &- x2
        x0, x3 = x0 &+ x3, x0 &- x3

        x4 <<= 7
        x7 <<= 7
        x7, x4 = x7 &+ x4, x7 &- x4

        x6 = x6 &* SQRT2INV_14
        x5 = x5 &* SQRT2INV_14

        x7, x5 = x7 &+ x5, x7 &- x5
        x4, x6 = x4 &+ x6, x4 &- x6

        x4, x7 = dct_box(x4 >> 2, x7 >> 2, COS3_12, -SIN3_12)
        x5, x6 = dct_box(x5 >> 2, x6 >> 2, COS1_12, -SIN1_12)

        x0, x7 = x0 &+ x7, x0 &- x7
        x1, x6 = x1 &+ x6, x1 &- x6
        x2, x5 = x2 &+ x5, x2 &- x5
        x3, x4 = x3 &+ x4, x3 &- x4

        block[base] = x0
        block[base + 1] = x1
        block[base + 2] = x2
        block[base + 3] = x3
        block[base + 4] = x4
        block[base + 5] = x5
        block[base + 6] = x6
        block[base + 7] = x7
      end
    end

    @[AlwaysInline]
    private def self.idct_cols(block : Array(Int32) | Slice(Int32)) : Nil
      8.times do |col|
        x0 = block[col]
        x7 = block[8 + col]
        x2 = block[16 + col]
        x5 = block[24 + col]
        x1 = block[32 + col]
        x6 = block[40 + col]
        x3 = block[48 + col]
        x4 = block[56 + col]

        if x7 == 0 && x2 == 0 && x5 == 0 && x1 == 0 && x6 == 0 && x3 == 0 && x4 == 0
          dc = (x0 + (1 << 19)) >> 18
          8.times do |i|
            block[i * 8 + col] = dc
          end
          next
        end

        x0 += 1 << 19

        x0, x1 = (x0 &+ x1) >> 2, (x0 &- x1) >> 2
        x2, x3 = dct_box(x2 >> 13, x3 >> 13, SQRT2INV_COS6_12, -SQRT2INV_SIN6_12)
        x1, x2 = x1 &+ x2, x1 &- x2
        x0, x3 = x0 &+ x3, x0 &- x3

        x7, x4 = x7 &+ x4, x7 &- x4
        x5 = (x5 >> 13) &* SQRT2INV_14
        x6 = (x6 >> 13) &* SQRT2INV_14
        x7, x5 = x7 &+ x5, x7 &- x5
        x4, x6 = x4 &+ x6, x4 &- x6
        x4, x7 = dct_box(x4 >> 14, x7 >> 14, COS3_12, -SIN3_12)
        x5, x6 = dct_box(x5 >> 14, x6 >> 14, COS1_12, -SIN1_12)

        x0, x7 = x0 &+ x7, x0 &- x7
        x1, x6 = x1 &+ x6, x1 &- x6
        x2, x5 = x2 &+ x5, x2 &- x5
        x3, x4 = x3 &+ x4, x3 &- x4

        block[col] = x0 >> 18
        block[8 + col] = x1 >> 18
        block[16 + col] = x2 >> 18
        block[24 + col] = x3 >> 18
        block[32 + col] = x4 >> 18
        block[40 + col] = x5 >> 18
        block[48 + col] = x6 >> 18
        block[56 + col] = x7 >> 18
      end
    end
  end
end
