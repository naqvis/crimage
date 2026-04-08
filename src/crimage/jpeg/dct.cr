# This file implements the Discrete Cosine Transform for JPEG encoding.
# The DCT converts spatial image data into frequency domain for compression.
module CrImage::JPEG
  # Forward Discrete Cosine Transform (DCT) implementation
  # Uses a separable 8x8 transform with precomputed coefficients.
  module DCT
    SCALE = [
      1.0 / ::Math.sqrt(8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
      ::Math.sqrt(2.0 / 8.0),
    ]

    BASIS = [
      [0.3535533905932738, 0.3535533905932738, 0.3535533905932738, 0.3535533905932738, 0.3535533905932738, 0.3535533905932738, 0.3535533905932738, 0.3535533905932738],
      [0.4903926402016152, 0.4157348061512726, 0.27778511650980114, 0.09754516100806417, -0.0975451610080641, -0.277785116509801, -0.4157348061512727, -0.4903926402016152],
      [0.46193976625564337, 0.19134171618254492, -0.19134171618254486, -0.46193976625564337, -0.4619397662556434, -0.19134171618254517, 0.191341716182545, 0.46193976625564326],
      [0.4157348061512726, -0.0975451610080641, -0.4903926402016152, -0.2777851165098011, 0.2777851165098009, 0.4903926402016153, 0.0975451610080644, -0.41573480615127256],
      [0.35355339059327384, -0.35355339059327373, -0.35355339059327384, 0.3535533905932737, 0.35355339059327384, -0.35355339059327334, -0.3535533905932733, 0.35355339059327323],
      [0.27778511650980114, -0.4903926402016152, 0.09754516100806415, 0.41573480615127273, -0.41573480615127256, -0.09754516100806429, 0.49039264020161516, -0.27778511650980076],
      [0.19134171618254495, -0.4619397662556434, 0.46193976625564326, -0.19134171618254528, -0.19134171618254495, 0.46193976625564315, -0.4619397662556437, 0.19134171618254314],
      [0.09754516100806417, -0.2777851165098011, 0.41573480615127273, -0.4903926402016153, 0.4903926402016152, -0.415734806151272, 0.27778511650980076, -0.09754516100806251],
    ]

    # Perform 2D DCT on an 8x8 block
    # Input: 64-element array of pixel values (0-255 range)
    # Output: 64-element array of DCT coefficients
    def self.transform(block : Array(Int32)) : Array(Int32)
      result = Array(Int32).new(64, 0)
      transform_into(block, result)
      result
    end

    def self.transform_into(block : Indexable(Int32), result : Array(Int32)) : Nil
      raise ArgumentError.new("Block must have 64 elements") unless block.size == 64
      raise ArgumentError.new("Result must have 64 elements") unless result.size == 64

      shifted = StaticArray(Float64, 64).new(0.0)
      temp = StaticArray(Float64, 64).new(0.0)

      64.times do |i|
        shifted[i] = (block[i] - 128).to_f64
      end

      8.times do |y|
        row_base = y * 8
        8.times do |u|
          sum = 0.0
          basis = BASIS[u]
          8.times do |x|
            sum += shifted[row_base + x] * basis[x]
          end
          temp[row_base + u] = sum
        end
      end

      8.times do |v|
        8.times do |u|
          sum = 0.0
          8.times do |y|
            sum += BASIS[v][y] * temp[y * 8 + u]
          end
          result[v * 8 + u] = sum.round.to_i32
        end
      end

      nil
    end
  end
end
