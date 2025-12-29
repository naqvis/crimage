module CrImage::Util
  # Image stacking and comparison utilities.
  #
  # Provides tools for combining multiple images into layouts for:
  # - Before/after comparisons
  # - Image galleries and collages
  # - Side-by-side analysis
  # - Grid layouts
  module Stacking
    # Stacks images horizontally (side by side).
    #
    # Places images next to each other from left to right with configurable
    # spacing and vertical alignment. Height is determined by the tallest image.
    #
    # Parameters:
    # - `images` : Array of images to stack (must not be empty)
    # - `spacing` : Pixels between images (default: 0)
    # - `alignment` : Vertical alignment (default: Center)
    # - `background` : Background color (default: transparent)
    #
    # Returns: A new RGBA image with stacked images
    #
    # Raises: `ArgumentError` if images array is empty or spacing is negative
    #
    # Example:
    # ```
    # before = CrImage.read("before.jpg")
    # after = CrImage.read("after.jpg")
    # comparison = CrImage.stack_horizontal([before, after])
    # ```
    def self.stack_horizontal(images : Array(Image), spacing : Int32 = 0,
                              alignment : VerticalAlignment = VerticalAlignment::Center,
                              background : Color::Color = Color::TRANSPARENT) : RGBA
      raise ArgumentError.new("images array cannot be empty") if images.empty?
      raise ArgumentError.new("spacing must be non-negative") if spacing < 0

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

      # Create result image
      result = CrImage.rgba(total_width, max_height, background)

      # Place images
      current_x = 0
      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Calculate vertical offset based on alignment
        y_offset = case alignment
                   when .top?
                     0
                   when .center?
                     (max_height - height) // 2
                   when .bottom?
                     max_height - height
                   else
                     0
                   end

        # Copy image
        height.times do |y|
          width.times do |x|
            pixel = img.at(x + bounds.min.x, y + bounds.min.y)
            result.set(current_x + x, y_offset + y, pixel)
          end
        end

        current_x += width + spacing
      end

      result
    end

    # Stacks images vertically (top to bottom).
    #
    # Places images on top of each other from top to bottom with configurable
    # spacing and horizontal alignment. Width is determined by the widest image.
    #
    # Parameters:
    # - `images` : Array of images to stack (must not be empty)
    # - `spacing` : Pixels between images (default: 0)
    # - `alignment` : Horizontal alignment (default: Center)
    # - `background` : Background color (default: transparent)
    #
    # Returns: A new RGBA image with stacked images
    #
    # Raises: `ArgumentError` if images array is empty or spacing is negative
    #
    # Example:
    # ```
    # img1 = CrImage.read("top.jpg")
    # img2 = CrImage.read("bottom.jpg")
    # stacked = CrImage.stack_vertical([img1, img2])
    # ```
    def self.stack_vertical(images : Array(Image), spacing : Int32 = 0,
                            alignment : HorizontalAlignment = HorizontalAlignment::Center,
                            background : Color::Color = Color::TRANSPARENT) : RGBA
      raise ArgumentError.new("images array cannot be empty") if images.empty?
      raise ArgumentError.new("spacing must be non-negative") if spacing < 0

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

      # Create result image
      result = CrImage.rgba(max_width, total_height, background)

      # Place images
      current_y = 0
      images.each do |img|
        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Calculate horizontal offset based on alignment
        x_offset = case alignment
                   when .left?
                     0
                   when .center?
                     (max_width - width) // 2
                   when .right?
                     max_width - width
                   else
                     0
                   end

        # Copy image
        height.times do |y|
          width.times do |x|
            pixel = img.at(x + bounds.min.x, y + bounds.min.y)
            result.set(x_offset + x, current_y + y, pixel)
          end
        end

        current_y += height + spacing
      end

      result
    end

    # Creates a before/after comparison with optional divider.
    #
    # Places two images side by side with optional vertical divider line
    # between them. Perfect for showing image processing results.
    #
    # Parameters:
    # - `before` : First image (typically original)
    # - `after` : Second image (typically processed)
    # - `divider` : Whether to draw divider line (default: false)
    # - `divider_width` : Width of divider line in pixels (default: 2)
    # - `divider_color` : Color of divider line (default: light gray)
    # - `spacing` : Pixels between images (default: 10)
    #
    # Returns: A new RGBA image with comparison layout
    #
    # Raises: `ArgumentError` if divider_width is not positive when divider is enabled
    #
    # Example:
    # ```
    # before = CrImage.read("before.jpg")
    # after = CrImage.read("after.jpg")
    # comparison = CrImage.compare_images(before, after, divider: true)
    # ```
    def self.compare_images(before : Image, after : Image,
                            divider : Bool = false,
                            divider_width : Int32 = 2,
                            divider_color : Color::Color = Color.rgb(200, 200, 200),
                            spacing : Int32 = 10) : RGBA
      raise ArgumentError.new("divider_width must be positive") if divider && divider_width <= 0

      if divider
        # Stack with divider line
        stacked = stack_horizontal([before, after], spacing: spacing)

        # Draw divider line in the middle
        bounds = stacked.bounds
        height = bounds.max.y - bounds.min.y

        before_bounds = before.bounds
        before_width = before_bounds.max.x - before_bounds.min.x
        divider_x = before_width + spacing // 2

        # Draw vertical line
        height.times do |y|
          divider_width.times do |dx|
            x = divider_x + dx - divider_width // 2
            if x >= 0 && x < bounds.max.x
              stacked.set(x, y, divider_color)
            end
          end
        end

        stacked
      else
        stack_horizontal([before, after], spacing: spacing)
      end
    end

    # Creates a grid layout of images.
    #
    # Arranges images in a uniform grid with specified number of columns.
    # Each cell is sized to fit the largest image, with smaller images centered.
    #
    # Parameters:
    # - `images` : Array of images to arrange (must not be empty)
    # - `cols` : Number of columns (must be positive)
    # - `spacing` : Pixels between cells (default: 10)
    # - `background` : Background color (default: transparent)
    #
    # Returns: A new RGBA image with grid layout
    #
    # Raises: `ArgumentError` if images is empty, cols is not positive, or spacing is negative
    #
    # Example:
    # ```
    # images = [img1, img2, img3, img4]
    # grid = CrImage.create_grid(images, cols: 2)
    # ```
    def self.create_grid(images : Array(Image), cols : Int32,
                         spacing : Int32 = 10,
                         background : Color::Color = Color::TRANSPARENT) : RGBA
      raise ArgumentError.new("images array cannot be empty") if images.empty?
      raise ArgumentError.new("cols must be positive") if cols <= 0
      raise ArgumentError.new("spacing must be non-negative") if spacing < 0

      rows = (images.size.to_f64 / cols).ceil.to_i32

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

      # Create result image
      result = CrImage.rgba(total_width, total_height, background)

      # Place images in grid
      images.each_with_index do |img, idx|
        row = idx // cols
        col = idx % cols

        x_pos = col * (max_width + spacing)
        y_pos = row * (max_height + spacing)

        bounds = img.bounds
        width = bounds.max.x - bounds.min.x
        height = bounds.max.y - bounds.min.y

        # Center image in cell
        x_offset = (max_width - width) // 2
        y_offset = (max_height - height) // 2

        # Copy image
        height.times do |y|
          width.times do |x|
            pixel = img.at(x + bounds.min.x, y + bounds.min.y)
            result.set(x_pos + x_offset + x, y_pos + y_offset + y, pixel)
          end
        end
      end

      result
    end
  end

  # Vertical alignment for horizontal stacking.
  #
  # Controls how images of different heights are aligned when stacked horizontally:
  # - `Top` : Align to top edge
  # - `Center` : Center vertically
  # - `Bottom` : Align to bottom edge
  enum VerticalAlignment
    Top
    Center
    Bottom
  end

  # Horizontal alignment for vertical stacking.
  #
  # Controls how images of different widths are aligned when stacked vertically:
  # - `Left` : Align to left edge
  # - `Center` : Center horizontally
  # - `Right` : Align to right edge
  enum HorizontalAlignment
    Left
    Center
    Right
  end
