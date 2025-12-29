require "./bit_writer"
require "./huffman_encoder"
require "./transform_encoder"
require "../color/color"
require "../image/nrgba"

module CrImage::WEBP
  # Writer handles VP8L bitstream generation for WebP lossless encoding.
  #
  # Implements the VP8L lossless compression algorithm including:
  # - Transform encoding (predictor, subtract green, color, palette)
  # - LZ77 backward references
  # - Color cache
  # - Huffman encoding
  # - Bitstream formatting
  module Writer
    # Transform types
    TRANSFORM_PREDICT        = 0
    TRANSFORM_COLOR          = 1
    TRANSFORM_SUB_GREEN      = 2
    TRANSFORM_COLOR_INDEXING = 3

    # Distance map for nearby pixels (WebP specification)
    DISTANCE_MAP = [
      96, 73, 55, 39, 23, 13, 5, 1, 255, 255, 255, 255, 255, 255, 255, 255,
      101, 78, 58, 42, 26, 16, 8, 2, 0, 3, 9, 17, 27, 43, 59, 79,
      102, 86, 62, 46, 32, 20, 10, 6, 4, 7, 11, 21, 33, 47, 63, 87,
      105, 90, 70, 52, 37, 28, 18, 14, 12, 15, 19, 29, 38, 53, 71, 91,
      110, 99, 82, 66, 48, 35, 30, 24, 22, 25, 31, 36, 49, 67, 83, 100,
      115, 108, 94, 76, 64, 50, 44, 40, 34, 41, 45, 51, 65, 77, 95, 109,
      118, 113, 103, 92, 80, 68, 60, 56, 54, 57, 61, 69, 81, 93, 104, 114,
      119, 116, 111, 106, 97, 88, 84, 74, 72, 75, 85, 89, 98, 107, 112, 117,
    ]

    # Generates VP8L bitstream from NRGBA image.
    #
    # Applies transforms, encodes with LZ77 and Huffman coding, and
    # generates the complete VP8L bitstream.
    #
    # Returns: Tuple of {bitstream_data, has_alpha}
    def self.write_bitstream(img : CrImage::NRGBA) : {Bytes, Bool}
      writer = BitWriter.new

      # Write VP8L header
      write_vp8l_header(writer, img.bounds, !img.opaque?)

      # Flatten image to pixel array
      pixels = flatten_image(img)
      width = img.bounds.width
      height = img.bounds.height

      # Determine which transforms to apply
      # For now, we'll use a simple strategy
      is_indexed = false # We don't detect paletted images yet

      # Apply transforms
      if is_indexed
        # Color indexing transform
        writer.write_bits(1_u64, 1) # transform present
        writer.write_bits(TRANSFORM_COLOR_INDEXING.to_u64, 2)

        palette, pw = CrImage::WEBP::TransformEncoder.apply_palette(pixels, width, height)
        width = pw

        writer.write_bits((palette.size - 1).to_u64, 8)
        write_image_data(writer, palette, palette.size, 1, false, 4)
      end

      if !is_indexed
        # Subtract green transform
        writer.write_bits(1_u64, 1) # transform present
        writer.write_bits(TRANSFORM_SUB_GREEN.to_u64, 2)
        CrImage::WEBP::TransformEncoder.apply_subtract_green(pixels)
      end

      if !is_indexed
        # Predictor transform
        writer.write_bits(1_u64, 1) # transform present
        writer.write_bits(TRANSFORM_PREDICT.to_u64, 2)

        tile_bits, bw, bh, blocks = CrImage::WEBP::TransformEncoder.apply_predictor(pixels, width, height)
        writer.write_bits((tile_bits - 2).to_u64, 3)
        write_image_data(writer, blocks, bw, bh, false, 4)
      end

      # End of transforms
      writer.write_bits(0_u64, 1)

      # Write main image data
      write_image_data(writer, pixels, width, height, true, 4)

      # Align to byte boundary
      writer.align_byte

      # Add padding byte if length is odd
      data = writer.to_slice
      if data.size % 2 != 0
        padded = Bytes.new(data.size + 1)
        data.copy_to(padded)
        padded[data.size] = 0_u8
        data = padded
      end

      {data, !img.opaque?}
    end

    # Writes VP8L header (5 bytes).
    #
    # Format:
    # - Magic byte (0x2f)
    # - Width minus one (14 bits)
    # - Height minus one (14 bits)
    # - Alpha flag (1 bit)
    # - Version (3 bits, always 0)
    private def self.write_vp8l_header(writer : BitWriter, bounds : Rectangle, has_alpha : Bool) : Nil
      # Magic byte
      writer.write_bits(0x2f_u64, 8)

      # Width minus one (14 bits)
      writer.write_bits((bounds.width - 1).to_u64, 14)

      # Height minus one (14 bits)
      writer.write_bits((bounds.height - 1).to_u64, 14)

      # Alpha flag (1 bit)
      writer.write_bits(has_alpha ? 1_u64 : 0_u64, 1)

      # Version (3 bits) - always 0
      writer.write_bits(0_u64, 3)
    end

    # Flattens NRGBA image to 1D pixel array.
    #
    # Converts 2D image to row-major array for processing.
    private def self.flatten_image(img : CrImage::NRGBA) : Array(CrImage::Color::NRGBA)
      width = img.bounds.width
      height = img.bounds.height
      pixels = Array(CrImage::Color::NRGBA).new(width * height)

      height.times do |y|
        width.times do |x|
          pixels << img.nrgba_at(x + img.bounds.min.x, y + img.bounds.min.y)
        end
      end

      pixels
    end

    # Encodes image data with LZ77 and color cache.
    #
    # Applies LZ77 backward references to find repeated pixel sequences,
    # uses color cache for recently seen colors, and encodes literals
    # for unique pixels. Returns array of encoded symbols.
    def self.encode_image_data(pixels : Array(CrImage::Color::NRGBA), width : Int32, height : Int32, color_cache_bits : Int32) : Array(Int32)
      # Initialize data structures
      head = Array(Int32).new(1 << 14, 0)
      prev = Array(Int32).new(pixels.size, 0)
      cache = Array(CrImage::Color::NRGBA).new(1 << color_cache_bits, CrImage::Color::NRGBA.new(0_u8, 0_u8, 0_u8, 0_u8))
      encoded = Array(Int32).new(pixels.size * 4, 0)
      cnt = 0

      i = 0
      while i < pixels.size
        # Try LZ77 matching
        if i + 2 < pixels.size
          # Compute hash
          h = hash(pixels[i], 14)
          h ^= hash(pixels[i + 1], 14) &* 0x9e3779b9_u32
          h ^= hash(pixels[i + 2], 14) &* 0x85ebca6b_u32
          h = h % (1 << 14)

          cur = head[h] - 1
          prev[i] = head[h]
          head[h] = i + 1

          dis = 0
          streak = 0

          # Search for matches
          8.times do
            break if cur == -1 || i - cur >= (1 << 20) - 120

            l = 0
            while i + l < pixels.size && l < 4096
              break if pixels[i + l] != pixels[cur + l]
              l += 1
            end

            if l > streak
              streak = l
              dis = i - cur
            end

            cur = prev[cur] - 1
          end

          # Use match if it's at least 3 pixels long
          if streak >= 3
            # Update color cache for matched pixels
            streak.times do |j|
              h = hash(pixels[i + j], color_cache_bits).to_i32
              cache[h] = pixels[i + j]
            end

            # Compute distance code
            y = dis // width
            x = dis - y * width

            code = dis + 120
            if x <= 8 && y < 8
              code = DISTANCE_MAP[y * 16 + 8 - x] + 1
            elsif x > width - 8 && y < 7
              code = DISTANCE_MAP[(y + 1) * 16 + 8 + (width - x)] + 1
            end

            # Encode length
            s, l = prefix_encode_code(streak)
            encoded[cnt + 0] = s + 256
            encoded[cnt + 1] = l

            # Encode distance
            s, l = prefix_encode_code(code)
            encoded[cnt + 2] = s
            encoded[cnt + 3] = l
            cnt += 4

            i += streak
            next
          end
        end

        # Try color cache
        p = pixels[i]
        if color_cache_bits > 0
          h = hash(p, color_cache_bits)

          if i > 0 && cache[h] == p
            encoded[cnt] = h.to_i32 + 256 + 24
            cnt += 1
            i += 1
            next
          end

          cache[h] = p
        end

        # Encode as literal
        encoded[cnt + 0] = p.g.to_i32
        encoded[cnt + 1] = p.r.to_i32
        encoded[cnt + 2] = p.b.to_i32
        encoded[cnt + 3] = p.a.to_i32
        cnt += 4
        i += 1
      end

      encoded[0...cnt]
    end

    # Writes image data with Huffman encoding.
    #
    # Encodes pixels, builds Huffman codes, and writes the compressed
    # bitstream. Handles both main image data and transform metadata.
    private def self.write_image_data(writer : BitWriter, pixels : Array(CrImage::Color::NRGBA), width : Int32, height : Int32, is_recursive : Bool, color_cache_bits : Int32) : Nil
      # Write color cache metadata
      if color_cache_bits > 0
        writer.write_bits(1_u64, 1)
        writer.write_bits(color_cache_bits.to_u64, 4)
      else
        writer.write_bits(0_u64, 1)
      end

      # Write recursive flag for transform data
      if is_recursive
        writer.write_bits(0_u64, 1)
      end

      # Encode image data
      encoded = encode_image_data(pixels, width, height, color_cache_bits)

      # Compute histograms
      histos = compute_histograms(encoded, color_cache_bits)

      # Build and write Huffman codes
      codes = [] of Array(HuffmanCode)
      5.times do |i|
        c = HuffmanEncoder.build_codes(histos[i], 15)
        codes << c
        HuffmanEncoder.write_codes(writer, c)
      end

      # Write encoded symbols
      i = 0
      while i < encoded.size
        writer.write_code(codes[0][encoded[i]])

        if encoded[i] < 256
          # Literal pixel
          writer.write_code(codes[1][encoded[i + 1]])
          writer.write_code(codes[2][encoded[i + 2]])
          writer.write_code(codes[3][encoded[i + 3]])
          i += 4
        elsif encoded[i] < 256 + 24
          # LZ77 reference
          # Length extra bits
          cnt = prefix_encode_bits(encoded[i] - 256)
          writer.write_bits(encoded[i + 1].to_u64, cnt)

          # Distance code
          writer.write_code(codes[4][encoded[i + 2]])

          # Distance extra bits
          cnt = prefix_encode_bits(encoded[i + 2])
          writer.write_bits(encoded[i + 3].to_u64, cnt)
          i += 4
        else
          # Color cache entry
          i += 1
        end
      end
    end

    # Computes histograms for 5 alphabets.
    #
    # VP8L uses 5 separate Huffman alphabets:
    # - 0: Green/literals + length codes + cache codes
    # - 1: Red
    # - 2: Blue
    # - 3: Alpha
    # - 4: Distance codes
    def self.compute_histograms(encoded : Array(Int32), color_cache_bits : Int32) : Array(Array(Int32))
      cache_size = color_cache_bits > 0 ? (1 << color_cache_bits) : 0

      histos = [
        Array(Int32).new(256 + 24 + cache_size, 0),
        Array(Int32).new(256, 0),
        Array(Int32).new(256, 0),
        Array(Int32).new(256, 0),
        Array(Int32).new(40, 0),
      ]

      i = 0
      while i < encoded.size
        symbol = encoded[i]
        histos[0][symbol] += 1 if symbol < histos[0].size

        if symbol < 256
          histos[1][encoded[i + 1]] += 1 if encoded[i + 1] < histos[1].size
          histos[2][encoded[i + 2]] += 1 if encoded[i + 2] < histos[2].size
          histos[3][encoded[i + 3]] += 1 if encoded[i + 3] < histos[3].size
          i += 3
        elsif symbol < 256 + 24
          dist_code = encoded[i + 2]
          histos[4][dist_code] += 1 if dist_code < histos[4].size
          i += 3
        end

        i += 1
      end

      histos
    end

    # Hash function for color cache (WebP specification).
    #
    # Computes hash of ARGB color for color cache lookup.
    private def self.hash(c : CrImage::Color::NRGBA, shifts : Int32) : UInt32
      x = c.a.to_u32 << 24 | c.r.to_u32 << 16 | c.g.to_u32 << 8 | c.b.to_u32
      shift_amount = [shifts, 32].min
      return 0_u32 if shift_amount >= 32
      (x &* 0x1e35a7bd_u32) >> (32 - shift_amount)
    end

    # Prefix encodes a value (length or distance).
    #
    # WebP uses prefix coding for lengths and distances in LZ77 references.
    # Returns tuple of {prefix_code, extra_bits}.
    private def self.prefix_encode_code(n : Int32) : {Int32, Int32}
      return {[0, n - 1].max, 0} if n <= 5

      shift = 0
      rem = n - 1
      while rem > 3
        rem >>= 1
        shift += 1
      end

      if rem == 2
        return {2 + 2 * shift, n - (2 << shift) - 1}
      end

      {3 + 2 * shift, n - (3 << shift) - 1}
    end

    # Gets number of extra bits for a prefix code.
    #
    # Returns how many extra bits follow the prefix code.
    private def self.prefix_encode_bits(prefix : Int32) : Int32
      return 0 if prefix < 4
      (prefix - 2) >> 1
    end
  end
end
