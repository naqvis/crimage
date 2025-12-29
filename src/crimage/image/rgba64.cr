require "./image_type_macro"

module CrImage
  # RGBA64 is an in-memory 64-bit image with premultiplied alpha.
  #
  # Each pixel is stored as 8 bytes (16 bits per channel: R, G, B, A).
  # Provides higher color precision than 8-bit RGBA for professional imaging.
  #
  # Memory layout: Contiguous byte array with 8 bytes per pixel
  # Color model: RGBA64 with premultiplied alpha (16-bit per channel)
  #
  # Example:
  # ```
  # img = CrImage::RGBA64.new(CrImage.rect(0, 0, 640, 480))
  # img.set_rgba64(100, 100, CrImage::Color::RGBA64.new(65535, 0, 0, 65535))
  # ```
  define_slice_image_type(
    RGBA64,
    Color::RGBA64,
    8,
    rgba64_model,
    rgba64_at,
    set_rgba64,
    Color::RGBA64.new(0, 0, 0, 0),
    false
  )
end
