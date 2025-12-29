module CrImage::WEBP
  # HuffmanCode represents a Huffman code with its symbol, bit pattern, and depth.
  #
  # Stores a single Huffman code mapping a symbol to its bit representation.
  # WebP uses reversed bit order (LSB first).
  #
  # Properties:
  # - `symbol` : The value being encoded (0-255 for colors, etc.)
  # - `bits` : The bit pattern (reversed for WebP)
  # - `depth` : Code length in bits (0 = unused, -1 = single symbol alphabet)
  class HuffmanCode
    property symbol : Int32
    property bits : Int32
    property depth : Int32

    def initialize(@symbol : Int32, @bits : Int32, @depth : Int32)
    end
  end

  # HuffmanNode represents a node in the Huffman tree.
  #
  # Used during tree construction. Leaf nodes represent symbols,
  # branch nodes combine subtrees.
  private class HuffmanNode
    property is_branch : Bool
    property weight : Int32
    property symbol : Int32
    property left : HuffmanNode?
    property right : HuffmanNode?

    def initialize(@weight : Int32, @symbol : Int32 = -1, @is_branch : Bool = false)
      @left = nil
      @right = nil
    end

    # Create a branch node from two child nodes
    def self.branch(left : HuffmanNode, right : HuffmanNode) : HuffmanNode
      node = new(left.weight + right.weight, -1, true)
      node.left = left
      node.right = right
      node
    end

    # Compare nodes by weight for priority queue
    def <=>(other : HuffmanNode) : Int32
      @weight <=> other.weight
    end
  end

  # HuffmanEncoder builds Huffman trees and generates codes for entropy encoding.
  #
  # Implements canonical Huffman coding with depth limiting for WebP.
  # Supports both simple codes (1-2 symbols) and full Huffman trees
  # with meta-Huffman encoding of code lengths.
  module HuffmanEncoder
    # Code length order for meta-Huffman encoding (WebP specification)
    CODE_LENGTH_ORDER = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

    # Builds Huffman codes from a frequency histogram with maximum depth limit.
    #
    # Constructs optimal Huffman tree, computes code depths, limits depths
    # to max_depth, and generates canonical codes.
    #
    # Parameters:
    # - `histogram` : Frequency count for each symbol
    # - `max_depth` : Maximum code length (default: 15)
    #
    # Returns: Array of HuffmanCode indexed by symbol
    #
    # Special cases:
    # - Empty histogram: Returns all zero-depth codes
    # - Single symbol: Returns depth -1 (handled by simple code format)
    def self.build_codes(histogram : Array(Int32), max_depth : Int32 = 15) : Array(HuffmanCode)
      alphabet_size = histogram.size

      # Count non-zero symbols
      non_zero_count = histogram.count { |freq| freq > 0 }

      # Handle special cases
      if non_zero_count == 0
        # No symbols - return empty codes
        return Array(HuffmanCode).new(alphabet_size) { |i| HuffmanCode.new(i, 0, 0) }
      elsif non_zero_count == 1
        # Single symbol - use depth -1 (no bits needed, handled by simple code format)
        symbol = histogram.index { |freq| freq > 0 }.not_nil!
        codes = Array(HuffmanCode).new(alphabet_size) { |i| HuffmanCode.new(i, 0, 0) }
        codes[symbol] = HuffmanCode.new(symbol, 0, -1)
        return codes
      end

      # Build Huffman tree
      tree = build_huffman_tree(histogram, max_depth)

      # Compute depths for each symbol
      depths = Array(Int32).new(alphabet_size, 0)
      compute_depths(tree, 0, depths)

      # Limit depths to max_depth
      limit_depths(depths, histogram, max_depth)

      # Generate canonical Huffman codes from depths
      generate_canonical_codes(depths)
    end

    # Builds a Huffman tree from histogram using a priority queue.
    #
    # Creates leaf nodes for non-zero frequencies, applies minimum weight
    # threshold to help limit depth, and merges nodes bottom-up.
    private def self.build_huffman_tree(histogram : Array(Int32), max_depth : Int32) : HuffmanNode
      # Calculate sum of all frequencies
      sum = 0
      histogram.each { |x| sum += x }

      # Calculate minimum weight threshold to help limit tree depth
      min_weight = sum >> (max_depth - 2)

      # Create leaf nodes for symbols with non-zero frequency
      nodes = [] of HuffmanNode
      histogram.each_with_index do |freq, symbol|
        if freq > 0
          # Apply minimum weight threshold
          weight = freq < min_weight ? min_weight : freq
          nodes << HuffmanNode.new(weight, symbol, false)
        end
      end

      # Ensure we have at least one node
      while nodes.size < 1
        nodes << HuffmanNode.new(min_weight, 0, false)
      end

      # Sort nodes by weight (min-heap behavior)
      nodes.sort!

      # Build tree by repeatedly merging two lowest-weight nodes
      while nodes.size > 1
        # Take two nodes with lowest weight
        left = nodes.shift
        right = nodes.shift

        # Create branch node
        branch = HuffmanNode.branch(left, right)

        # Insert branch back into sorted position
        insert_pos = nodes.bsearch_index { |n| n.weight > branch.weight } || nodes.size
        nodes.insert(insert_pos, branch)
      end

      nodes.first
    end

    # Computes depth of each symbol in the tree.
    #
    # Recursively traverses tree, recording depth for each leaf node.
    private def self.compute_depths(node : HuffmanNode?, depth : Int32, depths : Array(Int32)) : Nil
      return if node.nil?

      if !node.is_branch
        # Leaf node - record depth
        depths[node.symbol] = depth
      else
        # Branch node - recurse
        compute_depths(node.left, depth + 1, depths)
        compute_depths(node.right, depth + 1, depths)
      end
    end

    # Limits code depths to max_depth using simplified package-merge algorithm.
    #
    # If any code exceeds max_depth, redistributes depths by capping deep
    # codes and increasing shallow codes to maintain valid tree.
    private def self.limit_depths(depths : Array(Int32), histogram : Array(Int32), max_depth : Int32) : Nil
      # Check if any depth exceeds max_depth
      max_current_depth = depths.max? || 0
      return if max_current_depth <= max_depth

      # Simple depth limiting: redistribute symbols with excessive depth
      loop do
        max_current_depth = depths.max? || 0
        break if max_current_depth <= max_depth

        # Find symbols with depth > max_depth
        deep_symbols = [] of Int32
        depths.each_with_index do |depth, symbol|
          deep_symbols << symbol if depth > max_depth && histogram[symbol] > 0
        end

        break if deep_symbols.empty?

        # Reduce depth of deepest symbols
        deep_symbols.each do |symbol|
          depths[symbol] = max_depth
        end

        # Rebalance: increase depth of some shallow symbols
        shallow_symbols = [] of Int32
        depths.each_with_index do |depth, symbol|
          shallow_symbols << symbol if depth > 0 && depth < max_depth && histogram[symbol] > 0
        end

        if !shallow_symbols.empty?
          # Increase depth of least frequent shallow symbol
          min_freq_symbol = shallow_symbols.min_by { |s| histogram[s] }
          depths[min_freq_symbol] += 1
        end

        break if depths.max? || 0 <= max_depth
      end
    end

    # Generates canonical Huffman codes from code depths.
    #
    # Canonical codes have the property that codes of the same length
    # are sequential, making them easier to decode and transmit.
    private def self.generate_canonical_codes(depths : Array(Int32)) : Array(HuffmanCode)
      alphabet_size = depths.size

      # Create symbol-depth pairs and sort
      symbols_by_depth = [] of Tuple(Int32, Int32)
      depths.each_with_index do |depth, symbol|
        symbols_by_depth << {depth, symbol} if depth > 0
      end

      # Sort by depth first, then by symbol value
      symbols_by_depth.sort_by! { |pair| {pair[0], pair[1]} }

      # Assign canonical codes
      codes = Array(HuffmanCode).new(alphabet_size) { |i| HuffmanCode.new(i, 0, 0) }
      code = 0
      prev_depth = 0

      symbols_by_depth.each do |depth, symbol|
        # Shift code left when depth increases
        code <<= (depth - prev_depth)
        codes[symbol] = HuffmanCode.new(symbol, code, depth)
        code += 1
        prev_depth = depth
      end

      codes
    end

    # Writes Huffman codes to bitstream using simple or complex encoding.
    #
    # Chooses between simple code format (1-2 symbols) and full Huffman
    # encoding with meta-Huffman code lengths.
    #
    # Simple format: Used when 1-2 symbols with values < 256
    # Complex format: Uses meta-Huffman to encode code lengths
    def self.write_codes(writer : BitWriter, codes : Array(HuffmanCode)) : Nil
      # Count symbols with non-zero depth (including -1 for single symbols)
      non_zero_symbols = codes.select { |code| code.depth != 0 }
      count = non_zero_symbols.size

      if count == 0
        # No symbols - write simple code with 0 in 3 bits
        writer.write_bits(1_u64, 1) # simple_code_or_skip = 1
        writer.write_bits(0_u64, 3) # Write 0 in 3 bits
        return
      elsif count <= 2 && non_zero_symbols.all? { |code| code.symbol < 256 }
        # Simple code: 1 or 2 symbols with values < 256
        write_simple_code(writer, non_zero_symbols)
      else
        # Complex code: use meta-Huffman encoding
        write_full_huffman_code(writer, codes)
      end
    end

    # Writes simple Huffman code (1 or 2 symbols).
    #
    # Simple format is more compact for small alphabets. Symbols are
    # written directly without building a full tree.
    private def self.write_simple_code(writer : BitWriter, symbols : Array(HuffmanCode)) : Nil
      writer.write_bits(1_u64, 1)                     # simple_code_or_skip = 1
      writer.write_bits((symbols.size - 1).to_u64, 1) # num_symbols: 0 = 1 symbol, 1 = 2 symbols

      symbol0 = symbols[0].symbol
      # first_symbol_length_code: 0 = 1 bit, 1 = 8 bits (7*1+1)
      if symbol0 <= 1
        writer.write_bits(0_u64, 1)          # first_symbol_length_code = 0 (1 bit follows)
        writer.write_bits(symbol0.to_u64, 1) # Write symbol in 1 bit
      else
        writer.write_bits(1_u64, 1)          # first_symbol_length_code = 1 (8 bits follow)
        writer.write_bits(symbol0.to_u64, 8) # Write symbol in 8 bits
      end

      if symbols.size > 1
        writer.write_bits(symbols[1].symbol.to_u64, 8) # Second symbol always 8 bits
      end
    end

    # Writes full Huffman code using meta-Huffman encoding.
    #
    # Encodes code lengths using a separate Huffman tree (meta-Huffman),
    # then writes the actual code lengths. This two-level approach
    # compresses the code length data.
    def self.write_full_huffman_code(writer : BitWriter, codes : Array(HuffmanCode)) : Nil
      writer.write_bits(0_u64, 1) # simple_code_or_skip = 0

      # Collect code lengths
      code_lengths = codes.map(&.depth)

      # Build histogram of code lengths (including zeros)
      # WebP spec: code lengths can be 0-15, plus special codes 16-18 for RLE
      # So we need histogram size of 19
      length_histogram = Array(Int32).new(19, 0)
      code_lengths.each do |length|
        length_histogram[length] += 1 if length < 19
      end

      # Build Huffman codes for code lengths (meta-Huffman)
      meta_codes = build_codes(length_histogram, 7) # Max depth 7 for meta codes

      # Determine how many code length codes to write
      # Find the last non-zero entry in the histogram (in CODE_LENGTH_ORDER)
      num_code_lengths = 0
      CODE_LENGTH_ORDER.each_with_index do |order, i|
        if order < length_histogram.size && length_histogram[order] > 0
          num_code_lengths = [i + 1, 4].max
        end
      end
      num_code_lengths = [num_code_lengths, 4].max # At least 4

      # Write number of code length codes
      writer.write_bits((num_code_lengths - 4).to_u64, 4)

      # Write code length codes in specified order
      num_code_lengths.times do |i|
        order = CODE_LENGTH_ORDER[i]
        depth = order < meta_codes.size ? meta_codes[order].depth : 0
        # Depth can be -1 for single-symbol alphabets, treat as 0
        depth = 0 if depth < 0
        writer.write_bits(depth.to_u64, 3)
      end

      # Write use_length flag (0 = use all symbols)
      writer.write_bits(0_u64, 1)

      # Write actual code lengths using meta-Huffman encoding
      # For each code in the original alphabet, write its depth using the meta-Huffman code
      codes.each do |code|
        # Use the code's depth as the symbol to encode with meta-Huffman
        writer.write_code(meta_codes[code.depth])
      end
    end
  end
end
