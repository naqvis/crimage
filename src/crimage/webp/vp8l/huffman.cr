module CrImage::WEBP::VP8L
  # Reverse bits lookup table
  REVERSE_BITS = StaticArray[
    0x00_u8, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0, 0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0,
    0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8, 0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8,
    0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4, 0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
    0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec, 0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc,
    0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2, 0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2,
    0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea, 0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
    0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6, 0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6,
    0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee, 0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe,
    0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1, 0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
    0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9, 0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9,
    0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5, 0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5,
    0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed, 0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
    0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3, 0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3,
    0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb, 0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb,
    0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7, 0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
    0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef, 0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff,
  ]

  LEAF_NODE = -1_i32
  LUT_SIZE  =  7_u32
  LUT_MASK  = (1_u32 << LUT_SIZE) - 1

  # Huffman tree implementation for VP8L
  class HNode
    property symbol : UInt32
    property children : Int32

    def initialize(@symbol = 0_u32, @children = 0_i32)
    end
  end

  # Huffman tree
  class HTree
    @nodes : Array(HNode)
    @lut : StaticArray(UInt32, 128)
    @max_nodes : Int32

    def initialize
      @nodes = [HNode.new]
      @lut = StaticArray(UInt32, 128).new(0_u32)
      @max_nodes = 1
    end

    def build(code_lengths : Array(UInt32))
      # Calculate number of symbols
      n_symbols = 0_u32
      last_symbol = 0_u32
      code_lengths.each_with_index do |cl, symbol|
        if cl != 0
          n_symbols += 1
          last_symbol = symbol.to_u32
        end
      end

      raise FormatError.new("Invalid Huffman tree") if n_symbols == 0

      # Initialize nodes array with capacity for full tree
      # During construction, len grows from 1 up to cap by steps of two
      # After construction, len == cap == 2*nSymbols - 1
      @max_nodes = (2 * n_symbols - 1).to_i32
      @nodes = Array(HNode).new(1, HNode.new)

      # Handle trivial case (single symbol)
      if n_symbols == 1
        raise FormatError.new("Invalid Huffman tree") if code_lengths.size <= last_symbol
        insert(last_symbol, 0, 0)
        return
      end

      # Build canonical codes
      codes = code_lengths_to_codes(code_lengths)
      code_lengths.each_with_index do |cl, symbol|
        if cl > 0
          insert(symbol.to_u32, codes[symbol], cl)
        end
      end
    end

    def build_simple(n_symbols : UInt32, symbols : StaticArray(UInt32, 2), alphabet_size : UInt32)
      # Initialize nodes array with capacity for full tree
      @max_nodes = (2 * n_symbols - 1).to_i32
      @nodes = Array(HNode).new(1, HNode.new)

      n_symbols.times do |i|
        raise FormatError.new("Invalid Huffman tree") if symbols[i] >= alphabet_size
        insert(symbols[i], i.to_u32, n_symbols - 1)
      end
    end

    def next(decoder : CrImage::WEBP::VP8L::BitReader) : UInt32
      n = 0_u32

      # Read enough bits so we can use the look-up table
      if decoder.available_bits < LUT_SIZE
        # Try to ensure we have enough bits for LUT
        unless decoder.ensure_bits(LUT_SIZE)
          # No more bytes, but we may still be able to decode with what we have
          return slow_path(decoder, n)
        end
      end

      # Use the look-up table
      lut_val = @lut[decoder.peek(LUT_SIZE)]
      if (b = lut_val & 0xff) != 0
        b -= 1
        decoder.consume(b)
        return lut_val >> 8
      end

      # LUT miss - need to traverse tree
      n = lut_val >> 8
      decoder.consume(LUT_SIZE)

      slow_path(decoder, n)
    end

    private def slow_path(decoder : CrImage::WEBP::VP8L::BitReader, n : UInt32) : UInt32
      node_idx = n

      while @nodes[node_idx].children != LEAF_NODE
        # Ensure we have at least 1 bit available
        if decoder.available_bits == 0
          unless decoder.ensure_bits(1)
            raise FormatError.new("Unexpected EOF")
          end
        end

        bit = decoder.peek(1)
        node_idx = @nodes[node_idx].children.to_u32 + bit
        decoder.consume(1)
      end
      @nodes[node_idx].symbol
    end

    private def insert(symbol : UInt32, code : UInt32, code_length : UInt32)
      raise FormatError.new("Invalid Huffman tree") if symbol > 0xffff || code_length > 0xfe

      base_code = 0_u32
      if code_length > LUT_SIZE
        base_code = REVERSE_BITS[(code >> (code_length - LUT_SIZE)) & 0xff].to_u32 >> (8 - LUT_SIZE)
      else
        base_code = REVERSE_BITS[code & 0xff].to_u32 >> (8 - code_length)
        (1 << (LUT_SIZE - code_length)).times do |i|
          @lut[base_code | (i.to_u32 << code_length)] = (symbol << 8) | (code_length + 1)
        end
      end

      n = 0_u32
      jump = LUT_SIZE.to_i32
      remaining_code_length = code_length
      while remaining_code_length > 0
        remaining_code_length -= 1
        raise FormatError.new("Invalid Huffman tree") if n.to_i32 > @nodes.size

        case @nodes[n].children
        when LEAF_NODE
          raise FormatError.new("Invalid Huffman tree")
        when 0
          # Check if we can add 2 more nodes without exceeding capacity
          raise FormatError.new("Invalid Huffman tree") if @nodes.size >= @max_nodes
          # Create two empty child nodes
          @nodes[n].children = @nodes.size.to_i32
          @nodes << HNode.new
          @nodes << HNode.new
        end

        children_idx = @nodes[n].children
        if children_idx == LEAF_NODE
          raise FormatError.new("Invalid Huffman tree: unexpected leaf node in traversal")
        end
        if children_idx < 0
          raise FormatError.new("Invalid Huffman tree: negative children index #{children_idx}")
        end
        n = children_idx.to_u32 + (1_u32 & (code >> remaining_code_length))

        jump -= 1
        if jump == 0 && @lut[base_code] == 0
          @lut[base_code] = n << 8
        end
      end

      case @nodes[n].children
      when LEAF_NODE
        # No-op - already a leaf
      when 0
        # Turn the uninitialized node into a leaf
        @nodes[n].children = LEAF_NODE
      else
        raise FormatError.new("Invalid Huffman tree: node #{n} already has children #{@nodes[n].children}")
      end

      @nodes[n].symbol = symbol
    end

    private def code_lengths_to_codes(code_lengths : Array(UInt32)) : Array(UInt32)
      # Find maximum code length
      max_code_length = 0_u32
      code_lengths.each do |cl|
        max_code_length = cl if cl > max_code_length
      end

      # Validate code lengths
      max_allowed_code_length = 15_u32
      raise FormatError.new("Invalid Huffman tree") if code_lengths.empty? || max_code_length > max_allowed_code_length

      # Build histogram of code lengths
      histogram = StaticArray(UInt32, 16).new(0_u32)
      code_lengths.each { |cl| histogram[cl] += 1 }

      # Generate next codes for each code length
      curr_code = 0_u32
      next_codes = StaticArray(UInt32, 16).new(0_u32)
      1.upto(15) do |cl|
        curr_code = (curr_code + histogram[cl - 1]) << 1
        next_codes[cl] = curr_code
      end

      # Assign codes to symbols
      codes = Array(UInt32).new(code_lengths.size, 0_u32)
      code_lengths.each_with_index do |cl, symbol|
        if cl > 0
          codes[symbol] = next_codes[cl]
          next_codes[cl] += 1
        end
      end

      codes
    end
  end

  # Code length decoding constants
  REPEATS_CODE_LENGTH    = 16_u32
  CODE_LENGTH_CODE_ORDER = StaticArray[
    17_u8, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
  ]
  REPEAT_BITS    = StaticArray[2_u8, 3, 7]
  REPEAT_OFFSETS = StaticArray[3_u8, 3, 11]

  # Huffman group (5 trees: green, red, blue, alpha, distance)
  class HuffmanGroup
    getter green : HTree
    getter red : HTree
    getter blue : HTree
    getter alpha : HTree
    getter distance : HTree

    ALPHABET_SIZES = StaticArray[256_u32 + 24, 256_u32, 256_u32, 256_u32, 40_u32]

    def initialize(decoder : BitReader, cc_bits : UInt32)
      green_size = ALPHABET_SIZES[0]
      green_size += (1_u32 << cc_bits) if cc_bits > 0
      @green = decode_huffman_tree(decoder, green_size)
      @red = decode_huffman_tree(decoder, ALPHABET_SIZES[1])
      @blue = decode_huffman_tree(decoder, ALPHABET_SIZES[2])
      @alpha = decode_huffman_tree(decoder, ALPHABET_SIZES[3])
      @distance = decode_huffman_tree(decoder, ALPHABET_SIZES[4])
    end

    private def decode_huffman_tree(decoder : BitReader, alphabet_size : UInt32) : HTree
      tree = HTree.new
      use_simple = decoder.read(1)

      if use_simple != 0
        n_symbols = decoder.read(1) + 1
        first_symbol_length_code = decoder.read(1)
        first_symbol_length_code = 7 * first_symbol_length_code + 1

        symbols = StaticArray(UInt32, 2).new(0_u32)
        symbols[0] = decoder.read(first_symbol_length_code.to_u32)
        symbols[1] = decoder.read(8) if n_symbols == 2

        tree.build_simple(n_symbols.to_u32, symbols, alphabet_size)
      else
        n_codes = decoder.read(4) + 4
        raise FormatError.new("Invalid Huffman tree") if n_codes > CODE_LENGTH_CODE_ORDER.size

        code_length_code_lengths = Array(UInt32).new(CODE_LENGTH_CODE_ORDER.size, 0_u32)
        n_codes.times do |i|
          code_length_code_lengths[CODE_LENGTH_CODE_ORDER[i]] = decoder.read(3)
        end

        code_lengths = decode_code_lengths(decoder, code_length_code_lengths, alphabet_size.to_i32)
        tree.build(code_lengths)
      end

      tree
    end

    private def decode_code_lengths(decoder : BitReader, code_length_code_lengths : Array(UInt32), max_symbol : Int32) : Array(UInt32)
      h = HTree.new
      h.build(code_length_code_lengths)

      dst = Array(UInt32).new(max_symbol, 0_u32)

      use_length = decoder.read(1)
      if use_length != 0
        n = decoder.read(3)
        n = 2 + 2 * n
        ms = decoder.read(n.to_u32)
        max_symbol = (ms + 2).to_i32
        raise FormatError.new("Invalid code lengths") if max_symbol > dst.size
      end

      prev_code_length = 8_u32
      symbol = 0

      while symbol < dst.size
        break if max_symbol == 0
        max_symbol -= 1

        code_length = h.next(decoder)

        if code_length < REPEATS_CODE_LENGTH
          dst[symbol] = code_length
          symbol += 1
          prev_code_length = code_length if code_length != 0
          next
        end

        repeat = decoder.read(REPEAT_BITS[code_length - REPEATS_CODE_LENGTH].to_u32)
        repeat += REPEAT_OFFSETS[code_length - REPEATS_CODE_LENGTH].to_u32
        raise FormatError.new("Invalid code lengths") if symbol + repeat > dst.size

        cl = code_length == 16 ? prev_code_length : 0_u32
        repeat.times do
          dst[symbol] = cl
          symbol += 1
        end
      end

      dst
    end
  end
end
