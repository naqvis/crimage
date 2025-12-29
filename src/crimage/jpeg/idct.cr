# This file implements the Inverse Discrete Cosine Transform for JPEG decoding.
# The IDCT converts frequency domain data back to spatial image data.

module CrImage::JPEG
  # Inverse Discrete Cosine Transform (IDCT) implementation
  # Uses direct formula for correctness
  # Operates on 8x8 blocks
  module IDCT
    # Perform 2D IDCT on an 8x8 block
    # Input: 64-element array of DCT coefficients
    # Output: 64-element array of pixel values
    def self.transform(block : Array(Int32)) : Array(Int32)
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64

      # Apply 2D IDCT
      result = Array(Float64).new(64, 0.0)

      8.times do |y|
        8.times do |x|
          sum = 0.0
          8.times do |ver|
            8.times do |hor|
              cu = hor == 0 ? 1.0 / ::Math.sqrt(2.0) : 1.0
              cv = ver == 0 ? 1.0 / ::Math.sqrt(2.0) : 1.0

              sum += cu * cv * block[ver * 8 + hor] *
                     ::Math.cos((2 * x + 1) * hor * ::Math::PI / 16.0) *
                     ::Math.cos((2 * y + 1) * ver * ::Math::PI / 16.0)
            end
          end

          # Apply normalization: (2/N) where N=8
          result[y * 8 + x] = sum * 0.25 # 2/8 = 0.25
        end
      end

      # Shift and clamp values to 0-255 range
      result.map do |val|
        pixel = val.round.to_i32 + 128
        pixel.clamp(0, 255)
      end
    end
  end
end
