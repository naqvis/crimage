require "../image"
require "../transform"

module CrImage::Util
  # Thumbnail generation mode.
  #
  # Controls how the image is resized to fit target dimensions:
  # - `Fit` : Scale to fit within bounds, preserve aspect ratio (letterbox/pillarbox)
  # - `Fill` : Scale to fill bounds completely, crop excess (no empty space)
  # - `Stretch` : Stretch to exact dimensions, ignore aspect ratio
  enum ThumbnailMode
    Fit
    Fill
    Stretch
  end

  # Resampling quality level for thumbnail generation.
  #
  # Different algorithms offer trade-offs between speed and quality:
  # - `Nearest` : Fastest, pixelated results, good for pixel art
  # - `Bilinear` : Fast, smooth results, good for most use cases
  # - `Bicubic` : Slower, sharper results, good for photos
  # - `Lanczos` : Slowest, highest quality, best for critical work
  enum ResampleQuality
    Nearest
    Bilinear
    Bicubic
    Lanczos
  end

  # Generates a thumbnail from an image with specified dimensions and quality.
  #
  # Creates a resized version of the image suitable for thumbnails, previews,
  # and web display. Supports different scaling modes and quality levels.
  #
  # Parameters:
  # - `img` : The source image
  # - `width` : Target width in pixels (must be positive)
  # - `height` : Target height in pixels (must be positive)
  # - `mode` : Scaling mode (default: Fit)
  # - `quality` : Resampling quality (default: Bicubic)
  #
  # Returns: A new RGBA thumbnail image
  #
  # Raises: `ArgumentError` if dimensions are not positive
  #
  # Example:
  # ```
  # img = CrImage.read("photo.jpg")
  # thumb = CrImage::Util.thumbnail(img, 200, 200, ThumbnailMode::Fill)
  # ```
  def self.thumbnail(img : Image, width : Int32, height : Int32,
                     mode : ThumbnailMode = ThumbnailMode::Fit,
                     quality : ResampleQuality = ResampleQuality::Bicubic) : RGBA
    raise ArgumentError.new("Width must be positive, got #{width}") if width <= 0
    raise ArgumentError.new("Height must be positive, got #{height}") if height <= 0

    src_bounds = img.bounds
    src_width = src_bounds.width
    src_height = src_bounds.height

    case mode
    when ThumbnailMode::Fit
      # Scale to fit within bounds, preserve aspect ratio
      # Calculate scale factor to fit within target dimensions
      scale_x = width.to_f / src_width
      scale_y = height.to_f / src_height
      scale = [scale_x, scale_y].min

      # Calculate new dimensions maintaining aspect ratio
      new_width = (src_width * scale).round.to_i
      new_height = (src_height * scale).round.to_i

      # Resize using selected quality
      resize_with_quality(img, new_width, new_height, quality)
    when ThumbnailMode::Fill
      # Scale to fill bounds, crop excess
      # Calculate scale factor to fill target dimensions
      scale_x = width.to_f / src_width
      scale_y = height.to_f / src_height
      scale = [scale_x, scale_y].max

      # Calculate intermediate dimensions
      scaled_width = (src_width * scale).round.to_i
      scaled_height = (src_height * scale).round.to_i

      # Resize to fill dimensions
      scaled = resize_with_quality(img, scaled_width, scaled_height, quality)

      # Crop to exact target dimensions (center crop)
      crop_x = ((scaled_width - width) / 2).to_i
      crop_y = ((scaled_height - height) / 2).to_i

      # Create final image with exact dimensions
      dst = RGBA.new(CrImage.rect(0, 0, width, height))
      height.times do |y|
        width.times do |x|
          dst.set(x, y, scaled.at(x + crop_x, y + crop_y))
        end
      end
      dst
    when ThumbnailMode::Stretch
      # Stretch to exact dimensions (ignore aspect ratio)
      resize_with_quality(img, width, height, quality)
    else
      # This should never happen, but Crystal requires exhaustive case handling
      raise InvalidArgumentError.new("mode", mode.to_s)
    end
  end

  # Resizes image using the specified quality/algorithm.
  #
  # Dispatches to the appropriate resize method based on quality setting.
  private def self.resize_with_quality(img : Image, width : Int32, height : Int32,
                                       quality : ResampleQuality) : RGBA
    case quality
    when .nearest?
      Transform.resize_nearest(img, width, height)
    when .bilinear?
      Transform.resize_bilinear(img, width, height)
    when .bicubic?
      Transform.resize_bicubic(img, width, height)
    when .lanczos?
      Transform.resize_lanczos(img, width, height)
    else
      # This should never happen, but Crystal requires exhaustive case handling
      raise InvalidArgumentError.new("quality", quality.to_s)
    end
  end
end
