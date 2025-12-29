module CrImage::Util
  # Color quantization algorithms for palette generation.
  #
  # Different algorithms offer trade-offs between quality and speed:
  # - `MedianCut` : Divides color space by median, good quality, moderate speed
  # - `Octree` : Tree-based clustering, fast, good for large images
  # - `Popularity` : Selects most frequent colors, fastest, simpler results
  enum QuantizationAlgorithm
    MedianCut
    Octree
    Popularity
  end

  # Advanced color quantization algorithms for palette generation.
  # Implements median cut and octree quantization for better color reduction.
  module Quantization
    # Generates an optimal color palette from an image using the specified algorithm.
    #
    # Parameters:
    # - `src` : The source image
    # - `max_colors` : Maximum number of colors in palette (2-256)
    # - `algorithm` : Quantization algorithm to use (default: MedianCut)
    #
    # Returns: A `Color::Palette` with optimal colors
    #
    # Example:
    # ```
    # img = CrImage::PNG.read("photo.png")
    # palette = CrImage::Util::Quantization.generate_palette(img, 16)
    # dithered = img.dither(palette)
    # ```
    def self.generate_palette(src : Image, max_colors : Int32 = 256,
                              algorithm : QuantizationAlgorithm = QuantizationAlgorithm::MedianCut) : Color::Palette
      raise ArgumentError.new("max_colors must be between 2 and 256") unless max_colors >= 2 && max_colors <= 256

      case algorithm
      when .median_cut?
        median_cut(src, max_colors)
      when .octree?
        octree(src, max_colors)
      when .popularity?
        popularity(src, max_colors)
      else
        raise ArgumentError.new("Unknown quantization algorithm")
      end
    end

    # Median cut algorithm - divides color space by median values.
    #
    # Recursively splits color boxes along the dimension with largest range,
    # dividing at the median. Produces well-distributed palettes.
    private def self.median_cut(src : Image, max_colors : Int32) : Color::Palette
      # Collect all colors from image
      colors = collect_colors(src)
      return Color::Palette.new(colors.map(&.as(Color::Color))) if colors.size <= max_colors

      # Create initial box with all colors
      boxes = [ColorBox.new(colors)]

      # Split boxes until we have enough colors
      while boxes.size < max_colors
        # Find box with largest range
        largest_box = boxes.max_by { |box| box.range }
        break if largest_box.range == 0

        # Split the box
        box1, box2 = largest_box.split
        boxes.delete(largest_box)
        boxes << box1
        boxes << box2
      end

      # Get average color from each box
      palette_colors = boxes.map { |box| box.average_color.as(Color::Color) }
      Color::Palette.new(palette_colors)
    end

    # Octree quantization - uses tree structure for color clustering.
    #
    # Builds an octree of colors, then reduces it to the target size by
    # merging leaf nodes. Fast and memory-efficient for large images.
    private def self.octree(src : Image, max_colors : Int32) : Color::Palette
      tree = OctreeNode.new(0)

      # Insert all colors into octree
      bounds = src.bounds
      bounds.height.times do |y|
        bounds.width.times do |x|
          r, g, b, _ = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          tree.insert((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, 0)
        end
      end

      # Reduce tree to max_colors
      while tree.leaf_count > max_colors
        tree.reduce
      end

      # Get palette colors
      palette_colors = tree.get_palette
      Color::Palette.new(palette_colors)
    end

    # Popularity algorithm - selects most frequent colors.
    #
    # Counts color frequencies and returns the N most common colors.
    # Fastest method but may miss important but less frequent colors.
    private def self.popularity(src : Image, max_colors : Int32) : Color::Palette
      # Count color frequencies
      color_counts = Hash(UInt32, Int32).new(0)

      bounds = src.bounds
      bounds.height.times do |y|
        bounds.width.times do |x|
          r, g, b, _ = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          # Pack RGB into single value for hashing
          packed = ((r >> 8).to_u32 << 16) | ((g >> 8).to_u32 << 8) | (b >> 8).to_u32
          color_counts[packed] += 1
        end
      end

      # Sort by frequency and take top N
      top_colors = color_counts.to_a.sort_by { |_, count| -count }.first(max_colors)

      # Convert back to Color objects
      palette_colors = top_colors.map do |packed, _|
        r = ((packed >> 16) & 0xFF).to_u8
        g = ((packed >> 8) & 0xFF).to_u8
        b = (packed & 0xFF).to_u8
        Color::RGBA.new(r, g, b, 255).as(Color::Color)
      end

      Color::Palette.new(palette_colors)
    end

    # Collects all unique colors from the image.
    #
    # Returns array of distinct RGBA colors found in the image.
    private def self.collect_colors(src : Image) : Array(Color::RGBA)
      colors = [] of Color::RGBA
      bounds = src.bounds

      bounds.height.times do |y|
        bounds.width.times do |x|
          r, g, b, _ = src.at(x + bounds.min.x, y + bounds.min.y).rgba
          colors << Color::RGBA.new((r >> 8).to_u8, (g >> 8).to_u8, (b >> 8).to_u8, 255)
        end
      end

      colors.uniq
    end

    # Color box for median cut algorithm.
    #
    # Represents a region of color space containing a set of colors.
    # Used for recursive subdivision in median cut quantization.
    private class ColorBox
      property colors : Array(Color::RGBA)

      def initialize(@colors : Array(Color::RGBA))
      end

      # Calculates the range (maximum extent) across all color channels.
      #
      # Returns the largest difference in any single channel (R, G, or B).
      def range : Int32
        return 0 if @colors.empty?

        r_min = r_max = @colors[0].r.to_i32
        g_min = g_max = @colors[0].g.to_i32
        b_min = b_max = @colors[0].b.to_i32

        @colors.each do |color|
          r = color.r.to_i32
          g = color.g.to_i32
          b = color.b.to_i32
          r_min = r if r < r_min
          r_max = r if r > r_max
          g_min = g if g < g_min
          g_max = g if g > g_max
          b_min = b if b < b_min
          b_max = b if b > b_max
        end

        r_range = r_max - r_min
        g_range = g_max - g_min
        b_range = b_max - b_min

        [r_range, g_range, b_range].max
      end

      # Splits the color box into two boxes at the median.
      #
      # Divides along the channel with the largest range for optimal splitting.
      #
      # Returns: Tuple of two new ColorBox instances
      def split : Tuple(ColorBox, ColorBox)
        return {self, ColorBox.new([] of Color::RGBA)} if @colors.size <= 1

        # Find channel with largest range
        r_range = @colors.max_of(&.r) - @colors.min_of(&.r)
        g_range = @colors.max_of(&.g) - @colors.min_of(&.g)
        b_range = @colors.max_of(&.b) - @colors.min_of(&.b)

        # Sort by channel with largest range
        sorted = if r_range >= g_range && r_range >= b_range
                   @colors.sort_by(&.r)
                 elsif g_range >= b_range
                   @colors.sort_by(&.g)
                 else
                   @colors.sort_by(&.b)
                 end

        # Split at median
        mid = sorted.size // 2
        {ColorBox.new(sorted[0...mid]), ColorBox.new(sorted[mid..])}
      end

      # Calculates the average color of all colors in the box.
      #
      # Returns: Mean color representing this color box
      def average_color : Color::RGBA
        return Color::RGBA.new(0, 0, 0, 255) if @colors.empty?

        r_sum = g_sum = b_sum = 0_u32
        @colors.each do |color|
          r_sum += color.r
          g_sum += color.g
          b_sum += color.b
        end

        count = @colors.size
        Color::RGBA.new(
          (r_sum // count).to_u8,
          (g_sum // count).to_u8,
          (b_sum // count).to_u8,
          255
        )
      end
    end

    # Octree node for octree quantization.
    #
    # Each node represents a region of RGB color space. Leaf nodes at level 7
    # represent individual colors, while internal nodes group similar colors.
    private class OctreeNode
      property children : Array(OctreeNode?)
      property is_leaf : Bool
      property pixel_count : Int32
      property red_sum : Int32
      property green_sum : Int32
      property blue_sum : Int32
      property level : Int32

      def initialize(@level : Int32)
        @children = Array(OctreeNode?).new(8, nil)
        @is_leaf = @level == 7
        @pixel_count = 0
        @red_sum = 0
        @green_sum = 0
        @blue_sum = 0
      end

      # Inserts a color into the octree.
      #
      # Recursively traverses the tree based on RGB bit values, creating
      # nodes as needed. Leaf nodes accumulate color sums for averaging.
      def insert(r : UInt8, g : UInt8, b : UInt8, level : Int32)
        if @is_leaf
          @pixel_count += 1
          @red_sum += r
          @green_sum += g
          @blue_sum += b
        else
          # Calculate index in octree (3 bits: one from each channel)
          shift = 7 - level
          index = ((r >> shift) & 1) << 2 | ((g >> shift) & 1) << 1 | ((b >> shift) & 1)

          child = @children[index]
          if child.nil?
            child = OctreeNode.new(level + 1)
            @children[index] = child
          end

          child.insert(r, g, b, level + 1)
        end
      end

      # Counts the total number of leaf nodes in the subtree.
      #
      # Returns: Number of leaf nodes (palette colors)
      def leaf_count : Int32
        return 1 if @is_leaf

        count = 0
        @children.each do |child|
          count += child.leaf_count if child
        end
        count
      end

      # Reduces the tree by merging leaf nodes into their parent.
      #
      # Finds the deepest level with leaves and merges them, reducing
      # the total number of colors in the palette.
      def reduce
        # Find deepest level with leaves
        @children.each do |child|
          next unless child
          if !child.is_leaf
            child.reduce
            return
          end
        end

        # Merge children into this node
        @children.each do |child|
          next unless child
          @pixel_count += child.pixel_count
          @red_sum += child.red_sum
          @green_sum += child.green_sum
          @blue_sum += child.blue_sum
        end

        @is_leaf = true
        @children.fill(nil)
      end

      # Extracts the palette colors from leaf nodes.
      #
      # Recursively collects average colors from all leaf nodes.
      #
      # Returns: Array of colors representing the quantized palette
      def get_palette : Array(Color::Color)
        colors = [] of Color::Color

        if @is_leaf && @pixel_count > 0
          r = (@red_sum // @pixel_count).clamp(0, 255).to_u8
          g = (@green_sum // @pixel_count).clamp(0, 255).to_u8
          b = (@blue_sum // @pixel_count).clamp(0, 255).to_u8
          colors << Color::RGBA.new(r, g, b, 255).as(Color::Color)
        else
          @children.each do |child|
            colors.concat(child.get_palette) if child
          end
        end

        colors
      end
    end
  end
end
