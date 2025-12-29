require "./image_type_macro"

module CrImage
  # RGBA is an in-memory image with premultiplied alpha.
  #
  # Each pixel is stored as 4 bytes (R, G, B, A) with color values
  # premultiplied by alpha for efficient compositing. This is the most
  # common image format for rendering and display.
  #
  # Memory layout: Contiguous byte array with 4 bytes per pixel
  # Color model: RGBA with premultiplied alpha
  #
  # Example:
  # ```
  # img = CrImage::RGBA.new(CrImage.rect(0, 0, 640, 480))
  # img.set_rgba(100, 100, CrImage::Color::RGBA.new(255, 0, 0, 255))
  # ```
  define_slice_image_type(
    RGBA,
    Color::RGBA,
    4,
    rgba_model,
    rgba_at,
    set_rgba,
    Color::RGBA.new(0, 0, 0, 0),
    false
  )
end
