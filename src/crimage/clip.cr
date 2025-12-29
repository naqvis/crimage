require "./image"

module CrImage
  # ClipContext provides a clipping region for drawing operations.
  #
  # When drawing within a clip context, all operations are restricted
  # to the specified rectangular region. Pixels outside the region
  # are not modified.
  #
  # Example:
  # ```
  # img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
  #
  # # Draw within a clipped region
  # img.with_clip(50, 50, 200, 150) do
  #   # This circle will be clipped to the 200x150 region
  #   img.draw_circle(100, 100, 80, color: CrImage::Color::RED, fill: true)
  # end
  # ```
  class ClipContext
    getter image : CrImage::Image
    getter clip_rect : Rectangle
    getter original_bounds : Rectangle

    def initialize(@image, @clip_rect)
      @original_bounds = @image.bounds
    end

    # Check if a point is within the clip region
    def in_clip?(x : Int32, y : Int32) : Bool
      x >= @clip_rect.min.x && x < @clip_rect.max.x &&
        y >= @clip_rect.min.y && y < @clip_rect.max.y
    end

    # Get the intersection of a rectangle with the clip region
    def clip(rect : Rectangle) : Rectangle
      rect.intersect(@clip_rect)
    end
  end

  # ClippedImage wraps an image and restricts all drawing to a clip region.
  #
  # This is a proxy that intercepts set() calls and only allows
  # modifications within the clip bounds.
  class ClippedImage
    include CrImage::Image

    @inner : CrImage::Image
    @clip : Rectangle

    def initialize(@inner, @clip)
    end

    def color_model : CrImage::Color::Model
      @inner.color_model
    end

    def bounds : Rectangle
      @clip
    end

    def at(x : Int32, y : Int32) : CrImage::Color::Color
      @inner.at(x, y)
    end

    def set(x : Int32, y : Int32, c : CrImage::Color::Color)
      return unless x >= @clip.min.x && x < @clip.max.x
      return unless y >= @clip.min.y && y < @clip.max.y
      @inner.set(x, y, c)
    end
  end

  module Image
    # Executes a block with drawing operations clipped to the specified region.
    #
    # All drawing operations within the block will be restricted to the
    # rectangular region defined by (x, y, width, height). Pixels outside
    # this region will not be modified.
    #
    # Parameters:
    # - `x` : Left edge of clip region
    # - `y` : Top edge of clip region
    # - `width` : Width of clip region
    # - `height` : Height of clip region
    # - `&block` : Block receiving a ClippedImage to draw on
    #
    # Example:
    # ```
    # img = CrImage.rgba(400, 300, CrImage::Color::WHITE)
    #
    # # Draw a circle that would normally overflow, but gets clipped
    # img.with_clip(50, 50, 100, 100) do |clipped|
    #   style = CrImage::Draw::CircleStyle.new(CrImage::Color::RED, fill: true)
    #   CrImage::Draw.circle(clipped, CrImage.point(50, 50), 80, style)
    # end
    # ```
    def with_clip(x : Int32, y : Int32, width : Int32, height : Int32, &block : ClippedImage ->)
      # Calculate clip rectangle, intersected with image bounds
      clip_rect = CrImage.rect(x, y, x + width, y + height).intersect(bounds)
      return if clip_rect.empty

      clipped = ClippedImage.new(self, clip_rect)
      yield clipped
    end

    # Executes a block with drawing operations clipped to the specified rectangle.
    #
    # Parameters:
    # - `rect` : Rectangle defining the clip region
    # - `&block` : Block receiving a ClippedImage to draw on
    #
    # Example:
    # ```
    # plot_area = CrImage.rect(50, 50, 350, 250)
    # img.with_clip(plot_area) do |clipped|
    #   # All drawing here is restricted to plot_area
    # end
    # ```
    def with_clip(rect : Rectangle, &block : ClippedImage ->)
      clip_rect = rect.intersect(bounds)
      return if clip_rect.empty

      clipped = ClippedImage.new(self, clip_rect)
      yield clipped
    end
  end
end
