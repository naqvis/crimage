# This file implements the Discrete Cosine Transform for JPEG encoding.
# The DCT converts spatial image data into frequency domain for compression.
module CrImage::JPEG
  # Forward Discrete Cosine Transform (DCT) implementation
  # Uses direct formula for correctness
  # Operates on 8x8 blocks
  module DCT
    # Perform 2D DCT on an 8x8 block
    # Input: 64-element array of pixel values (0-255 range)
    # Output: 64-element array of DCT coefficients
    def self.transform(block : Array(Int32)) : Array(Int32)
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64

      # Create a working copy and shift values from [0, 255] to [-128, 127]
      temp = block.map { |val| (val - 128).to_f64 }

      # Apply 2D DCT
      result = Array(Float64).new(64, 0.0)

      8.times do |ver|
        8.times do |hor|
          sum = 0.0
          8.times do |ypos|
            8.times do |xpos|
              sum += temp[ypos * 8 + xpos] *
                     ::Math.cos((2 * xpos + 1) * hor * ::Math::PI / 16.0) *
                     ::Math.cos((2 * ypos + 1) * ver * ::Math::PI / 16.0)
            end
          end

          # Apply normalization: (2/N) * C(u) * C(v) where N=8
          cu = hor == 0 ? 1.0 / ::Math.sqrt(2.0) : 1.0
          cv = ver == 0 ? 1.0 / ::Math.sqrt(2.0) : 1.0
          result[ver * 8 + hor] = sum * 0.25 * cu * cv # 2/8 = 0.25
        end
      end

      result.map(&.round.to_i32)
    end
  end
end
