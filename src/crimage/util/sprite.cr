module CrImage::Util
  # Sprite sheet layout strategies.
  #
  # Different layout algorithms for organizing sprites:
  # - `Horizontal` : Single row, left to right
  # - `Vertical` : Single column, top to bottom
  # - `Grid` : Uniform grid with automatic dimensions
  # - `Packed` : Efficient packing to minimize wasted space
  enum SpriteLayout
    Horizontal
    Vertical
    Grid
    Packed
  end

  # Metadata for a sprite within a sprite sheet.
  #
  # Contains position and dimensions of a sprite in the combined sheet.
  # Used for extracting individual sprites or generating sprite maps.
  struct SpriteInfo
    property x : Int32
    property y : Int32
    property width : Int32
    property height : Int32
    property index : Int32

    def initialize(@x, @y, @width, @height, @index)
    end

    # Returns the bounding rectangle of this sprite.
    #
    # Useful for cropping the sprite from the sheet.
    def bounds : Rectangle
      CrImage.rect(@x, @y, @x + @width, @y + @height)
    end
  end

  # Result of sprite sheet generation.
  #
  # Contains the combined sprite sheet image and metadata for each sprite.
  # Provides convenient access to sprite positions and dimensions.
  struct SpriteSheet
    property image : RGBA
    property sprites : Array(SpriteInfo)

    def initialize(@image, @sprites)
    end

    # Gets sprite info by index.
    #
    # Returns: SpriteInfo for the specified sprite
    def [](index : Int32) : SpriteInfo
      @sprites[index]
    end

    # Returns the total number of sprites in the sheet.
    def size : Int32
      @sprites.size
    end
  end

  # Generate sprite sheets from multiple images.
  #
  # Provides tools for combining multiple images into optimized sprite sheets.
  # Useful for:
  # - Game development (texture atlases)
  # - Web optimization (CSS sprites)
  # - Animation frames
  # - Icon sets
  module SpriteGenerator
    # Generates a sprite sheet from multiple images.
    #
    # Combines images into a single sheet using the specified layout algorithm.
    # Returns both the combined image and metadata for extracting individual sprites.
    #
    # Parameters:
    # - `images` : Array of images to combine (must not be empty)
    # - `layout` : Layout strategy (default: Horizontal)
    # - `spacing` : Pixels between sprites (default: 0)
    # - `background` : Background color (default: transparent)
    #
    # Returns: SpriteSheet with combined image and sprite metadata
    #
    # Raises: `ArgumentError` if images array is empty or spacing is negative
    #
    # Example:
    # ```
    # images = [img1, img2, img3]
    # sheet = CrImage::Util::SpriteGenerator.generate(images)
    # CrImage::PNG.write("sprites.png", sheet.image)
    # sheet.sprites.each { |s| puts "Sprite #{s.index}: (#{s.x}, #{s.y})" }
    # ```
    def self.generate(images : Array(Image),
                      layout : SpriteLayout = SpriteLayout::Horizontal,
                      spacing : Int32 = 0,
                      background : Color::Color = Color::TRANSPARENT) : SpriteSheet
      raise ArgumentError.new("images array cannot be empty") if images.empty?
      raise ArgumentError.new("spacing must be non-negative") if spacing < 0

      case layout
      when .horizontal?
        generate_horizontal(images, spacing, background)
      when .vertical?
        generate_vertical(images, spacing, background)
      when .grid?
        generate_grid(images, spacing, background)
      when .packed?
        generate_packed(images, spacing, background)
      else
        generate_horizontal(images, spacing, background)
      end
    end

    # Generates horizontal sprite sheet (single row).
    #
    # Places all sprites in a single row from left to right.
    private def self.generate_horizontal(images : Array(Image), spacing : Int32, background : Color::Color) : SpriteSheet
      # Calculate dimensions
      total_width = 0
      max_height = 0

      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y
        total_width += width
        max_height = height if height > max_height
      end

      total_width += spacing * (images.size - 1) if images.size > 1

      # Create sprite sheet
      sheet = CrImage.rgba(total_width, max_height, background)
      sprites = [] of SpriteInfo

      # Place sprites
      current_x = 0
      images.each_with_index do |img, idx|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Copy image to sheet
        copy_image(sheet, img, current_x, 0)

        # Record sprite info
        sprites << SpriteInfo.new(current_x, 0, width, height, idx)

        current_x += width + spacing
      end

      SpriteSheet.new(sheet, sprites)
    end

    # Generates vertical sprite sheet (single column).
    #
    # Places all sprites in a single column from top to bottom.
    private def self.generate_vertical(images : Array(Image), spacing : Int32, background : Color::Color) : SpriteSheet
      # Calculate dimensions
      max_width = 0
      total_height = 0

      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y
        max_width = width if width > max_width
        total_height += height
      end

      total_height += spacing * (images.size - 1) if images.size > 1

      # Create sprite sheet
      sheet = CrImage.rgba(max_width, total_height, background)
      sprites = [] of SpriteInfo

      # Place sprites
      current_y = 0
      images.each_with_index do |img, idx|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Copy image to sheet
        copy_image(sheet, img, 0, current_y)

        # Record sprite info
        sprites << SpriteInfo.new(0, current_y, width, height, idx)

        current_y += height + spacing
      end

      SpriteSheet.new(sheet, sprites)
    end

    # Generates grid sprite sheet with uniform cells.
    #
    # Arranges sprites in a square-ish grid with automatic row/column calculation.
    private def self.generate_grid(images : Array(Image), spacing : Int32, background : Color::Color) : SpriteSheet
      # Calculate optimal grid dimensions
      count = images.size
      cols = ::Math.sqrt(count.to_f64).ceil.to_i32
      rows = (count.to_f64 / cols).ceil.to_i32

      # Find max dimensions for uniform grid
      max_width = 0
      max_height = 0

      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y
        max_width = width if width > max_width
        max_height = height if height > max_height
      end

      # Calculate total dimensions
      total_width = cols * max_width + (cols - 1) * spacing
      total_height = rows * max_height + (rows - 1) * spacing

      # Create sprite sheet
      sheet = CrImage.rgba(total_width, total_height, background)
      sprites = [] of SpriteInfo

      # Place sprites in grid
      images.each_with_index do |img, idx|
        row = idx // cols
        col = idx % cols

        x = col * (max_width + spacing)
        y = row * (max_height + spacing)

        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Copy image to sheet
        copy_image(sheet, img, x, y)

        # Record sprite info
        sprites << SpriteInfo.new(x, y, width, height, idx)
      end

      SpriteSheet.new(sheet, sprites)
    end

    # Generates packed sprite sheet with efficient space usage.
    #
    # Uses simple left-to-right, top-to-bottom packing sorted by height
    # to minimize wasted space.
    private def self.generate_packed(images : Array(Image), spacing : Int32, background : Color::Color) : SpriteSheet
      # Sort images by height (tallest first) for better packing
      sorted_indices = (0...images.size).to_a.sort_by do |i|
        bounds = images[i].bounds
        -(bounds.max.y - bounds.min.y)
      end

      # Calculate approximate dimensions
      total_area = 0
      max_height = 0

      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y
        total_area += width * height
        max_height = height if height > max_height
      end

      # Estimate sheet width (square-ish)
      sheet_width = ::Math.sqrt(total_area.to_f64 * 1.2).ceil.to_i32

      # Pack sprites
      sprites = Array(SpriteInfo).new(images.size)
      current_x = 0
      current_y = 0
      row_height = 0
      max_x = 0

      sorted_indices.each do |idx|
        img = images[idx]
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Check if we need to move to next row
        if current_x + width > sheet_width && current_x > 0
          current_x = 0
          current_y += row_height + spacing
          row_height = 0
        end

        # Record position (will be reordered later)
        sprites << SpriteInfo.new(current_x, current_y, width, height, idx)

        row_height = height if height > row_height
        current_x += width + spacing
        max_x = current_x if current_x > max_x
      end

      # Calculate final dimensions
      final_width = max_x - spacing
      final_height = current_y + row_height

      # Create sprite sheet
      sheet = CrImage.rgba(final_width, final_height, background)

      # Copy images and reorder sprite info by original index
      reordered_sprites = Array(SpriteInfo).new(images.size)
      sprites.each do |sprite_info|
        img = images[sprite_info.index]
        copy_image(sheet, img, sprite_info.x, sprite_info.y)
        reordered_sprites << sprite_info
      end

      # Sort back to original order
      reordered_sprites.sort_by! { |s| s.index }

      SpriteSheet.new(sheet, reordered_sprites)
    end

    # Copies image to destination at specified position.
    #
    # Pixel-by-pixel copy for compositing sprites into the sheet.
    private def self.copy_image(dst : RGBA, src : Image, dst_x : Int32, dst_y : Int32)
      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      src_height.times do |y|
        src_width.times do |x|
          color = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
          dst.set(dst_x + x, dst_y + y, color)
        end
      end
    end
  end
end

module CrImage
  # Generates sprite sheet from array of images.
  #
  # Convenience method that delegates to `Util::SpriteGenerator.generate`.
  #
  # Example:
  # ```
  # images = [img1, img2, img3]
  # sheet = CrImage.generate_sprite_sheet(images)
  # ```
  def self.generate_sprite_sheet(images : Array(Image),
                                 layout : Util::SpriteLayout = Util::SpriteLayout::Horizontal,
                                 spacing : Int32 = 0,
                                 background : Color::Color = Color::TRANSPARENT) : Util::SpriteSheet
    Util::SpriteGenerator.generate(images, layout, spacing, background)
  end
end
