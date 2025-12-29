module CrImage::WEBP::VP8L
  # VP8L Decoder implementation
  class Decoder
    @reader : BitReader
    @width : Int32
    @height : Int32
    @original_width : Int32

    def initialize(io : IO)
      @reader = BitReader.new(io)
      @width = 0
      @height = 0
      @original_width = 0
    end

    def decode : CrImage::Image
      # Read header
      magic = @reader.read(8)
      raise FormatError.new("Invalid VP8L header") unless magic == 0x2f

      @width = (@reader.read(14) + 1).to_i32
      @height = (@reader.read(14) + 1).to_i32

      @reader.read(1) # alpha hint
      version = @reader.read(3)
      raise FormatError.new("Invalid VP8L version") unless version == 0

      # Store original width before transforms modify it
      @original_width = @width

      # Decode transforms
      transforms = [] of Transform
      loop do
        more = @reader.read(1)
        break if more == 0

        t, new_width = decode_transform(@width, @height)
        transforms << t
        @width = new_width
      end

      # Decode transformed pixel data
      pix = decode_pix(@width, @height, 0, true)

      # Apply inverse transforms in reverse order
      (transforms.size - 1).downto(0) do |i|
        pix = transforms[i].inverse(pix, @height)
      end

      CrImage::NRGBA.new(
        pix,
        4 * @original_width,
        CrImage.rect(0, 0, @original_width, @height)
      )
    end

    private def decode_transform(w : Int32, h : Int32) : Tuple(Transform, Int32)
      old_width = w
      transform_type = @reader.read(2)

      case transform_type
      when 0 # Predictor
        bits = @reader.read(3) + 2
        pix = decode_pix(n_tiles(w, bits), n_tiles(h, bits), 0, false)
        {PredictorTransform.new(old_width, bits, pix), w}
      when 1 # Cross-color
        bits = @reader.read(3) + 2
        pix = decode_pix(n_tiles(w, bits), n_tiles(h, bits), 0, false)
        {CrossColorTransform.new(old_width, bits, pix), w}
      when 2 # Subtract green
        {SubtractGreenTransform.new(old_width), w}
      when 3 # Color indexing
        n_colors = @reader.read(8) + 1
        bits = case
               when n_colors <= 2  then 3_u32
               when n_colors <= 4  then 2_u32
               when n_colors <= 16 then 1_u32
               else                     0_u32
               end
        new_w = n_tiles(w, bits)
        pix = decode_pix(n_colors.to_i32, 1, 4 * 256, false)

        # Accumulate palette colors
        p = 4
        while p < pix.size
          pix[p + 0] = pix[p + 0] &+ pix[p - 4]
          pix[p + 1] = pix[p + 1] &+ pix[p - 3]
          pix[p + 2] = pix[p + 2] &+ pix[p - 2]
          pix[p + 3] = pix[p + 3] &+ pix[p - 1]
          p += 4
        end

        # Extend to 256 colors (spec says to use transparent black for missing indices)
        palette = Bytes.new(4 * 256, 0_u8)
        pix.each_with_index { |b, i| palette[i] = b }
        {ColorIndexingTransform.new(old_width, bits, palette), new_w}
      else
        raise FormatError.new("Invalid transform type")
      end
    end

    private def decode_pix(w : Int32, h : Int32, min_cap : Int32, top_level : Bool) : Bytes
      # Decode color cache parameters
      cc_bits, cc_shift, cc_entries = 0_u32, 0_u32, nil.as(Array(UInt32)?)
      use_color_cache = @reader.read(1)
      if use_color_cache != 0
        cc_bits = @reader.read(4)
        raise FormatError.new("vp8l: invalid color cache parameters") if cc_bits < 1 || cc_bits > 11
        cc_shift = 32 - cc_bits
        cc_entries = Array(UInt32).new(1 << cc_bits, 0_u32)
      end

      # Decode Huffman groups
      h_groups, h_pix, h_bits = decode_huffman_groups(w, h, top_level, cc_bits)
      h_mask, tiles_per_row = 0_i32, 0_i32
      if h_bits != 0
        h_mask = (1_i32 << h_bits) - 1
        tiles_per_row = n_tiles(w, h_bits)
      end

      # Decode pixels
      # This creates a slice with length 4*w*h and capacity minCap
      target_size = 4 * w * h
      capacity = min_cap > target_size ? min_cap : target_size
      pix = Bytes.new(capacity, 0_u8)

      p = 0
      cached_p = 0
      x, y = 0_i32, 0_i32
      hg = h_groups[0]
      lookup_hg = h_mask != 0

      while p < target_size
        if lookup_hg
          i = 4 * (tiles_per_row * (y >> h_bits) + (x >> h_bits))
          hg = h_groups[(h_pix[i].to_u32 << 8) | h_pix[i + 1].to_u32]
        end

        green = hg.green.next(@reader)

        case
        when green < N_LITERAL_CODES # Literal pixel
          red = hg.red.next(@reader)
          blue = hg.blue.next(@reader)
          alpha = hg.alpha.next(@reader)

          raise FormatError.new("vp8l: pixel buffer overflow") if p >= pix.size - 3
          pix[p + 0] = red.to_u8
          pix[p + 1] = green.to_u8
          pix[p + 2] = blue.to_u8
          pix[p + 3] = alpha.to_u8
          p += 4

          x += 1
          if x == w
            x, y = 0, y + 1
          end
          lookup_hg = h_mask != 0 && (x & h_mask) == 0
        when green < N_LITERAL_CODES + N_LENGTH_CODES # LZ77 backwards reference
          length = lz77_param(green - N_LITERAL_CODES)
          dist_sym = hg.distance.next(@reader)
          dist_code = lz77_param(dist_sym)
          dist = distance_map(w, dist_code.to_u32)

          # Bounds checking
          # Use Int64 to avoid overflow during bounds checking
          p_end_i64 = p.to_i64 + 4_i64 * length.to_i64
          q_i64 = p.to_i64 - 4_i64 * dist.to_i64
          q_end_i64 = p_end_i64 - 4_i64 * dist.to_i64

          if p < 0 || p_end_i64 > pix.size || q_i64 < 0 || q_end_i64 > pix.size
            raise FormatError.new("vp8l: invalid LZ77 parameters")
          end

          # Copy pixels byte-by-byte (handles overlapping regions correctly)
          p_end = p_end_i64.to_i
          q = q_i64.to_i
          while p < p_end
            pix[p] = pix[q]
            p += 1
            q += 1
          end

          x = x &+ length
          while x >= w
            x, y = x &- w, y &+ 1
          end
          lookup_hg = h_mask != 0
        else # Color cache lookup
          if entries = cc_entries
            # Insert previous pixels into cache before lookup
            # VP8L uses ARGB order: R at offset 0, G at 1, B at 2, A at 3
            while cached_p < p
              argb = pix[cached_p + 0].to_u32 << 16 |
                     pix[cached_p + 1].to_u32 << 8 |
                     pix[cached_p + 2].to_u32 << 0 |
                     pix[cached_p + 3].to_u32 << 24
              entries[(argb &* COLOR_CACHE_MULTIPLIER) >> cc_shift] = argb
              cached_p += 4
            end

            # Lookup color from cache
            cache_idx = green - N_LITERAL_CODES - N_LENGTH_CODES
            raise FormatError.new("vp8l: invalid color cache index") if cache_idx.to_i32 >= entries.size

            argb = entries[cache_idx]
            raise FormatError.new("vp8l: pixel buffer overflow") if p > pix.size - 4

            # Extract ARGB components: R at offset 0, G at 1, B at 2, A at 3
            pix[p + 0] = ((argb >> 16) & 0xff).to_u8 # R
            pix[p + 1] = ((argb >> 8) & 0xff).to_u8  # G
            pix[p + 2] = ((argb >> 0) & 0xff).to_u8  # B
            pix[p + 3] = ((argb >> 24) & 0xff).to_u8 # A
            p += 4

            x += 1
            if x == w
              x, y = 0, y + 1
            end
            lookup_hg = h_mask != 0 && (x & h_mask) == 0
          else
            raise FormatError.new("vp8l: color cache not initialized")
          end
        end
      end

      # Return slice of the correct size
      pix[0, target_size]
    end

    private def decode_huffman_groups(w : Int32, h : Int32, top_level : Bool, cc_bits : UInt32) : Tuple(Array(HuffmanGroup), Bytes, UInt32)
      max_hg_index = 0
      h_pix = Bytes.empty
      h_bits = 0_u32

      if top_level
        use_meta = @reader.read(1)
        if use_meta != 0
          h_bits = @reader.read(3) + 2
          h_pix = decode_pix(n_tiles(w, h_bits), n_tiles(h, h_bits), 0, false)

          # Find maximum Huffman group index in meta-image
          # Meta-image pixels encode group indices in first two bytes (R and G channels)
          p = 0
          while p < h_pix.size
            i = (h_pix[p].to_i32 << 8) | h_pix[p + 1].to_i32
            max_hg_index = i if i > max_hg_index
            p += 4
          end
        end
      end

      # Create Huffman groups with correct alphabet sizes
      h_groups = Array(HuffmanGroup).new(max_hg_index + 1) do
        HuffmanGroup.new(@reader, cc_bits)
      end

      {h_groups, h_pix, h_bits}
    end

    private def lz77_param(symbol : UInt32) : Int32
      return (symbol + 1).to_i32 if symbol < 4
      extra_bits = (symbol - 2) >> 1
      offset = (2 + (symbol & 1)) << extra_bits
      n = @reader.read(extra_bits)
      (offset + n + 1).to_i32
    end

    private def n_tiles(size : Int32, bits : UInt32) : Int32
      VP8L.n_tiles(size, bits)
    end

    private def distance_map(width : Int32, code : UInt32) : Int32
      VP8L.distance_map(width, code)
    end
  end
end