end

module CrImage
  # Stacks images horizontally.
  #
  # Convenience method that delegates to `Util::Stacking.stack_horizontal`.
  #
  # Example:
  # ```
  # comparison = CrImage.stack_horizontal([img1, img2, img3])
  # ```
  def self.stack_horizontal(images : Array(Image), spacing : Int32 = 0,
                            alignment : Util::VerticalAlignment = Util::VerticalAlignment::Center,
                            background : Color::Color = Color::TRANSPARENT) : RGBA
    Util::Stacking.stack_horizontal(images, spacing, alignment, background)
  end

  # Stacks images vertically.
  #
  # Convenience method that delegates to `Util::Stacking.stack_vertical`.
  #
  # Example:
  # ```
  # stacked = CrImage.stack_vertical([img1, img2, img3])
  # ```
  def self.stack_vertical(images : Array(Image), spacing : Int32 = 0,
                          alignment : Util::HorizontalAlignment = Util::HorizontalAlignment::Center,
                          background : Color::Color = Color::TRANSPARENT) : RGBA
    Util::Stacking.stack_vertical(images, spacing, alignment, background)
  end

  # Creates before/after comparison.
  #
  # Convenience method that delegates to `Util::Stacking.compare_images`.
  #
  # Example:
  # ```
  # comparison = CrImage.compare_images(before, after, divider: true)
  # ```
  def self.compare_images(before : Image, after : Image,
                          divider : Bool = false,
                          divider_width : Int32 = 2,
                          divider_color : Color::Color = Color.rgb(200, 200, 200),
                          spacing : Int32 = 10) : RGBA
    Util::Stacking.compare_images(before, after, divider, divider_width, divider_color, spacing)
  end

  # Creates grid layout.
  #
  # Convenience method that delegates to `Util::Stacking.create_grid`.
  #
  # Example:
  # ```
  # grid = CrImage.create_grid([img1, img2, img3, img4], cols: 2)
  # ```
  def self.create_grid(images : Array(Image), cols : Int32,
                       spacing : Int32 = 10,
                       background : Color::Color = Color::TRANSPARENT) : RGBA
    Util::Stacking.create_grid(images, cols, spacing, background)
  end
end
