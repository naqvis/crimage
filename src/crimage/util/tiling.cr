module CrImage::Util
  # Image tiling and pattern generation.
  #
  # Provides tools for creating tiled patterns and seamless textures.
  # Useful for:
  # - Creating backgrounds and wallpapers
  # - Generating repeating patterns
  # - Making seamless textures for 3D graphics
  # - Web design and UI backgrounds
  module Tiling
    # Tiles an image in a grid pattern.
    #
    # Creates a larger image by repeating the source image in a rectangular
    # grid. Each tile is an exact copy of the source image.
    #
    # Parameters:
    # - `src` : The source image to tile
    # - `cols` : Number of columns (must be positive)
    # - `rows` : Number of rows (must be positive)
    #
    # Returns: A new RGBA image with tiled pattern
    #
    # Raises: `ArgumentError` if cols or rows are not positive
    #
    # Example:
    # ```
    # img = CrImage.read("tile.png")
    # tiled = img.tile(3, 3) # 3x3 grid
    # ```
    def self.tile(src : Image, cols : Int32, rows : Int32) : RGBA
      raise ArgumentError.new("cols must be positive") if cols <= 0
      raise ArgumentError.new("rows must be positive") if rows <= 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Calculate output dimensions
      total_width = src_width * cols
      total_height = src_height * rows

      # Create result image
      result = CrImage.rgba(total_width, total_height, Color::TRANSPARENT)

      # Tile the image
      rows.times do |row|
        cols.times do |col|
          offset_x = col * src_width
          offset_y = row * src_height

          # Copy source image to this tile position
          src_height.times do |y|
            src_width.times do |x|
              pixel = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
              result.set(offset_x + x, offset_y + y, pixel)
            end
          end
        end
      end

      result
    end

    # Creates a seamless tileable pattern from an image.
    #
    # Blends opposite edges together to eliminate visible seams when the
    # image is tiled. The blend_width controls how much of the edge is
    # blended (larger = smoother transition but more distortion).
    #
    # Parameters:
    # - `src` : The source image
    # - `blend_width` : Width of edge blending in pixels (0 = auto, 1/8 of smallest dimension)
    #
    # Returns: A new RGBA image that tiles seamlessly
    #
    # Raises: `ArgumentError` if blend_width is too large
    #
    # Example:
    # ```
    # img = CrImage.read("texture.png")
    # seamless = img.make_seamless
    # tiled = seamless.tile(4, 4) # No visible seams
    # ```
    def self.make_seamless(src : Image, blend_width : Int32 = 0) : RGBA
      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Auto-calculate blend width if not specified
      if blend_width <= 0
        blend_width = [src_width, src_height].min // 8
        blend_width = [blend_width, 1].max
      end

      raise ArgumentError.new("blend_width too large") if blend_width >= src_width // 2 || blend_width >= src_height // 2

      # Create result image
      result = CrImage.rgba(src_width, src_height, Color::TRANSPARENT)

      # Copy source image
      src_height.times do |y|
        src_width.times do |x|
          pixel = src.at(x + src_bounds.min.x, y + src_bounds.min.y)
          result.set(x, y, pixel)
        end
      end

      # Blend horizontal edges (left-right)
      src_height.times do |y|
        blend_width.times do |i|
          # Blend factor (0.0 to 1.0)
          factor = i.to_f64 / blend_width

          # Left edge - blend with right edge
          left_x = i
          right_x = src_width - blend_width + i

          left_pixel = src.at(left_x + src_bounds.min.x, y + src_bounds.min.y)
          right_pixel = src.at(right_x + src_bounds.min.x, y + src_bounds.min.y)

          blended = blend_colors(right_pixel, left_pixel, factor)
          result.set(left_x, y, blended)

          # Right edge - blend with left edge
          blended = blend_colors(left_pixel, right_pixel, factor)
          result.set(right_x, y, blended)
        end
      end

      # Blend vertical edges (top-bottom)
      src_width.times do |x|
        blend_width.times do |i|
          factor = i.to_f64 / blend_width

          # Top edge - blend with bottom edge
          top_y = i
          bottom_y = src_height - blend_width + i

          top_pixel = result.at(x, top_y)
          bottom_pixel = result.at(x, bottom_y)

          blended = blend_colors(bottom_pixel, top_pixel, factor)
          result.set(x, top_y, blended)

          # Bottom edge - blend with top edge
          blended = blend_colors(top_pixel, bottom_pixel, factor)
          result.set(x, bottom_y, blended)
        end
      end

      result
    end

    # Tiles an image to fill specific dimensions.
    #
    # Repeats the image as many times as needed to cover the target area,
    # cropping the final row/column if they extend beyond the target size.
    # Useful for creating backgrounds and wallpapers.
    #
    # Parameters:
    # - `src` : The source image to tile
    # - `target_width` : Desired width in pixels (must be positive)
    # - `target_height` : Desired height in pixels (must be positive)
    #
    # Returns: A new RGBA image with tiled pattern
    #
    # Raises: `ArgumentError` if dimensions are not positive
    #
    # Example:
    # ```
    # img = CrImage.read("pattern.png")
    # background = img.tile_to_size(1920, 1080)
    # ```
    def self.tile_to_size(src : Image, target_width : Int32, target_height : Int32) : RGBA
      raise ArgumentError.new("target_width must be positive") if target_width <= 0
      raise ArgumentError.new("target_height must be positive") if target_height <= 0

      src_bounds = src.bounds
      src_width = src_bounds.max.x - src_bounds.min.x
      src_height = src_bounds.max.y - src_bounds.min.y

      # Calculate how many tiles we need
      cols = (target_width.to_f64 / src_width).ceil.to_i32
      rows = (target_height.to_f64 / src_height).ceil.to_i32

      # Tile the image
      tiled = tile(src, cols, rows)

      # Crop to exact target size
      if tiled.bounds.width > target_width || tiled.bounds.height > target_height
        crop_rect = CrImage.rect(0, 0, target_width, target_height)
        tiled.crop(crop_rect).as(RGBA)
      else
        tiled
      end
    end

    # Blends two colors with linear interpolation.
    #
    # Parameters:
    # - `color1` : First color (weight = 1.0 - factor)
    # - `color2` : Second color (weight = factor)
    # - `factor` : Blend factor (0.0 = color1, 1.0 = color2)
    #
    # Returns: Blended color
    private def self.blend_colors(color1 : Color::Color, color2 : Color::Color, factor : Float64) : Color::Color
      r1, g1, b1, a1 = color1.rgba
      r2, g2, b2, a2 = color2.rgba

      inv_factor = 1.0 - factor

      r = ((r1 >> 8).to_f64 * inv_factor + (r2 >> 8).to_f64 * factor).to_i32
      g = ((g1 >> 8).to_f64 * inv_factor + (g2 >> 8).to_f64 * factor).to_i32
      b = ((b1 >> 8).to_f64 * inv_factor + (b2 >> 8).to_f64 * factor).to_i32
      a = ((a1 >> 8).to_f64 * inv_factor + (a2 >> 8).to_f64 * factor).to_i32

      Color.rgba(r.to_u8, g.to_u8, b.to_u8, a.to_u8)
    end
  end
end

module CrImage
  module Image
    # Tiles the image in a grid pattern.
    #
    # Convenience method that delegates to `Util::Tiling.tile`.
    #
    # Example:
    # ```
    # img = CrImage.read("tile.png")
    # tiled = img.tile(3, 3)
    # ```
    def tile(cols : Int32, rows : Int32) : RGBA
      Util::Tiling.tile(self, cols, rows)
    end

    # Makes the image seamlessly tileable.
    #
    # Convenience method that delegates to `Util::Tiling.make_seamless`.
    #
    # Example:
    # ```
    # img = CrImage.read("texture.png")
    # seamless = img.make_seamless
    # ```
    def make_seamless(blend_width : Int32 = 0) : RGBA
      Util::Tiling.make_seamless(self, blend_width)
    end

    # Tiles the image to fill specific dimensions.
    #
    # Convenience method that delegates to `Util::Tiling.tile_to_size`.
    #
    # Example:
    # ```
    # img = CrImage.read("pattern.png")
    # background = img.tile_to_size(1920, 1080)
    # ```
    def tile_to_size(target_width : Int32, target_height : Int32) : RGBA
      Util::Tiling.tile_to_size(self, target_width, target_height)
    end
  end
end
